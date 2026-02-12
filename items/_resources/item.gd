class_name Item
extends Resource

# --- Enums --- #
enum ItemType {
	MATERIAL,
	BLOCK,
	CONSUMABLE
}

# --- Variables --- #
@export var item_id: int = 0
@export var item_name: String
@export var texture: Texture2D

@export_multiline var tooltip: String

@export var item_type: ItemType
@export var max_stack: int = 99 #pretty sure this is gonna end up being extra
# --- Functions --- #
func consume() -> void:
	pass
