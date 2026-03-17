class_name BaseOutfit
extends Resource

# --- Variables --- #
@export var primary_colors: Array[Color] = []
@export var secondary_colors: Array[Color] = []

@export_group("Base Sprites", "base_")
@export var base_arm_back: Texture2D
@export var base_leg_back: Texture2D
@export var base_body: Texture2D
@export var base_leg_front: Texture2D
@export var base_head: Texture2D
@export var base_arm_front: Texture2D

@export_group("Detail Sprites", "detail_")
@export var detail_arm_back: Texture2D
@export var detail_leg_back: Texture2D
@export var detail_body: Texture2D
@export var detail_leg_front: Texture2D
@export var detail_head: Texture2D
@export var detail_arm_front: Texture2D

# --- Functions --- #
func get_primary_color() -> Color:
	return primary_colors.pick_random()

func get_secondary_color() -> Color:
	return secondary_colors.pick_random()
