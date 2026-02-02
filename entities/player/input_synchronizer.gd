class_name InputSynchronizer
extends Node

# --- Variables --- #
@export var player: PlayerController
@export var input_direction: Vector2
@export var input_jump := false
@export var input_free_cam := false

# --- Functions --- #
func _ready() -> void:
	# disable processing on anything but the owner
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		return
	
	NetworkTime.before_tick_loop.connect(_gather)

func _gather() -> void:
	if not is_multiplayer_authority():
		return
	
	input_direction = Vector2(
		Input.get_axis(&'move_left', &'move_right'),
		Input.get_axis(&'move_up', &'move_down')
	)
	
	input_jump = Input.is_action_pressed(&'jump')
	input_free_cam = Input.is_action_pressed(&'free_cam')
