class_name PlayerController
extends CharacterBody2D

# --- Variables --- #
const INTERPOLATE_SPEED := 10.0

## Identifies the main client that this player belongs to. This is set to
## [method MultiplayerAPI.get_unique_id] when initialized by the server.
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
## The current spawn point of the player. This defaults to [member Globals.world_spawn]
@export var spawn_point: Vector2i
## Points to a marker representing the center of the player entity
var center_point: Vector2:
	get():
		return $'center'.global_position

## The max distance between which players can interact with entities and blocks
@export var base_range := 10.0

# - Movement
@onready var input_sync: InputSynchronizer = $'input_sync'
@onready var snapshot_interpolator: SnapshotInterpolator = $'snapshot_interpolator'

## The quickest that this player can move during normal movement
@export var move_max_speed := 120.0
## How quickly the player accelerates in [code]pixels/second[/code]
@export var move_acceleration := 100.0
## How quickly the player slows down in [code]pixels/second[/code].
## [br]Used when no input is being held and when turning around
@export var move_slowdown := 180.0
## How high the player jumps when they perform a jump. Sets [member base_velocity.y]
@export var jump_power := 350.0

var is_grounded := false

## How quickly the player accelerates towards the ground in [code]pixels/second[/cdoe]
@export var gravity := 980.0
## The maximum vertical velocity the player can be going when affected by [member gravity]
@export var terminal_velocity := 380.0

## How strong incoming knockback is applied. Represents the player's "weight"
@export var knockback_power := 200.0
## The base velocity derived from movement (left/right movement, jumping, etc.)
var base_velocity: Vector2
## Velocity derived from incoming attakcs that deal knockback damage
var knockback_velocity: Vector2
## Velocity that is waiting to be applied in the [method _rollback_tick] in order
## to maintain functionality when using NetFox
var pending_knockback: Vector2

# - Combat
@export_group("Combat")
## The [class PlayerHp] component used for this player
@export var hp: PlayerHp
## How much defense the player has. Defense linearly reduces incoming damage
## (to a minimum of 1 damage per attack)
@export var defense := 0

# - Animation
const ANIMATION_PRIORITY: Dictionary[StringName, int] = {
	&'idle': 1,
	&'walk': 1,
	&'jump': 1,
	&'fall': 1,
	&'swing_left': 2,
	&'swing_right': 2
}

## Whether or not free-cam mode is active (This will eventually be removed)
var free_cam_mode := false
## Whether or not the free-cam mode was previously pressed (prevents chaotically
## swapping free-cam modes)
var free_cam_pressed := false

# - Inventory
## The player's inventory
var my_inventory := Inventory.new()

# - Entity Interest
## Entities that are "interested" in this player (within the player's load range)
var interested_entities: Dictionary[int, bool] = {}

# - Visuals
## Which way the player is currenly facing ([code]-1[/code] for left, [code]1[/code] for right)
var face_direction := 1:
	set(_dir):
		face_direction = _dir
		
		for child in $'outfit'.get_children():
			if child is not Sprite2D:
				continue  
			child.flip_h = face_direction == -1

var active := true

# --- Functions --- #
func _ready() -> void:
	await get_tree().process_frame
	
	$'rollback_sync'.process_settings()
	
	$'snapshot_interpolator'.owner_id = owner_id
	
	# disable movement while loading new areas (for now, just on spawn)
	active = false
	$'chunk_loader'.area_loaded.connect(done_initial_load, CONNECT_ONE_SHOT)
	
	if multiplayer.is_server():
		my_inventory.load_inventory()
	
	if owner_id != multiplayer.get_unique_id():
		$'snapshot_interpolator'.enabled = true
		
		# disable inventory ui
		$'inventory_ui'.queue_free()
	else:
		# update position
		position = spawn_point
		
		# setup inventory
		my_inventory.load_inventory()
		
		# Ensure the sibling hotbar is visible
		$inventory_ui/hotbar_container.show()
		$inventory_ui/inventory_container.hide()
		
		# Initialize the UI via the script on the container
		$inventory_ui/inventory_container.setup_ui(my_inventory)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory_toggle"):
		var container = $inventory_ui/inventory_container
		container.visible = !container.visible

#region Animation
func _process(_delta: float) -> void:
	# update direction
	if velocity.x != 0.0 and can_turn():
		var changed := false
		
		if face_direction == -1 and velocity.x > 0.0:
			face_direction = 1
			changed = true
		if face_direction == 1  and velocity.x < 0.0:
			face_direction = -1
			changed = true
	
	# update animation
	update_is_on_floor()
	if is_on_floor():
		if not is_grounded:
			$'audio_player'.play_sfx(PlayerSfxManager.SFX.LAND)
			
			is_grounded = true
		
		if abs(velocity.x) < 0.10:
			set_lower_animation(&'idle')
			set_upper_animation(&'idle')
		else:
			set_lower_animation(&'walk')
			set_upper_animation(&'walk')
	else:
		if is_grounded:
			$'audio_player'.play_sfx(PlayerSfxManager.SFX.LAND)
			
			is_grounded = false
		
		if velocity.y < 0.0:
			set_lower_animation(&'jump')
			set_upper_animation(&'jump')
		else:
			set_lower_animation(&'fall')
			set_upper_animation(&'fall')

## Sets the lower-body animation (animates the front and back legs)
func set_lower_animation(animation: StringName, play_speed := 1.0) -> void:
	var curr_priority: int = ANIMATION_PRIORITY.get($'animator_lower'.current_animation, 0)
	var new_priority: int = ANIMATION_PRIORITY.get(animation, 0)
	
	if new_priority < curr_priority:
		return
	
	if $'animator_lower'.current_animation != animation:
		$'animator_lower'.speed_scale = play_speed
		$'animator_lower'.play(animation)

## Sets the upper-body animation (animates the torso, head, and arms)
func set_upper_animation(animation: StringName, play_speed := 1.0) -> void:
	var curr_priority: int = ANIMATION_PRIORITY.get($'animator_upper'.current_animation, 0)
	var new_priority: int = ANIMATION_PRIORITY.get(animation, 0)
	
	if new_priority < curr_priority:
		return
	
	if $'animator_upper'.current_animation != animation:
		$'animator_upper'.speed_scale = play_speed
		$'animator_upper'.play(animation)

func can_turn() -> bool:
	return (
		$'animator_upper'.current_animation != &'swing_right' and
		$'animator_upper'.current_animation != &'swing_left'
	)

func can_act() -> bool:
	return can_turn()

func do_swing(swing_speed := 1.0, direction := 0) -> void:
	if direction != 0:
		face_direction = direction
	
	if face_direction == 1:
		set_upper_animation(&'swing_right', swing_speed)
	elif face_direction == -1:
		set_upper_animation(&'swing_left', swing_speed)

#endregion

#region Physics
## Enables/Disables free-cam mode
func set_free_cam_mode(mode: bool) -> void:
	free_cam_mode = mode
	$'shape'.disabled = free_cam_mode

## Run a rollback-friendly tick
func _rollback_tick(delta, _tick, _is_fresh) -> void:
	# update knockback (rollback-friendly)
	if pending_knockback != Vector2.ZERO:
		knockback_velocity = pending_knockback
		base_velocity = Vector2.ZERO
		pending_knockback = Vector2.ZERO
	
	# apply input if active
	if active:
		apply_input(delta)

## Gather input from the [class InputSynchronizer] node at [code]$'input_sync'[/code]
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

## Force an [method is_on_floor] update since NetFox can have some issues when running
## rollbacks and detecting the floor.
func update_is_on_floor() -> void:
	# force an update of is_on_floor after rollbacks occur
	var temp_velocity := velocity
	velocity = Vector2.ZERO
	move_and_slide()
	velocity = temp_velocity

## Handles an incomming damage snapshot
@rpc('authority', 'call_remote', 'reliable')
func receive_damage_snapshot(snapshot: Dictionary) -> void:
	# apply knockback (if not dead)
	if not snapshot.get(&'entity_dead', false) or true:
		pending_knockback = snapshot.get(&'knockback', Vector2.ZERO) * knockback_power

#endregion

#region Loading
## The [class ChunkLoader] has loaded and autotiled the initial region of tiles.
## [br]Enables input, the camera, and sets the camera bounds
func done_initial_load() -> void:
	active = true
	$'camera'.enabled = true
	$'camera'.limit_right  = (Globals.world_size.x) * TileManager.TILE_SIZE
	$'camera'.limit_bottom = (Globals.world_size.y) * TileManager.TILE_SIZE
	
	# hide ui
	get_tree().current_scene.get_node(^'join_ui').hide()
	
	# swtich track to music TODO: Move this to a a function in biome manager when implemented
	Globals.music.play_track(MusicManager.Area.FOREST_DAY, 1)

#endregion

#region Interest
func add_interest(entity_id: int) -> void:
	interested_entities[entity_id] = true

func remove_interest(entity_id: int) -> void:
	interested_entities.erase(entity_id)

#endregion
