extends Node

# -- Signals --- #
signal world_size_changed(size: Vector2i)

# --- Variables --- #
var world_size := Vector2i(4200, 1200):
	set(_size):
		@warning_ignore("integer_division")
		world_chunks = _size / TileManager.CHUNK_SIZE
		world_size = _size
		world_size_changed.emit(world_size)

@warning_ignore("integer_division")
var world_chunks := world_size / TileManager.CHUNK_SIZE
var world_spawn: Vector2i

# - TileMaps
var server_map: ServerTileMap
var world_map: WorldTileMap

# - Player Interactions
var hovered_hitbox: TileEntityHitbox

# - Player
var player: PlayerController

# - Items
var item_registry: Dictionary[int, String] = {}

# --- Functions --- #
func _ready() -> void:
	world_size = world_size
	
	crawl_item_registry("res://items", item_registry)

func parse_arguments() -> Dictionary:
	var arguments: Dictionary = {}
	
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		arg = arg.replace('--', '')
		if arg.contains('='):
			var tokens := arg.split('=')
			arguments[tokens[0]] = tokens[1]
		else:
			arguments[arg] = true
	
	return arguments

#region Items
func crawl_item_registry(root_dir: String, registry: Dictionary[int, String]) -> void:
	var entity_dir := DirAccess.open(root_dir)
	
	for dir_name in entity_dir.get_directories():
		if dir_name.begins_with("_"):
			continue
		
		var id_str := dir_name.split('_')[0]
		
		if not id_str.is_valid_int():
			printerr("[Wizbowo's Conquest] Cannot parse id from %s (got %s)" % [dir_name, id_str])
			continue
		
		var id := int(id_str)
		var dir := DirAccess.open(root_dir.path_join(dir_name))
		
		if dir.file_exists('item.tres'):
			registry[id] = root_dir.path_join(dir_name).path_join('item.tres')
		elif dir.file_exists('item.tres.remap'):
			registry[id] = root_dir.path_join(dir_name).path_join('item.tres').trim_suffix('.remap')
		else:
			printerr("[Wizbowo's Conquest] No file 'item.tres' found in directory %s" % dir_name)

func get_item(item_id: int) -> Item:
	if item_id in item_registry:
		return load(item_registry[item_id])
	
	printerr("[Wizbowo's Conquest] Failed to load item with id '%s'" % item_id)
	
	return null

#endregion
