class_name WaterManager
extends Control

# --- Variables --- #
const TRANSITION_TIME := 0.25

const UNDERGROUND_LAYERS: Array[BiomeManager.Layer] = [
	BiomeManager.Layer.UNDERGROUND,
	BiomeManager.Layer.CAVERN
]

var current_biome := BiomeManager.current_biome
var current_layer := BiomeManager.current_layer

var current_water := Color.BLUE
var current_foam := Color.BLUE

@export var water_rules: Dictionary[BiomeManager.Biome, WaterRule]

# --- Functions --- #
func _ready() -> void:
	BiomeManager.biome_changed.connect(_on_biome_changed)
	BiomeManager.layer_changed.connect(_on_layer_changed)
	
	transition_to_water(water_rules.get(current_biome))

func _on_biome_changed(biome: BiomeManager.Biome) -> void:
	current_biome = biome
	
	transition_to_water(water_rules.get(current_biome))

func _on_layer_changed(layer: BiomeManager.Layer) -> void:
	current_layer = layer
	
	transition_to_water(water_rules.get(current_biome))

func transition_to_water(water_rule: WaterRule) -> void:
	if OS.has_feature('dedicated_server'):
		return
	if water_rule == null:
		push_warning("WaterManager: No WaterRule found for biome %s" % current_biome)
		return
	var water_color := water_rule.water_color
	var foam_color  := water_rule.foam_color
	
	if water_rule.has_underground_color and current_layer in UNDERGROUND_LAYERS:
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
