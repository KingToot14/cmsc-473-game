class_name TestingCamera
extends Camera2D

# --- Variables --- #
@export var move_speed := 300.0
var direction: Vector2

# --- Functions --- #
func _process(delta: float) -> void:
	direction = Vector2(
		Input.get_axis(&'move_left', &'move_right'),
		Input.get_axis(&'move_up', &'move_down') 
	)
	
	position = Vector2(Vector2i(position + direction * move_speed * delta))
