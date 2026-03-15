class_name WaterManager
extends Control

# --- Variables --- #
const TRANSITION_TIME := 0.25

var current_biome: StringName
var current_layer: StringName

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

func _on_biome_changed(biome: StringName) -> void:
	var tween := create_tween().set_parallel()
	
	match biome:
		&'forest':
			tween.tween_method(set_water_color, current_water, forest_water, TRANSITION_TIME)
			tween.tween_method(set_foam_color,  current_foam,  forest_foam,  TRANSITION_TIME)
			current_water = forest_water
			current_foam = forest_foam
		&'winter':
			tween.tween_method(set_water_color, current_water, winter_water, TRANSITION_TIME)
			tween.tween_method(set_foam_color,  current_foam,  winter_foam,  TRANSITION_TIME)
			current_water = winter_water
			current_foam = winter_foam

func set_water_color(water_color: Color) -> void:
	material.set_shader_parameter(&'water_color', water_color)

func set_foam_color(foam_color: Color) -> void:
	material.set_shader_parameter(&'foam_color', foam_color)
