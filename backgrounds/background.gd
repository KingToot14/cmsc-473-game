class_name Background
extends Node2D

# --- Variables --- #
const TRANSITION_TIME := 0.50

var tween: Tween

@export_flags(
	'space', 'surface', 'underground', 'cavern', 'underworld'
) var allowed_layers := 0

@export_flags(
	'forest', 'desert', 'snow', 'ocean'
) var allowed_biomes := 0

# --- Functions --- #
func update_background(biome: BiomeManager.Biome, layer: BiomeManager.Layer) -> void:
	if (biome & allowed_biomes) and (layer & allowed_layers):
		if tween:
			tween.kill()
		tween = create_tween()
		
		tween.tween_property(self, ^'modulate:a', 1.0, TRANSITION_TIME)
	else:
		if tween:
			tween.kill()
		tween = create_tween()
		
		tween.tween_property(self, ^'modulate:a', 0.0, TRANSITION_TIME)
