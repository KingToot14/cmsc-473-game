class_name WaterManager
extends Control

# --- Variables --- #
const TRANSITION_TIME := 0.25

var current_biome := BiomeManager.current_biome
var current_layer := BiomeManager.current_layer

var current_water := Color.BLUE
var current_foam := Color.BLUE

@export_group("Forest", "forest_")
@export var forest_water := Color.BLUE
@export var forest_foam := Color.BLUE

@export_group("Underground", "underground_")
@export var underground_water := Color.BLUE
@export var underground_foam := Color.BLUE

@export_group("Winter", "winter_")
@export var winter_water := Color.BLUE
@export var winter_foam := Color.BLUE

# --- Functions --- #
func _ready() -> void:
	BiomeManager.biome_changed.connect(_on_biome_changed)
	BiomeManager.layer_changed.connect(_on_layer_changed)

func _on_biome_changed(biome: StringName) -> void:
	current_biome = biome
	
	match biome:
		&'forest':
			# since forest is the "default" state, we need to also check layer
			match current_layer:
				&'space', &'surface':
					transition_to_water(forest_water, forest_foam)
				&'underground', &'cavern':
					transition_to_water(underground_water, underground_foam)
		&'winter':
			transition_to_water(winter_water, winter_foam)

func _on_layer_changed(layer: StringName) -> void:
	current_layer = layer
	
	# layer only matters for default underground (forest)
	if current_biome != &'forest':
		return
	
	match layer:
		&'space', &'surface':
			transition_to_water(forest_water, forest_foam)
		&'underground', &'cavern':
			transition_to_water(underground_water, underground_foam)

func transition_to_water(water_color: Color, foam_color: Color) -> void:
	var tween := create_tween().set_parallel()
	
	tween.tween_method(set_water_color, current_water, water_color, TRANSITION_TIME)
	tween.tween_method(set_foam_color,  current_foam,  foam_color,  TRANSITION_TIME)
	current_water = water_color
	current_foam = foam_color

func set_water_color(water_color: Color) -> void:
	material.set_shader_parameter(&'water_color', water_color)

func set_foam_color(foam_color: Color) -> void:
	material.set_shader_parameter(&'foam_color', foam_color)
