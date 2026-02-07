extends Node

# --- Variables --- #
var curr_id := 0

var enemy_registry: Dictionary[int, String] = {}
var tile_entity_registry: Dictionary[int, String] = {}

var anchored_entities: Dictionary[Vector2i, Array] = {}

var loaded_entities: Dictionary[int, Node2D] = {}

# --- Functions --- #
func _ready() -> void:
	# crawl files to add enemies to the list
	crawl_registry('res://entities/dynamic_entities', enemy_registry)
	crawl_registry('res://entities/tile_entities', tile_entity_registry)

func crawl_registry(root_dir: String, registry: Dictionary[int, String]) -> void:
	var entity_dir := DirAccess.open(root_dir)
	
	for dir_name in entity_dir.get_directories():
		var id_str := dir_name.split('_')[0]
		
		if not id_str.is_valid_int():
			printerr("[Wizbowo's Conquest] Cannot parse id from %s (got %s)" % [dir_name, id_str])
			continue
		
		var id := int(id_str)
		var dir := DirAccess.open(root_dir.path_join(dir_name))
		
		if dir.file_exists('entity.tscn'):
			registry[id] = root_dir.path_join(dir_name).path_join('entity.tscn')
		else:
			printerr("[Wizbowo's Conquest] No file 'entity.tscn' found in directory %s" % dir_name)

#region Entity Spawning
func create_entity(
		registry_id: int, position: Vector2i, spawn_data: Dictionary[StringName, Variant]
	) -> void:
	
	# setup new entity
	var entity_path: String = enemy_registry.get(registry_id)
	if not entity_path:
		printerr("[Wizbowo's Conquest] Cannot locate entity with id '%s'" % registry_id)
		return
	
	# create new entity
	var entity: Entity = load(entity_path).instantiate()
	entity.position = TileManager.tile_to_world(position.x, position.y)
	entity.name = "entity_%s" % curr_id
	
	entity.initialize(curr_id, spawn_data)
	loaded_entities[curr_id] = entity
	curr_id += 1
	
	# check interest
	entity.scan_interest()
	
	get_tree().current_scene.get_node(^'entities').add_child(entity)
	
	for player in entity.interested_players:
		load_entity.rpc_id(player, registry_id, position, spawn_data, entity.id)

func create_entities(
		registry_id: int, positions: Array[Vector2i], spawn_data: Dictionary[StringName, Variant]
	) -> void:
	
	var entity_path: String = enemy_registry.get(registry_id)
	if not entity_path:
		printerr("[Wizbowo's Conquest] Cannot locate entity with id '%s'" % registry_id)
		return
	
	# create new entity
	var start_id := curr_id
	var interested_players: Array[int]
	
	for position in positions:
		var entity: Entity = load(entity_path).instantiate()
		entity.position = TileManager.tile_to_world(position.x, position.y)
		entity.name = "entity_%s" % curr_id
		
		entity.initialize(curr_id, spawn_data)
		loaded_entities[curr_id] = entity
		curr_id += 1
		
		# check interest
		entity.scan_interest()
		interested_players = entity.interested_players.keys()
		
		get_tree().current_scene.get_node(^'entities').add_child(entity)
	
	# send to players
	for player in interested_players:
		load_entities.rpc_id(player, registry_id, positions, spawn_data, start_id, curr_id - 1)

func create_tile_entity(
		registry_id: int, position: Vector2i, spawn_data: Dictionary[StringName, Variant]
	) -> void:
	
	var entity_info := TileEntityInfo.new(curr_id, registry_id, position, spawn_data)
	curr_id += 1
	
	# add to chunk container
	var chunk := TileManager.tile_to_chunk(position.x, position.y)
	
	if chunk not in anchored_entities:
		anchored_entities[chunk] = []
	
	anchored_entities[chunk].append(entity_info)

@rpc('authority', 'call_remote', 'reliable')
func load_entity(
		registry_id: int, position: Vector2i, spawn_data: Dictionary[StringName, Variant], spawn_id: int
	) -> void:
	
	# don't re-instantiate existing entities
	if loaded_entities.get(spawn_id):
		return
	
	# setup new entity
	var entity_path: String = enemy_registry.get(registry_id)
	if not entity_path:
		return
	
	var entity: Entity = load(entity_path).instantiate()
	entity.add_interest(multiplayer.get_unique_id())
	
	entity.position = TileManager.tile_to_world(position.x, position.y)
	entity.name = "entity_%s" % spawn_id
	
	entity.initialize(spawn_id, spawn_data)
	loaded_entities[spawn_id] = entity
	
	get_tree().current_scene.get_node(^'entities').add_child(entity)

@rpc('authority', 'call_remote', 'reliable')
func load_entities(
		registry_id: int, positions: Array[Vector2i], spawn_data: Dictionary[StringName, Variant], 
		spawn_id_start: int, spawn_id_end: int
	) -> void:
	
	# setup new entity
	var entity_path: String = enemy_registry.get(registry_id)
	if not entity_path:
		return
	
	for i in range(len(positions)):
		var position := positions[i]
		var spawn_id := spawn_id_start + i
		
		# don't re-instantiate existing entities
		if loaded_entities.get(spawn_id):
			continue
		
		var entity: Entity = load(entity_path).instantiate()
		entity.add_interest(multiplayer.get_unique_id())
		
		entity.position = TileManager.tile_to_world(position.x, position.y)
		entity.name = "entity_%s" % spawn_id
		
		entity.initialize(spawn_id, spawn_data)
		loaded_entities[spawn_id] = entity
		
		get_tree().current_scene.get_node(^'entities').add_child(entity)

@rpc('authority', 'call_remote', 'reliable')
func load_tile_entity(
		registry_id: int, position: Vector2i, spawn_data: Dictionary[StringName, Variant], spawn_id: int
	) -> void:
	
	# don't re-instantiate existing entities
	if loaded_entities.get(spawn_id):
		return
	
	# setup new entity
	var entity_path: String = tile_entity_registry.get(registry_id)
	if not entity_path:
		return
	
	var entity: TileEntity = load(entity_path).instantiate()
	entity.position = TileManager.tile_to_world(position.x, position.y)
	entity.name = "entity_%s" % spawn_id
	
	entity.initialize(spawn_id, spawn_data)
	loaded_entities[spawn_id] = entity
	
	get_tree().current_scene.get_node(^'entities').add_child(entity)

#endregion

#region Entity Management
@rpc('any_peer', 'call_remote', "reliable")
func entity_take_damage(entity_id: int, snapshot: Dictionary) -> void:
	var entity: Node2D = loaded_entities[entity_id]
	
	if not (entity and len(entity.hp_pool) > 0):
		return
	
	# TODO: verify attack
	var damage: int = snapshot.get(&'damage', 0)
	var pool_id: int = snapshot.get(&'pool_id', 0)
	
	# apply damage
	entity.hp_pool[pool_id].modify_health(-damage, true)
	
	if entity.hp_pool[pool_id].curr_hp <= 0:
		snapshot[&'entity_dead'] = true
	
	# send to relavent players
	for player in entity.interested_players:
		entity.hp_pool[pool_id].receive_damage_snapshot.rpc_id(player, snapshot)

#endregion

#region Interest Management
func load_chunk(chunk: Vector2i, player_id: int) -> void:
	if chunk not in anchored_entities:
		return
	
	for entity_info: TileEntityInfo in anchored_entities[chunk]:
		# create entity server-side
		if not entity_info.entity_id in loaded_entities:
			@warning_ignore("confusable_local_declaration")
			var entity: TileEntity = load(tile_entity_registry.get(entity_info.registry_id)).instantiate()
			entity.position = TileManager.tile_to_world(
				entity_info.anchor_point.x,
				entity_info.anchor_point.y
			)
			entity.name = "entity_%s" % entity_info.entity_id
			
			entity.initialize(entity_info.entity_id, entity_info.data)
			loaded_entities[entity_info.entity_id] = entity
			
			get_tree().current_scene.get_node(^'entities').add_child(entity)
		
		# mark player as interested
		var entity: TileEntity = loaded_entities[entity_info.entity_id]
		if not is_instance_valid(entity):
			loaded_entities.erase(entity_info.entity_id)
			return
		
		entity.add_interest(player_id)
		
		# send to player
		load_tile_entity.rpc_id(player_id,
			entity_info.registry_id, entity_info.anchor_point, entity_info.data, entity_info.entity_id
		)

func unload_chunk(chunk: Vector2i, player_id: int) -> void:
	print("Loaded chunk %s from player '%s'" % [chunk, player_id])

func erase_entity(entity: Node2D) -> void:
	loaded_entities.erase(entity.id)
	
	if multiplayer.is_server() and entity is TileEntity:
		var chunk: Array = anchored_entities.get(entity.current_chunk, [])
		chunk.erase(entity)
		
		if len(chunk):
			anchored_entities.erase(entity.current_chunk)

#endregion

#region Helper Classes
class TileEntityInfo:
	var entity_id: int
	var registry_id: int
	var anchor_point: Vector2i
	var data: Dictionary[StringName, Variant]
	var current_instance: Entity
	
	@warning_ignore('shadowed_variable')
	func _init(entity_id: int, registry_id: int, anchor_point: Vector2i, data: Dictionary[StringName, Variant]):
		self.entity_id = entity_id
		self.registry_id = registry_id
		self.anchor_point = anchor_point
		self.data = data
	
	func spawn() -> void:
		current_instance = load(EntityManager.tile_entity_registry[entity_id]).instantiate()

#endregion
