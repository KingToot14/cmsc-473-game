class_name BackgroundManager
extends Node

# --- Variables --- #
const TRANSITION_TIME := 0.25

@export var biome_backgrounds: Dictionary[StringName, Node2D] = {}

var current_background: Node2D

# --- Functions --- #
func _ready() -> void:
	BiomeManager.biome_changed.connect(_on_biome_changed)
	
	_on_biome_changed(&'forest')

func _on_biome_changed(biome: StringName) -> void:
	if biome not in biome_backgrounds:
		return
	
	# switch backgrounds
	var new_background := biome_backgrounds[biome]
	
	if current_background and current_background != new_background:
		var tween := create_tween().set_parallel()
		
		current_background.modulate.a = 1.0
		current_background.show()
		new_background.modulate.a = 0.0
		new_background.show()
		
		tween.tween_property(current_background, ^'modulate:a', 0.0, TRANSITION_TIME)
		tween.tween_property(new_background, ^'modulate:a', 1.0, TRANSITION_TIME)
		tween.finished.connect(current_background.hide)
	else:
		new_background.show()
	
	current_background = new_background
