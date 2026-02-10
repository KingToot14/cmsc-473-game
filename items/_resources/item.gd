class_name Item
extends Resource

# --- Enums --- #
enum ItemType {
	MATERIAL,
	BLOCK,
	CONSUMABLE
}

# --- Variables --- #
@export var item_name: String
@export var texture: Texture2D

@export_multiline var tooltip: String

@export var item_type: ItemType

# --- Functions --- #
func consume() -> void:
	pass
