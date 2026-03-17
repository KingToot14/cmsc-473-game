extends Node

# --- Variables --- #
var curr_id := 0

var enemy_registry: Dictionary[int, EntityInfo] = {}
var tile_entity_registry: Dictionary[int, EntityInfo] = {}

var anchored_entities: Dictionary[Vector2i, Array] = {}

var loaded_entities: Dictionary[int, EntityReference] = {}

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
	entity.registry_id = registry_id
	curr_id += 1
	
	entity.name = "entity_%s" % entity.id
	
	var ref := EntityReference.new()
	ref.registry_id = registry_id
	ref.current_instance = entity
	ref.is_tile_entity = false
	
	loaded_entities[entity.id] = ref
	
	# anchor to chunk
	entity.calculate_chunk()
	var chunk := entity.current_chunk
	
	if chunk not in anchored_entities:
		anchored_entities[chunk] = []
	anchored_entities[chunk].append(entity.id)
	
	# send to interested players
	var spawn_data := entity.serialize_spawn_data()
	
	for player_id in entity.interested_players:
		load_entity.rpc_id(player_id, entity.id, registry_id, spawn_data)

#endregion

#region Entity Loading
@rpc('authority', 'call_remote', 'reliable')
func load_entity(spawn_id: int, registry_id: int, spawn_data: PackedByteArray) -> void:
	var ref: EntityReference = loaded_entities.get(spawn_id, null)
	
	# don't process if entity exists and is loaded in reference
	if ref and is_instance_valid(ref.current_instance):
		return
	
	# create new entity instance
	var entity_scene: PackedScene = enemy_registry.get(registry_id).entity_scene
	if not entity_scene:
		printerr("[Wizbowo's Conquest] Cannot locate entity with id '%s'" % registry_id)
		return
	
	var entity: Entity = entity_scene.instantiate()
	get_tree().current_scene.get_node(^'entities').add_child(entity)
	
	# load the latest buffer
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = spawn_data
	entity.deserialize_spawn_data(buffer)
	
	# set id and name
	entity.id = spawn_id
	entity.name = "entity_%s" % spawn_id
	
	# store entity reference
	if not ref:
		ref = EntityReference.new()
	
	ref.registry_id = registry_id
	ref.current_instance = entity
	ref.is_tile_entity = true
	ref.spawn_data = spawn_data
	
	loaded_entities[entity.id] = ref
	
	# update interest on the new instance
	entity.scan_interest()

@rpc('authority', 'call_remote', 'reliable')
func load_tile_entity(spawn_id: int, registry_id: int, spawn_data: PackedByteArray) -> void:
	var ref: EntityReference = loaded_entities.get(spawn_id, null)
	
	# don't process if entity exists and is loaded in reference
	if ref and is_instance_valid(ref.current_instance):
		return
	
	# create new entity instance
	var entity_scene: PackedScene = tile_entity_registry.get(registry_id).entity_scene
	
	if not entity_scene:
		printerr("[Wizbowo's Conquest] Cannot locate entity with id '%s'" % registry_id)
		return
	
	var entity: Entity = entity_scene.instantiate()
	get_tree().current_scene.get_node(^'entities').add_child(entity)
	
	# load the latest buffer
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = spawn_data
	entity.deserialize_spawn_data(buffer)
	
	# set id and name
	entity.id = spawn_id
	entity.name = "entity_%s" % spawn_id
	
	# store entity reference
	if not ref:
		ref = EntityReference.new()
	
	ref.registry_id = registry_id
	ref.current_instance = entity
	ref.is_tile_entity = true
	ref.spawn_data = spawn_data
	
	loaded_entities[entity.id] = ref
	
	# make sure the instance is aware of any nearby players
	entity.scan_interest()

#endregion

#region Data Persistence
func store_tile_entity(registry_id: int, entity: TileEntity) -> void:
	# set ids
	entity.id = curr_id
	entity.registry_id = registry_id
	curr_id += 1
	
	# create new reference
	var ref := EntityReference.new()
	ref.registry_id = registry_id
	ref.spawn_data = entity.serialize_spawn_data()
	ref.is_tile_entity = true
	
	loaded_entities[entity.id] = ref
	
	# anchor to chunk
	entity.calculate_chunk()
	var chunk := entity.current_chunk
	
	if chunk not in anchored_entities:
		anchored_entities[chunk] = []
	anchored_entities[chunk].append(entity.id)
	
	# attempt to load instantly
	entity.scan_interest()
	
	# if no entities exist, just store data for now
	if entity.interest_count == 0:
		entity.queue_free()
	else:
		ref.current_instance = entity
		
		for player_id in entity.interested_players:
			load_tile_entity.rpc_id(player_id, entity.id, registry_id, ref.spawn_data)

func update_entity_data(entity: Entity) -> void:
	var ref: EntityReference = loaded_entities.get(entity.id)
	
	# create reference if it doesn't exist
	if not ref:
		ref = EntityReference.new()
		loaded_entities[entity.id] = ref
	
	ref.registry_id = entity.registry_id
	ref.current_instance = entity
	ref.is_tile_entity = entity is TileEntity
	ref.spawn_data = entity.serialize_spawn_data()

func clear_entity_data(entity: Entity) -> void:
	loaded_entities.erase(entity.id)

func get_persistent_entities() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	
	# header (chunk count)
	buffer.put_u32(len(anchored_entities.keys()))
	
	# entity data
	for chunk: Vector2i in anchored_entities:
		var id_list: Array = anchored_entities[chunk]
		
		# entity count
		buffer.put_u16(len(id_list))
		
		# chunk position
		buffer.put_u16(chunk.x)
		buffer.put_u16(chunk.y)
		
		# spawn data
		for id in id_list:
			var entity_ref := loaded_entities[id]
			
			if not entity_ref:
				# default to no size
				buffer.put_u16(0)
				continue
			
			# reset entity id
			var spawn_data := PackedByteArray(entity_ref.spawn_data)
			spawn_data.encode_u32(0, 0)
			
			# data size
			buffer.put_u16(len(spawn_data))
			
			# registry id
			buffer.put_u16(entity_ref.registry_id)
			
			# data
			buffer.put_data(spawn_data)
	
	return buffer.data_array

func load_persistent_entities(buffer: StreamPeerBuffer) -> void:
	# header
	var chunk_count := buffer.get_u32()
	
	# loop through each chunk
	for i in range(chunk_count):
		# entity count
		var entity_count := buffer.get_u16()
		
		# chunk position
		var chunk_x := buffer.get_u16()
		var chunk_y := buffer.get_u16()
		
		# populate chunk
		for j in range(entity_count):
			# data size
			var data_size := buffer.get_u16()
			
			# skip empty entries
			if data_size == 0:
				continue
			
			# registry id
			var registry_id := buffer.get_u16()
			
			# spawn data
			var spawn_data: PackedByteArray = buffer.get_data(data_size)[1]
			var id := curr_id
			spawn_data.encode_u32(0, id)
			curr_id += 1
			
			var entity_ref: EntityReference = loaded_entities.get(id)
			
			if not entity_ref:
				entity_ref = EntityReference.new()
				loaded_entities[id] = entity_ref
			
			entity_ref.spawn_data = spawn_data
			entity_ref.registry_id = registry_id
			entity_ref.is_tile_entity = true
			
			# anchor entity
			var chunk := Vector2i(chunk_x, chunk_y)
			
			if chunk not in anchored_entities:
				anchored_entities[chunk] = []
			
			anchored_entities[chunk].append(id)

#endregion

#region Entity Updates
func send_update_important(entity_id: int, action_id: int, instant := true) -> void:
	receive_update_important.rpc(entity_id, action_id, NetworkTime.time, instant)

@rpc('authority', 'call_remote', 'reliable')
func receive_update_important(entity_id: int, action_id: int, time: float, instant := true) -> void:
	# make sure entity exists
	var entity_ref: EntityReference = loaded_entities.get(entity_id, null)
	if not entity_ref:
		return
	
	var entity := entity_ref.current_instance
	
	if not is_instance_valid(entity):
		return
	
	match action_id:
		Entity.KILL_ACTION:
			var buffer := StreamPeerBuffer.new()
			buffer.resize(2)
			
			# action id
			buffer.put_u16(action_id)
			
			if instant:
				entity.interpolator.perform_action(buffer.data_array)
			else:
				entity.interpolator.send_action(time, buffer.data_array)

@rpc('any_peer', 'call_remote', 'reliable')
func entity_receive_damage(entity_id: int, data: PackedByteArray) -> void:
	var entity := get_entity(entity_id)
	
	if entity:
		entity.hp.receive_damage(data)

#endregion

#region Interest Management
@rpc('any_peer', 'call_remote', 'reliable')
func load_region(start: Vector2i, width: int, height: int, player_id: int) -> void:
	for x in range(width):
		for y in range(height):
			load_chunk(Vector2i(start.x + x, start.y + y), player_id)

@rpc('any_peer', 'call_remote', 'reliable')
func load_chunk(chunk: Vector2i, player_id: int) -> void:
	for entity_id in anchored_entities.get(chunk, []):
		var reference: EntityReference = loaded_entities.get(entity_id)
		
		# clear null references
		if not reference:
			anchored_entities[chunk].erase(entity_id)
			loaded_entities.erase(entity_id)
			continue
		
		# switch replication logic
		if reference.is_tile_entity:
			# load on server if not already
			if not is_instance_valid(reference.current_instance):
				load_tile_entity(entity_id, reference.registry_id, reference.get_spawn_data())
			
			# mark new player as interested
			if is_instance_valid(reference.current_instance):
				# server-side interest ensures the entity won't despawn
				reference.current_instance.add_interest(player_id)
			
			# send to client
			load_tile_entity.rpc_id(player_id,
				entity_id, reference.registry_id,
				reference.get_spawn_data()
			)
		else:
			# load on server if not already
			if not is_instance_valid(reference.current_instance):
				load_entity(entity_id, reference.registry_id, reference.get_spawn_data())
			
			# mark new player as interested
			if is_instance_valid(reference.current_instance):
				reference.current_instance.add_interest(player_id)
			
			load_entity.rpc_id(player_id,
				entity_id, reference.registry_id,
				reference.get_spawn_data()
			)

func unload_chunk(chunk: Vector2i, player_id: int) -> void:
	print("Loaded chunk %s from player '%s'" % [chunk, player_id])

func erase_entity(entity: Entity) -> void:
	var ref: EntityReference = loaded_entities.get(entity.id)
	loaded_entities.erase(entity.id)
	
	if Globals.player:
		Globals.player.remove_interest(entity.id)
	
	# remove dynamic entities from anchored positions
	if ref and not ref.is_tile_entity:
		var chunk := entity.current_chunk
		
		if chunk in anchored_entities:
			anchored_entities[chunk].erase(entity.id)

func move_dynamic_entity(entity_id: int, prev_chunk: Vector2i, curr_chunk: Vector2i) -> void:
	# erase old chunk
	if prev_chunk in anchored_entities and entity_id in anchored_entities[prev_chunk]:
		anchored_entities[prev_chunk].erase(entity_id)
		
		if anchored_entities[prev_chunk].is_empty():
			anchored_entities.erase(prev_chunk)
	
	# add new chunk
	if curr_chunk not in anchored_entities:
		anchored_entities[curr_chunk] = []
	
	anchored_entities[curr_chunk].append(entity_id)

#endregion

#region Helper Functions
func get_entity(entity_id: int) -> Entity:
	# first make sure entity exists
	if entity_id not in loaded_entities:
		return null
	
	# check if entity has recently been queued
	if not is_instance_valid(loaded_entities[entity_id].current_instance):
		return null
	
	return loaded_entities[entity_id].current_instance

#endregion

#region Helper Classes
class EntityReference:
	var current_instance: Entity
	var spawn_data: PackedByteArray
	var is_tile_entity := false
	var registry_id := 0
	
	func get_spawn_data() -> PackedByteArray:
		# if instance exists, get most recent data
		if is_instance_valid(current_instance):
			return current_instance.serialize_spawn_data()
		# otherwise return cached data (primarily for tile entities)
		else:
			current_instance = null
			return spawn_data

#endregion
