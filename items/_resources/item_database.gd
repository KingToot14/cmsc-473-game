extends Node

var items: Dictionary[int, Item] = {}

func _ready() -> void:
	load_items()

func load_items() -> void:
	var base_path := "res://items/"
	var dir := DirAccess.open(base_path)
	if not dir:
		return

	for folder in dir.get_directories():
		var id_str := folder.split("_")[0]
		if not id_str.is_valid_int():
			continue

		var id := int(id_str)
		var item_path := base_path.path_join(folder).path_join("item.tres")

		if FileAccess.file_exists(item_path):
			items[id] = load(item_path)

func get_item(id: int) -> Item:
	return items.get(id, null)
