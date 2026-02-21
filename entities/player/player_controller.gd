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
@export var move_max_speed := 120.0
@export var move_acceleration := 100.0
@export var move_slowdown := 180.0
@export var jump_power := 350.0

@export var gravity := 980.0
@export var terminal_velocity := 380.0

@export var knockback_power := 200.0
var base_velocity: Vector2
var knockback_velocity: Vector2
var pending_knockback: Vector2

# - Combat
@export_group("Combat")
@export var hp: EntityHp
@export var defense := 0

@export var flash_material: ShaderMaterial

var free_cam_mode := false
var free_cam_pressed := false

# - Inventory
var my_inventory := Inventory.new()

# - Entity Interest
var interested_entities: Dictionary[int, bool] = {}

# - Visuals
var face_direction := 1

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
		
		# Ensure the sibling hotbar is visible
		$inventory_ui/hotbar_container.show()
		
		# Initialize the UI via the script on the container
		$inventory_ui/inventory_container.setup_ui(my_inventory)

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
		var container = $inventory_ui/inventory_container
		container.visible = !container.visible
		
		# Mouse logic
		if container.visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

#region Animation
func _process(_delta: float) -> void:
	# update direction
	if velocity.x != 0.0 and signf(velocity.x) != face_direction:
		face_direction = -face_direction
		
		for child in $'outfit'.get_children():
			child.flip_h = not child.flip_h
	
	# update animation
	update_is_on_floor()
	if is_on_floor():
		if abs(velocity.x) < 0.10:
			set_lower_animation(&'idle')
			set_upper_animation(&'idle')
		else:
			set_lower_animation(&'walk')
			set_upper_animation(&'walk')
	else:
		if velocity.y < 0.0:
			set_lower_animation(&'jump')
			set_upper_animation(&'jump')
		else:
			set_lower_animation(&'fall')
			set_upper_animation(&'fall')

func set_lower_animation(animation: StringName) -> void:
	if $'animator_lower'.current_animation != animation:
		$'animator_lower'.play(animation)

func set_upper_animation(animation: StringName) -> void:
	if $'animator_upper'.current_animation != animation:
		$'animator_upper'.play(animation)

#endregion

#region Physics
func set_free_cam_mode(mode: bool) -> void:
	free_cam_mode = mode
	$'shape'.disabled = free_cam_mode

func _rollback_tick(delta, _tick, _is_fresh) -> void:
	# update knockback (rollback-friendly)
	if pending_knockback != Vector2.ZERO:
		knockback_velocity = pending_knockback
		base_velocity = Vector2.ZERO
		pending_knockback = Vector2.ZERO
	
	# apply input if active
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
	base_velocity.y = min(velocity.y + gravity * delta, terminal_velocity)
	
	# check free cam
	if $'input_sync'.input_free_cam:
		if not free_cam_pressed:
			free_cam_pressed = true
			set_free_cam_mode(not free_cam_mode)
	else:
		free_cam_pressed = false
	
	# move right
	if $'input_sync'.input_direction.x > 0.0:
		# turn around quicker
		if base_velocity.x < -move_slowdown * delta:
			base_velocity.x += move_slowdown * delta
		# apply movement if not at max speed
		if base_velocity.x < move_max_speed:
			base_velocity.x += move_acceleration * delta
	# move left
	elif $'input_sync'.input_direction.x < 0.0:
		# turn around quicker
		if base_velocity.x > move_slowdown * delta:
			base_velocity.x -= move_slowdown * delta
		# apply movement if not at max speed
		if base_velocity.x > -move_max_speed:
			base_velocity.x -= move_acceleration * delta
	# slow down
	else:
		# reduce friction in air
		var air_modifier := 0.5
		if is_on_floor():
			air_modifier = 1.0
		
		# apply friction
		if base_velocity.x > move_slowdown * delta * air_modifier:
			base_velocity.x -= move_slowdown * delta * air_modifier
		elif base_velocity.x < -move_slowdown * delta * air_modifier:
			base_velocity.x += move_slowdown * delta * air_modifier
		else:
			base_velocity.x = 0.0
	
	if free_cam_mode:
		base_velocity.y = $'input_sync'.input_direction.y * move_max_speed
	
	# clamp velocity
	velocity.x = clamp(velocity.x, -move_max_speed, move_max_speed)
	
	# apply knockback
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_power * 4.0 * delta)
	if not is_on_floor():
		knockback_velocity.y = 0.0
	
	# combine velocity
	velocity = base_velocity + knockback_velocity
	
	# move adjusted to netfox's physics
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	
	# keep inside world boundaries
	global_position = global_position.clamp(Vector2(4, 4), TileManager.tile_to_world(
			Globals.world_size.x,
			Globals.world_size.y
		) - Vector2(4, 4)
	)

func update_is_on_floor() -> void:
	# force an update of is_on_floor after rollbacks occur
	var temp_velocity := velocity
	velocity = Vector2.ZERO
	move_and_slide()
	velocity = temp_velocity

@rpc('authority', 'call_remote', 'reliable')
func receive_damage_snapshot(snapshot: Dictionary) -> void:
	# apply knockback (if not dead)
	if not snapshot.get(&'entity_dead', false) or true:
		pending_knockback = snapshot.get(&'knockback', Vector2.ZERO) * knockback_power
	
	if not flash_material:
		return
	
	flash_material.set_shader_parameter(&'intensity', 1.0)
	
	var flash_tween := create_tween()
	
	flash_tween.tween_method(func (x):
		flash_material.set_shader_parameter(&'intensity', x),
		1.0, 0.0, 0.15
	)

#endregion

#region Loading
func done_initial_load() -> void:
	active = true
	$'camera'.enabled = true
	$'camera'.limit_right  = (Globals.world_size.x) * TileManager.TILE_SIZE
	$'camera'.limit_bottom = (Globals.world_size.y) * TileManager.TILE_SIZE
	
	# hide ui
	get_tree().current_scene.get_node(^'join_ui').hide()

#endregion

#region Interest
func add_interest(entity_id: int) -> void:
	interested_entities[entity_id] = true

func remove_interest(entity_id: int) -> void:
	interested_entities.erase(entity_id)

#endregion
