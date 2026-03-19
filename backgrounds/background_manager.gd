class_name BackgroundManager
extends Node

# --- Variables --- #
@export var biome_backgrounds: Dictionary[StringName, Node2D] = {}

var current_background: Node2D

# --- Functions --- #
func _ready() -> void:
	BiomeManager.biome_changed.connect(_on_biome_changed)
	BiomeManager.layer_changed.connect(_on_layer_changed)
	
	_on_biome_changed(BiomeManager.Biome.FOREST)

func _on_biome_changed(_biome: BiomeManager.Biome) -> void:
	for background: Background in get_tree().get_nodes_in_group(&'background'):
		background.update_background(BiomeManager.current_biome, BiomeManager.current_layer)

func _on_layer_changed(_layer: BiomeManager.Layer) -> void:
	for background: Background in get_tree().get_nodes_in_group(&'background'):
		background.update_background(BiomeManager.current_biome, BiomeManager.current_layer)
