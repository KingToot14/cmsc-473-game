class_name OutfitLoader
extends Node2D

# --- Variables --- #
@export var skin_material: ShaderMaterial
@export var outfit_material: ShaderMaterial
@export var default_outfit: BaseOutfit
var curr_outfit: BaseOutfit

@export var skin_tones: Array[Color] = []

# --- Functions --- #
func _ready() -> void:
	curr_outfit = default_outfit
	randomize_outfit()

func randomize_outfit() -> void:
	set_skin_tone(skin_tones.pick_random())
	
	if curr_outfit != null:
		load_outfit(curr_outfit, curr_outfit.get_primary_color(), curr_outfit.get_secondary_color())
	else:
		load_outfit(curr_outfit, Color.WHITE, Color.WHITE)

func set_skin_tone(skin_tone: Color) -> void:
	skin_material.set_shader_parameter(&'primary_color', skin_tone)

func load_outfit(outfit: BaseOutfit, primary_color: Color, secondary_color: Color) -> void:
	if outfit:
		$'arm_back_outfit'.texture  = outfit.base_arm_back
		$'leg_back_outfit'.texture  = outfit.base_leg_back
		$'body_outfit'.texture      = outfit.base_body
		$'leg_front_outfit'.texture = outfit.base_leg_front
		$'head_outfit'.texture      = outfit.base_head
		$'arm_front_outfit'.texture = outfit.base_arm_front
		
		$'arm_back_detail'.texture  = outfit.detail_arm_back
		$'leg_back_detail'.texture  = outfit.detail_leg_back
		$'body_detail'.texture      = outfit.detail_body
		$'leg_front_detail'.texture = outfit.detail_leg_front
		$'head_detail'.texture      = outfit.detail_head
		$'arm_front_detail'.texture = outfit.detail_arm_front
	else:
		$'arm_back_outfit'.texture  = null
		$'leg_back_outfit'.texture  = null
		$'body_outfit'.texture      = null
		$'leg_front_outfit'.texture = null
		$'head_outfit'.texture      = null
		$'arm_front_outfit'.texture = null
		
		$'arm_back_detail'.texture  = null
		$'leg_back_detail'.texture  = null
		$'body_detail'.texture      = null
		$'leg_front_detail'.texture = null
		$'head_detail'.texture      = null
		$'arm_front_detail'.texture = null
	
	# set shaders
	outfit_material.set_shader_parameter(&'primary_color', primary_color)
	outfit_material.set_shader_parameter(&'secondary_color', secondary_color)
