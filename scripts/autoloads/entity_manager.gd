extends Node

# --- Variables --- #
var curr_id := 0

var enemy_registry: Array[String]
var tile_entity_registry: Array[String]

# --- Functions --- #
func _ready() -> void:
	# crawl files to add enemies to the list
	crawl_registry('res://entities/enemies', enemy_registry)
	crawl_registry('res://entities/tile_entities', tile_entity_registry)

func crawl_registry(root_dir: String, registry: Array[String]) -> void:
	var entity_dir := DirAccess.open(root_dir)
	
	registry.resize(len(entity_dir.get_directories()))
	
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
func spawn_entity(entity_id: int, position: Vector2i, spawn_data: Dictionary[StringName, Variant]) -> void:
	var entity: Entity = load(enemy_registry.get(entity_id)).instantiate()
	entity.position = position
	
	entity.initialize(curr_id, spawn_data)
	curr_id += 1
	
	get_tree().current_scene.get_node(^'entities').add_child(entity)

func spawn_tile_entity(entity_id: int, position: Vector2i, spawn_data: Dictionary[StringName, Variant]) -> void:
	var entity: Entity = load(tile_entity_registry.get(entity_id)).instantiate()
	entity.position = position
	
	entity.initialize(curr_id, spawn_data)
	curr_id += 1
	
	get_tree().current_scene.get_node(^'entities').add_child(entity)

@rpc('authority', 'call_remote', 'reliable')
func load_entity(
		entity_id: int, position: Vector2i, spawn_data: Dictionary[StringName, Variant], spawn_id: int
	) -> void:
	
	# setup new entity
	var entity: Entity = load(enemy_registry.get(entity_id)).instantiate()
	entity.position = position
	
	entity.initialize(spawn_id, spawn_data)
	
	get_tree().current_scene.get_node(^'entities').add_child(entity)

@rpc('authority', 'call_remote', 'reliable')
func load_tile_entity(
		entity_id: int, position: Vector2i, spawn_data: Dictionary[StringName, Variant], spawn_id: int
	) -> void:
	
	# setup new entity
	var entity: Entity = load(tile_entity_registry.get(entity_id)).instantiate()
	entity.position = position
	
	entity.initialize(spawn_id, spawn_data)
	
	get_tree().current_scene.get_node(^'entities').add_child(entity)

#endregion

#region Entity Management


#endregion
