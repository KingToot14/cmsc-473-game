class_name PlayerController
extends CharacterBody2D

# --- Variables --- #
const INTERPOLATE_SPEED := 10.0

@export var owner_id := 1:
	set(id):
		# make sure only the client updates the movement
		$'input_sync'.set_multiplayer_authority(id)
		owner_id = id
		
		Globals.player = self

@export var spawn_point: Vector2i

@export var move_speed := 20.0

var free_cam_mode := false
var free_cam_pressed := false

# --- Functions --- #
func _ready() -> void:
	await get_tree().process_frame
	
	$'rollback_sync'.process_settings()
	
	$'snapshot_interpolator'.owner_id = owner_id
	
	if owner_id != multiplayer.get_unique_id():
		$'snapshot_interpolator'.enabled = true
	else:
		# update position + control camera
		position = spawn_point
		$'camera'.enabled = true

func set_free_cam_mode(mode: bool) -> void:
	free_cam_mode = mode
	$'shape'.disabled = free_cam_mode

func _rollback_tick(delta, _tick, _is_fresh) -> void:
	apply_input(delta)

func apply_input(_delta: float) -> void:
	# check free cam
	if $'input_sync'.input_free_cam:
		if not free_cam_pressed:
			free_cam_pressed = true
			set_free_cam_mode(not free_cam_mode)
	else:
		free_cam_pressed = false
	
	# update velocity
	velocity.x = $'input_sync'.input_direction.x * move_speed
	if free_cam_mode:
		velocity.y = $'input_sync'.input_direction.y * move_speed
	else:
		# apply normal gravity
		pass
	
	# move adjusted to netfox's physics
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func update_is_on_floor() -> void:
	# force an update of is_on_floor after rollbacks occur
	var temp_velocity := velocity
	velocity = Vector2.ZERO
	move_and_slide()
	velocity = temp_velocity
