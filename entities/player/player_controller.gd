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
var my_inventory := inventory.new()

var active := true

# --- Functions --- #
func _ready() -> void:
	await get_tree().process_frame
	
	$'rollback_sync'.process_settings()
	
	$'snapshot_interpolator'.owner_id = owner_id
	
	# disable movement while loading new areas (for now, just on spawn)
	active = false
	$'chunk_loader'.area_loaded.connect(done_initial_load, CONNECT_ONE_SHOT)
	
	if owner_id != multiplayer.get_unique_id():
		$'snapshot_interpolator'.enabled = true
	else:
		# update position + control camera
		position = spawn_point
		#$'camera'.enabled = true
#	$inventory_ui/inventory_container.setup_ui(my_inventory)

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&'test_input'):
		return
	
	var mouse_pos := get_local_mouse_position() + global_position
	var tile_pos := TileManager.world_to_tile(floori(mouse_pos.x), floori(mouse_pos.y))
	
	var this_pos := TileManager.world_to_tile(floori(global_position.x), floori(global_position.y))
	
	print(mouse_pos, " | ", tile_pos, " | ", global_position, " | ", this_pos)
	print(TileManager.get_block(tile_pos.x, tile_pos.y))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory_toggle"):
		$inventory_ui.visible = !$inventory_ui.visible

func set_free_cam_mode(mode: bool) -> void:
	free_cam_mode = mode
	$'shape'.disabled = free_cam_mode

func _rollback_tick(delta, _tick, _is_fresh) -> void:
	if active:
		apply_input(delta)

func apply_input(_delta: float) -> void:
	var gravity := 980.0
	var terminal_velocity := 380.0
	if $'input_sync'.input_jump:
		if is_on_floor():
			velocity.y = -400
			pass
	
		# gravity
	velocity.y = clampf(velocity.y + gravity * _delta, -terminal_velocity, terminal_velocity)
	
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

func done_initial_load() -> void:
	active = true
	$'camera'.enabled = true
	
	# hide ui
	get_tree().current_scene.get_node(^'join_ui').hide()
