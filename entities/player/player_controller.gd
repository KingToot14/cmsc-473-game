class_name PlayerController
extends CharacterBody2D

# --- Variables --- #
const INTERPOLATE_SPEED := 10.0

@export var owner_id := 1:
	set(id):
		# make sure only the client updates the movement
		$'input_sync'.set_multiplayer_authority(id)
		owner_id = id

@export var spawn_point: Vector2i

@export var move_speed := 20.0

# --- Functions --- #
func _ready() -> void:
	await get_tree().process_frame
	
	$'rollback_sync'.process_settings()
	
	$'snapshop_interpolator'.owner_id = owner_id
	
	if owner_id != multiplayer.get_unique_id():
		$'snapshop_interpolator'.enabled = true
		$'sprite'.top_level = true
	else:
		position = spawn_point

func _rollback_tick(delta, _tick, _is_fresh) -> void:
	apply_input(delta)

func apply_input(_delta: float) -> void:
	# update velocity
	velocity.x = $'input_sync'.input_direction.x * move_speed
	
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
