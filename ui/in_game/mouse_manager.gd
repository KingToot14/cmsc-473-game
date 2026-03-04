class_name MouseManager
extends Control

# --- Variables --- #
@export var player: PlayerController

@export var grid_overlay: Control

# --- Functions --- #
func _process(delta: float) -> void:
	grid_overlay.global_position = Vector2(
		floorf((player.global_position.x - grid_overlay.size.x / 2.0) / 8.0) * 8.0,
		floorf((player.global_position.y - grid_overlay.size.y / 2.0) / 8.0) * 8.0
	)
	
	RenderingServer.global_shader_parameter_set(&"mouse_position", player.get_global_mouse_position())
