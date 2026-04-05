extends Node

# --- Variables --- #
## References to a block's info. The key is the [code]block_id[/code].
var blocks: Dictionary[int, BlockInfo] = {}
## References to a wall's info. The key is the [code]wall_id[/code].
var walls: Dictionary[int, BlockInfo] = {}

## The largest block id
var _max_block_id := 0
## The largest wall id
var _max_wall_id := 0

## Whether or not a block id is "solid". Index into the array with the
## [code]block_id[/code].
var is_solid: Array[bool] = []

# --- Functions --- #
func _ready() -> void:
	load_blocks()
	load_walls()
	
	# load block properties
	is_solid.resize(_max_block_id + 1)
	
	for id in range(_max_block_id + 1):
		var info := get_block(id)
		if not info:
			continue
		
		if info.is_solid:
			is_solid[id] = true

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
			
			_max_block_id = max(_max_block_id, id)

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
			
			_max_wall_id = max(_max_wall_id, id)

func get_wall(id: int) -> BlockInfo:
	return walls.get(id, null)
