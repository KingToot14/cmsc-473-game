class_name ArmorItem
extends Item # Change this to whatever your base item class is named if different

enum ArmorType { HEAD, BODY, LEGS }

@export var armor_type: ArmorType
@export var defense: int = 0
@export var armor_name: StringName # e.g., "iron_armor" to pass to OutfitLoader
@export var armor_set: ArmorSet # Visual resource for the sprites

func _init() -> void:
	max_stack = 1
