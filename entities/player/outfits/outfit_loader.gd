class_name OutfitLoader
extends Node2D

# --- Variables --- #
@export var shader_material: ShaderMaterial
@export var default_outfit: BaseOutfit
var curr_outfit: BaseOutfit

# --- Functions --- #
func _ready() -> void:
	curr_outfit = default_outfit
	randomize_outfit()

func randomize_outfit() -> void:
	if curr_outfit != null:
		load_outfit(curr_outfit, curr_outfit.get_primary_color(), curr_outfit.get_secondary_color())
	else:
		load_outfit(default_outfit, default_outfit.get_primary_color(), default_outfit.get_secondary_color())

func load_outfit(outfit: BaseOutfit, primary_color: Color, secondary_color: Color) -> void:
	$'arm_back'.texture  = outfit.base_arm_back
	$'leg_back'.texture  = outfit.base_leg_back
	$'body'.texture      = outfit.base_body
	$'leg_front'.texture = outfit.base_leg_front
	$'head'.texture      = outfit.base_head
	$'arm_front'.texture = outfit.base_arm_front
	
	$'arm_back_detail'.texture  = outfit.detail_arm_back
	$'leg_back_detail'.texture  = outfit.detail_leg_back
	$'body_detail'.texture      = outfit.detail_body
	$'leg_front_detail'.texture = outfit.detail_leg_front
	$'head_detail'.texture      = outfit.detail_head
	$'arm_front_detail'.texture = outfit.detail_arm_front
	
	shader_material.set_shader_parameter(&'primary_color', primary_color)
	shader_material.set_shader_parameter(&'secondary_color', secondary_color)
