class_name PlayerController
extends CharacterBody2D

# --- Variables --- #
const INTERPOLATE_SPEED := 10.0

@export var owner_id := 1:
	set(id):
		# make sure only the client updates the movement
		$'input_sync'.set_multiplayer_authority(id)
		owner_id = id
		
		# set server reference
		ServerManager.connected_players[id] = self
		
		if multiplayer and multiplayer.get_unique_id() == id:
			Globals.player = self

# - Positioning
@export var spawn_point: Vector2i
var center_point: Vector2:
	get():
		return $'center'.global_position

# - Movement
@export var move_speed := 20.0
@export var jump_power := 180.0

@export var gravity := 980.0
@export var terminal_velocity := 380.0

var free_cam_mode := false
var free_cam_pressed := false

# - Inventory
var my_inventory := Inventory.new()

# - Entity Interest
var interested_entities: Dictionary[int, bool] = {}

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
		# update position
		position = spawn_point
#	$inventory_ui/inventory_container.setup_ui(my_inventory)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory_toggle"):
		$inventory_ui.visible = !$inventory_ui.visible

func set_free_cam_mode(mode: bool) -> void:
	free_cam_mode = mode
	$'shape'.disabled = free_cam_mode

func _rollback_tick(delta, _tick, _is_fresh) -> void:
	if active:
		apply_input(delta)

func apply_input(delta: float) -> void:
	# fixes a NetFox bug with is_on_floor()
	update_is_on_floor()
	if $'input_sync'.input_jump:
		if is_on_floor():
			velocity.y = -jump_power
			pass
	
	# gravity
	velocity.y = clampf(velocity.y + gravity * delta, -terminal_velocity, terminal_velocity)
	
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

#region Loading
func done_initial_load() -> void:
	active = true
	$'camera'.enabled = true
	
	# hide ui
	get_tree().current_scene.get_node(^'join_ui').hide()

#endregion

#region Interest
func add_interest(entity_id: int) -> void:
	interested_entities[entity_id] = true

func remove_interest(entity_id: int) -> void:
	interested_entities.erase(entity_id)

#endregion
