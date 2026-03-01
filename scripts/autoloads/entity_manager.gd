extends Node

# --- Variables --- #
var curr_id := 0

var enemy_registry: Dictionary[int, EntityInfo] = {}
var tile_entity_registry: Dictionary[int, EntityInfo] = {}

var tile_entities: Dictionary[Vector2i, Dictionary] = {}
var dynamic_entities: Dictionary[Vector2i, Dictionary] = {}

var loaded_entities: Dictionary[int, Node2D] = {}

# --- Functions --- #
func _ready() -> void:
	# crawl files to add enemies to the list
	crawl_registry('res://entities'.path_join('dynamic_entities'), enemy_registry)
	crawl_registry('res://entities'.path_join('tile_entities'), tile_entity_registry)

func crawl_registry(root_dir: String, registry: Dictionary[int, EntityInfo]) -> void:
	var entity_dir := DirAccess.open(root_dir)
	
	for dir_name in entity_dir.get_directories():
		var id_str := dir_name.split('_')[0]
		
		if not id_str.is_valid_int():
			printerr("[Wizbowo's Conquest] Cannot parse id from %s (got %s)" % [dir_name, id_str])
			continue
		
		var id := int(id_str)
		var dir := DirAccess.open(root_dir.path_join(dir_name))
		
		if dir.file_exists('info.tres') or dir.file_exists('info.tres.remap'):
			registry[id] = load(root_dir.path_join(dir_name).path_join('info.tres'))
		else:
			printerr("[Wizbowo's Conquest] No file 'info.tres' found in directory %s" % dir_name)

#region Entity Spawning
func add_entity(registry_id: int, entity: Entity) -> void:
	get_tree().current_scene.get_node(^'entities').add_child(entity)
	entity.scan_interest()
	
	# don't process entities that don't have interested players
	if entity.interest_count == 0:
		entity.queue_free()
		return
	
	# set entity id
	entity.id = curr_id
	entity.name = "entity_%s" % curr_id
	loaded_entities[curr_id] = entity
	curr_id += 1
	
	# anchor to chunk
	entity.calculate_chunk()
	
	if entity.current_chunk not in dynamic_entities:
		dynamic_entities[entity.current_chunk] = {}
	dynamic_entities[entity.current_chunk][curr_id] = true
	
	# send to interested players
	var spawn_data := entity.serialize_spawn_data()
	
	for player_id in entity.interested_players:
		load_entity_new.rpc_id(player_id, entity.id, registry_id, spawn_data)

@rpc('authority', 'call_remote', 'reliable')
func load_entity_new(spawn_id: int, registry_id: int, spawn_data: PackedByteArray) -> void:
	# create new entity instance
	var entity_scene: PackedScene = enemy_registry.get(registry_id).entity_scene
	if not entity_scene:
		printerr("[Wizbowo's Conquest] Cannot locate entity with id '%s'" % registry_id)
		return
	
	var entity: Entity = entity_scene.instantiate()
	
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = spawn_data
	entity.deserialize_spawn_data(buffer)
	
	entity.id = spawn_id
	entity.name = "entity_%s" % spawn_id
	loaded_entities[spawn_id] = entity
	
	get_tree().current_scene.get_node(^'entities').add_child(entity)

func create_entity(
		registry_id: int, position: Vector2i, spawn_data: Dictionary
	) -> void:
	
	# setup new entity
	var entity_scene: PackedScene = enemy_registry.get(registry_id).entity_scene
	if not entity_scene:
		printerr("[Wizbowo's Conquest] Cannot locate entity with id '%s'" % registry_id)
		return
	
	# create new entity
	var entity: Entity = entity_scene.instantiate()
	var chunk: Vector2i = TileManager.world_to_chunk(floori(position.x), floori(position.y))
	entity.position = position
	if chunk not in dynamic_entities:
		dynamic_entities[chunk] = {}
	dynamic_entities[chunk][curr_id] = true
	
	entity.name = "entity_%s" % curr_id
	
	entity.initialize(curr_id, registry_id, spawn_data.merged({&'spawned': true}))
	loaded_entities[curr_id] = entity
	curr_id += 1
	
	# check interest
	entity.scan_interest()
	
	get_tree().current_scene.get_node(^'entities').add_child(entity)
	
	for player in entity.interested_players:
		if player not in ServerManager.connected_players.keys():
			entity.remove_interest(player)
			continue
		
		load_entity.rpc_id(player, registry_id, position, spawn_data, entity.id)

func create_entities(
		registry_id: int, positions: Array[Vector2], spawn_data: Array[Dictionary]
	) -> void:
	
	var entity_scene: PackedScene = enemy_registry.get(registry_id).entity_scene
	if not entity_scene:
		printerr("[Wizbowo's Conquest] Cannot locate entity with id '%s'" % registry_id)
		return
	
	# create new entity
	var start_id := curr_id
	var interested_players: Array[int]
	
	for i in range(len(positions)):
		var position: Vector2 = positions[i]
		
		var entity: Entity = entity_scene.instantiate()
		var chunk: Vector2i = TileManager.world_to_chunk(floori(position.x), floori(position.y))
		entity.position = position
		if chunk not in dynamic_entities:
			dynamic_entities[chunk] = {}
		dynamic_entities[chunk][curr_id] = true
		
		entity.name = "entity_%s" % curr_id
		
		entity.initialize(curr_id, registry_id, spawn_data[i].merged({&'spawned': true}))
		loaded_entities[curr_id] = entity
		curr_id += 1
		
		# check interest
		entity.scan_interest()
		interested_players = entity.interested_players.keys()
		
		get_tree().current_scene.get_node(^'entities').add_child(entity)
	
	# send to players
	for player in interested_players:
		if player not in ServerManager.connected_players.keys():
			continue
		
		load_entities.rpc_id(player, registry_id, positions, spawn_data, start_id)

func create_tile_entity(
		registry_id: int, position: Vector2i, spawn_data: Dictionary
	) -> void:
	
	var entity_info := TileEntityInfo.new(curr_id, registry_id, position, spawn_data)
	curr_id += 1
	
	# add to chunk container
	var chunk := TileManager.tile_to_chunk(position.x, position.y)
	
	if chunk not in tile_entities:
		tile_entities[chunk] = {}
	
	tile_entities[chunk][curr_id - 1] = entity_info

@rpc('authority', 'call_remote', 'reliable')
func load_entity(
		registry_id: int, position: Vector2, spawn_data: Dictionary, spawn_id: int
	) -> void:
	
	# don't re-instantiate existing entities
	if loaded_entities.get(spawn_id):
		var loaded_entity: Entity = loaded_entities[spawn_id]
		loaded_entity.add_interest(multiplayer.get_unique_id())
		
		if Globals.player and loaded_entity.counts_towards_spawn_cap:
			Globals.player.add_interest(spawn_id)
		return
	
	# setup new entity
	var entity_scene: PackedScene = enemy_registry.get(registry_id).entity_scene
	if not entity_scene:
		return
	
	var entity: Entity = entity_scene.instantiate()
	entity.add_interest(multiplayer.get_unique_id())
	if Globals.player:
		Globals.player.remove_interest(spawn_id)
	
	entity.position = position
	entity.name = "entity_%s" % spawn_id
	
	entity.initialize(spawn_id, registry_id, spawn_data)
	loaded_entities[spawn_id] = entity
	
	get_tree().current_scene.get_node(^'entities').add_child(entity)

@rpc('authority', 'call_remote', 'reliable')
func load_entities(
		registry_id: int, positions: Array[Vector2], spawn_data: Array[Dictionary], 
		spawn_id_start: int
	) -> void:
	
	# setup new entity
	var entity_scene: PackedScene = enemy_registry.get(registry_id).entity_scene
	if not entity_scene:
		return
	
	for i in range(len(positions)):
		var position := positions[i]
		var spawn_id := spawn_id_start + i
		
		# don't re-instantiate existing entities
		if loaded_entities.get(spawn_id):
			var loaded_entity: Entity = loaded_entities[spawn_id]
			loaded_entity.add_interest(multiplayer.get_unique_id())
			
			if Globals.player and loaded_entity.counts_towards_spawn_cap:
				Globals.player.add_interest(spawn_id)
			return
		
		var entity: Entity = entity_scene.instantiate()
		entity.add_interest(multiplayer.get_unique_id())
		if Globals.player:
			Globals.player.remove_interest(spawn_id)
		
		entity.position = position
		entity.name = "entity_%s" % spawn_id
		
		entity.initialize(spawn_id, registry_id, spawn_data[i])
		loaded_entities[spawn_id] = entity
		
		get_tree().current_scene.get_node(^'entities').add_child(entity)

@rpc('authority', 'call_remote', 'reliable')
func load_tile_entity(
		registry_id: int, position: Vector2i, spawn_data: Dictionary, spawn_id: int
	) -> void:
	
	# don't re-instantiate existing entities
	if loaded_entities.get(spawn_id):
		return
	
	# setup new entity
	var entity_scene: PackedScene = tile_entity_registry.get(registry_id).entity_scene
	if not entity_scene:
		return
	
	var entity: TileEntity = entity_scene.instantiate()
	entity.position = TileManager.tile_to_world(position.x, position.y)
	entity.name = "entity_%s" % spawn_id
	
	entity.initialize(spawn_id, registry_id, spawn_data)
	loaded_entities[spawn_id] = entity
	
	get_tree().current_scene.get_node(^'entities').add_child(entity)

#endregion

#region Entity Management
@rpc('any_peer', 'call_remote', "reliable")
func entity_take_damage(entity_id: int, snapshot: Dictionary) -> void:
	if not is_instance_valid(loaded_entities.get(entity_id)):
		return
	
	var entity: Node2D = loaded_entities.get(entity_id)
	
	if not (entity and len(entity.hp_pool) > 0):
		return
	
	# TODO: verify attack
	var damage: int = snapshot.get(&'damage', 0)
	var pool_id: int = snapshot.get(&'pool_id', 0)
	
	# apply damage
	entity.hp_pool[pool_id].modify_health(-damage, true)
	
	# store hp
	if entity is TileEntity:
		var entity_info: TileEntityInfo = tile_entities[entity.current_chunk][entity.id]
		
		if &'hp' not in entity_info.data:
			entity_info.data[&'hp'] = {}
		
		entity_info.data[&'hp'][pool_id] = entity.hp_pool[pool_id].curr_hp
	else:
		if &'hp' not in entity.data:
			entity.data[&'hp'] = {}
		
		entity.data[&'hp'][pool_id] = entity.hp_pool[pool_id].curr_hp
	
	if entity.hp_pool[pool_id].curr_hp <= 0:
		snapshot[&'entity_dead'] = true
	
	# call receive signal on server copy
	entity.hp_pool[pool_id].received_damage.emit(snapshot)
	
	# send to relavent players
	for player in entity.interested_players:
		if player not in ServerManager.connected_players.keys():
			entity.remove_interest(player)
			continue
		
		entity.hp_pool[pool_id].receive_damage_snapshot.rpc_id(player, snapshot)

@rpc('any_peer', 'call_remote', 'reliable')
func entity_send_update(entity_id: int, data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	
	var entity: Node2D = loaded_entities.get(entity_id)
	
	if not entity:
		return
	
	# update server entity
	data.merge(entity.receive_update(data), true)
	
	# send to all interested players
	for player in entity.interested_players.keys():
		# make sure player still exists
		if entity is Entity and not entity.check_player(player):
			continue
		
		entity_receive_update.rpc_id(player, entity_id, data)

@rpc('authority', 'call_remote', 'reliable')
func entity_receive_update(entity_id: int, data: Dictionary) -> void:
	var entity: Node2D = loaded_entities.get(entity_id)
	
	if not entity:
		return
	
	# load update
	entity.receive_update(data)

#endregion

#region Interest Management
@rpc('any_peer', 'call_remote', 'reliable')
func load_region(start: Vector2i, width: int, height: int, player_id: int) -> void:
	for x in range(width):
		for y in range(height):
			load_chunk(Vector2i(start.x + x, start.y + y), player_id)

@rpc('any_peer', 'call_remote', 'reliable')
func load_chunk(chunk: Vector2i, player_id: int) -> void:
	for entity_id in tile_entities.get(chunk, {}).keys():
		var entity_info: TileEntityInfo = tile_entities[chunk][entity_id]
		
		# create entity server-side
		if not entity_info.entity_id in loaded_entities:
			var entity_scene: PackedScene = tile_entity_registry.get(entity_info.registry_id).entity_scene
			@warning_ignore("confusable_local_declaration")
			var entity: TileEntity = entity_scene.instantiate()
			entity.position = TileManager.tile_to_world(
				entity_info.anchor_point.x,
				entity_info.anchor_point.y
			)
			entity.name = "entity_%s" % entity_info.entity_id
			
			entity.initialize(entity_info.entity_id, entity_info.registry_id, entity_info.data)
			loaded_entities[entity_info.entity_id] = entity
			
			get_tree().current_scene.get_node(^'entities').add_child(entity)
		
		# mark player as interested
		if not is_instance_valid(loaded_entities[entity_info.entity_id]):
			loaded_entities.erase(entity_info.entity_id)
			continue
		
		var entity: TileEntity = loaded_entities[entity_info.entity_id]
		entity.add_interest(player_id)
		
		# send to player
		load_tile_entity.rpc_id(player_id,
			entity_info.registry_id, entity_info.anchor_point, entity_info.data, entity_info.entity_id
		)
	
	for entity_id in dynamic_entities.get(chunk, {}).keys():
		if not is_instance_valid(loaded_entities.get(entity_id)):
			continue
		
		var entity: Entity = loaded_entities[entity_id]
		entity.add_interest(player_id)
		
		load_entity_new.rpc_id(player_id, entity_id, entity.registry_id, entity.serialize_spawn_data())

func unload_chunk(chunk: Vector2i, player_id: int) -> void:
	print("Loaded chunk %s from player '%s'" % [chunk, player_id])

func erase_entity(entity: Node2D) -> void:
	loaded_entities.erase(entity.id)
	if Globals.player:
		Globals.player.remove_interest(entity.id)
	
	if multiplayer.is_server() and entity is TileEntity:
		var chunk: Dictionary = tile_entities.get(entity.current_chunk, {})
		chunk.erase(entity)
		
		if len(chunk) == 0:
			tile_entities.erase(entity.current_chunk)
	if multiplayer.is_server() and entity is Entity:
		var chunk: Vector2i = entity.current_chunk
		
		if chunk in dynamic_entities and entity.id in dynamic_entities[chunk]:
			dynamic_entities[chunk].erase(entity.id)
			if dynamic_entities[chunk].is_empty():
				dynamic_entities.erase(chunk)

func move_dynamic_entity(entity_id: int, prev_chunk: Vector2i, curr_chunk: Vector2i) -> void:
	# erase old chunk
	if prev_chunk in dynamic_entities and entity_id in dynamic_entities[prev_chunk]:
		dynamic_entities[prev_chunk].erase(entity_id)
		if dynamic_entities[prev_chunk].is_empty():
			dynamic_entities.erase(prev_chunk)
	
	# add new chunk
	if curr_chunk not in dynamic_entities:
		dynamic_entities[curr_chunk] = {}
	
	dynamic_entities[curr_chunk][entity_id] = true

#endregion

#region Helper Classes
class TileEntityInfo:
	var entity_id: int
	var registry_id: int
	var anchor_point: Vector2i
	var data: Dictionary
	var current_instance: Entity
	
	@warning_ignore('shadowed_variable')
	func _init(entity_id: int, registry_id: int, anchor_point: Vector2i, data: Dictionary):
		self.entity_id = entity_id
		self.registry_id = registry_id
		self.anchor_point = anchor_point
		self.data = data
	
	func spawn() -> void:
		current_instance = EntityManager.tile_entity_registry[entity_id].entity_scene.instantiate()

#endregion
