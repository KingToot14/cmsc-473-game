class_name WaterManager
extends Control

# --- Variables --- #
const TRANSITION_TIME := 0.25

var current_biome := BiomeManager.current_biome
var current_layer := BiomeManager.current_layer

var current_water := Color.BLUE
var current_foam := Color.BLUE

@export var water_rules: Dictionary[StringName, WaterRule]

# --- Functions --- #
func _ready() -> void:
	BiomeManager.biome_changed.connect(_on_biome_changed)
	BiomeManager.layer_changed.connect(_on_layer_changed)
	
	transition_to_water(water_rules.get(current_biome))

func _on_biome_changed(biome: StringName) -> void:
	current_biome = biome
	
	transition_to_water(water_rules.get(current_biome))

func _on_layer_changed(layer: StringName) -> void:
	current_layer = layer
	
	transition_to_water(water_rules.get(current_biome))

func transition_to_water(water_rule: WaterRule) -> void:
	var water_color := water_rule.water_color
	var foam_color  := water_rule.foam_color
	
	if water_rule.has_underground_color and current_layer in [&'underground', &'cavern']:
		water_color = water_rule.underground_water
		foam_color  = water_rule.underground_foam
	
	var tween := create_tween().set_parallel()
	
	tween.tween_method(set_water_color, current_water, water_color, TRANSITION_TIME)
	tween.tween_method(set_foam_color,  current_foam,  foam_color,  TRANSITION_TIME)
	current_water = water_color
	current_foam = foam_color

func set_water_color(water_color: Color) -> void:
	material.set_shader_parameter(&'water_color', water_color)

func set_foam_color(foam_color: Color) -> void:
	material.set_shader_parameter(&'foam_color', foam_color)
