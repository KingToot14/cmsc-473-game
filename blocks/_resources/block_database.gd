extends Node

# --- Variables --- #
var blocks: Dictionary[int, BlockInfo] = {}
var walls: Dictionary[int, BlockInfo] = {}

# --- Functions --- #
func _ready() -> void:
	load_blocks()

func load_blocks() -> void:
	var base_path := "res://blocks/"
	var dir := DirAccess.open(base_path)
	if not dir:
		return

	for folder in dir.get_directories():
		var id_str := folder.split("_")[0]
		if not id_str.is_valid_int():
			continue

		var id := int(id_str)
		var item_path := base_path.path_join(folder).path_join("info.tres")
		
		if FileAccess.file_exists(item_path):
			blocks[id] = load(item_path)

func get_block(id: int) -> BlockInfo:
	return blocks.get(id, null)

func load_walls() -> void:
	var base_path := "res://walls/"
	var dir := DirAccess.open(base_path)
	if not dir:
		return

	for folder in dir.get_directories():
		var id_str := folder.split("_")[0]
		if not id_str.is_valid_int():
			continue

		var id := int(id_str)
		var item_path := base_path.path_join(folder).path_join("info.tres")
		
		if FileAccess.file_exists(item_path):
			walls[id] = load(item_path)

func get_wall(id: int) -> BlockInfo:
	return walls.get(id, null)
