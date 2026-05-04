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

## Identifies the main client that this player belongs to. This is set to
## [method MultiplayerAPI.get_unique_id] when initialized by the server.
@export var db_id := 1
@export var username: String

# - Positioning
## The current spawn point of the player. This defaults to [member Globals.world_spawn]
@export var spawn_point: Vector2i
## Points to a marker representing the center of the player entity
var center_point: Vector2:
	get():
		return $'center'.global_position

## Points to the camera's current position (which remains padded inside the world bounds)
var camera_point: Vector2:
	get():
		return $'camera'.global_position

## The max distance between which players can interact with entities and blocks
@export var base_range := 10.0

# - Movement
@onready var input_sync: InputSynchronizer = $'input_sync'
@onready var interpolator: PlayerInterpolator = $'snapshot_interpolator'

## The quickest that this player can move during normal movement
@export var move_max_speed := 120.0
## How quickly the player accelerates in [code]pixels/second[/code]
@export var move_acceleration := 100.0
## How quickly the player slows down in [code]pixels/second[/code].
## [br]Used when no input is being held and when turning around
@export var move_slowdown := 180.0
## How high the player jumps when they perform a jump. Sets [member base_velocity.y]
@export var jump_power := 350.0

var needs_respawn := false

var is_grounded := false

## How quickly the player accelerates towards the ground in [code]pixels/second[/cdoe]
@export var gravity := 980.0
## The maximum vertical velocity the player can be going when affected by [member gravity]
@export var terminal_velocity := 380.0

@export_group("Water", "water_")
@export var water_gravity_mod := 0.75
@export var water_movement_mod := 0.75
@export var water_jump_mod := 0.50

@export var water_breath := 10.0
var breath_timer := 0.0
@export var water_drown_damage := 1
var was_in_water := false  # Track water state for entry/exit sounds

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

@onready var sfx: EntitySfxManager = $'sfx'

var active := true

# --- Functions --- #
func _ready() -> void:
	await get_tree().process_frame
	
	$'rollback_sync'.process_settings()
	
	interpolator.owner_id = owner_id
	my_inventory.owner_id = owner_id
	
	# disable movement while loading new areas (for now, just on spawn)
	active = false
	$'chunk_loader'.area_loaded.connect(done_initial_load, CONNECT_ONE_SHOT)
	
	# add inventory to child (weird workaround for RPCs)
	my_inventory.name = "inventory"
	add_child(my_inventory)
	
	if owner_id != multiplayer.get_unique_id():
		interpolator.enabled = true
		
		# disable UI for remote players
		$'inventory_ui'.queue_free()
		$'health_ui'.queue_free()
		
		# disable overlays
		$'grid_overlay'.hide()
		$'water_overlay'.hide()
		
		# show name
		$'player_name'.text = username
		$'player_name'.show()
	else:
		# update position
		position = spawn_point
		
		# Ensure the sibling hotbar is visible
		$inventory_ui/hotbar_container.show()
		$inventory_ui/inventory_container.hide()
		$inventory_ui/crafting_container.hide()
		
		# Initialize the UIs
		$inventory_ui/inventory_container.setup_ui(my_inventory)
		$'health_ui'.setup_ui(hp)
	
	if multiplayer.is_server():
		setup_save_timer()
		hp.died.connect(_on_player_died)
	
	#connect armor signal
	my_inventory.armor_updated.connect(_on_armor_updated)

func _unhandled_input(event: InputEvent) -> void:
	if owner_id != multiplayer.get_unique_id():
		return
	
	if event.is_action_pressed(&"inventory_toggle"):
		var inv_container = $inventory_ui/inventory_container
		var craft_container = $inventory_ui/crafting_container
		var armor_container = $inventory_ui/armor_container
		
		inv_container.visible = !inv_container.visible
		craft_container.visible = !craft_container.visible
		armor_container.visible = !armor_container.visible
	
#region Animation
func _process(_delta: float) -> void:
	# update direction
	if velocity.x != 0.0 and can_turn():
		if face_direction == -1 and velocity.x > 0.0:
			face_direction = 1
		if face_direction == 1  and velocity.x < 0.0:
			face_direction = -1
	
	# update animation
	update_is_on_floor()
	if is_on_floor():
		if not is_grounded:
			# play land sfx
			sfx.play_sfx(&'land')
			
			is_grounded = true
		
		if abs(velocity.x) < 0.10:
			set_lower_animation(&'idle')
			set_upper_animation(&'idle')
		else:
			set_lower_animation(&'walk')
			set_upper_animation(&'walk')
	else:
		if is_grounded:
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
	return (
		$'animator_upper'.current_animation != &'swing_right' and
		$'animator_upper'.current_animation != &'swing_left'
	)

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
	z_index = 500 if mode else 25


## Run a rollback-friendly tick
func _rollback_tick(delta, _tick, _is_fresh) -> void:
	
	if needs_respawn:
		var world_position := TileManager.tile_to_world(Globals.world_spawn.x, Globals.world_spawn.y)
		global_position = world_position
		velocity = Vector2.ZERO
		base_velocity = Vector2.ZERO
		knockback_velocity = Vector2.ZERO
		pending_knockback = Vector2.ZERO
		needs_respawn = false
		
	if pending_knockback != Vector2.ZERO:
		knockback_velocity = pending_knockback
		base_velocity = Vector2.ZERO
		pending_knockback = Vector2.ZERO
	
	if active:
		apply_input(delta)

## Gather input from the [class InputSynchronizer] node at [code]$'input_sync'[/code]
func apply_input(delta: float) -> void:
	# check if feet in water
	var tile_pos := TileManager.world_to_tile(
		floori(global_position.x),
		floori(global_position.y)
	)
	
	var in_water := (
		TileManager.get_liquid_type(tile_pos.x, tile_pos.y) >= WaterUpdater.WATER_TYPE or
		TileManager.get_liquid_type(tile_pos.x + 1, tile_pos.y) >= WaterUpdater.WATER_TYPE
	) and (
		TileManager.get_liquid_level(tile_pos.x, tile_pos.y) > WaterUpdater.MAX_WATER_LEVEL * 0.50 or \
		TileManager.get_liquid_level(tile_pos.x + 1, tile_pos.y) > WaterUpdater.MAX_WATER_LEVEL * 0.50
	)
	
	# Play water entry/exit sounds
	if in_water and not was_in_water:
		Globals.music.play_water_entry_sound()
	elif not in_water and was_in_water:
		Globals.music.play_water_exit_sound()
	was_in_water = in_water
	
# Check for nearby water or lava (within 20 tile radius)
	var near_liquid := false
	var liquid_type = 0
	var closest_distance = 999.0
	
	for x in range(-20, 21):
		for y in range(-20, 21):
			var check_pos = tile_pos + Vector2i(x, y)
			var l_type = TileManager.get_liquid_type(check_pos.x, check_pos.y)
			var liquid_level = TileManager.get_liquid_level(check_pos.x, check_pos.y)
			
			# Check if it's water or lava and has sufficient level
			if l_type > 0 and liquid_level > WaterUpdater.MAX_WATER_LEVEL * 0.50:
				near_liquid = true
				liquid_type = l_type
				
				# Calculate distance to this liquid tile
				var distance = sqrt(float(x*x + y*y))
				if distance < closest_distance:
					closest_distance = distance
	
	# Update liquid ambience based on proximity with fade
	if near_liquid:
		# Calculate fade volume based on distance (0 to 20 tiles)
		# At 20 tiles away: quiet, at 0 tiles: loud
		var fade_volume = clamp(1.0 - (closest_distance / 20.0), 0.0, 1.0)
		var db = linear_to_db(fade_volume) if fade_volume > 0.0 else -80.0
		
		if not Globals.music._water_ambience_playing:
			if liquid_type == WaterUpdater.WATER_TYPE:
				Globals.music.start_water_ambience()
			else:  # Lava or other liquid
				Globals.music.start_lava_ambience()
		
		# Set volume based on distance
		Globals.music.set_liquid_ambience_volume(db)
	elif Globals.music._water_ambience_playing:
		Globals.music.stop_water_ambience()

	# check if head is under water
	var head_in_water := (
		TileManager.get_liquid_type(tile_pos.x, tile_pos.y) > WaterUpdater.WATER_TYPE or
		TileManager.get_liquid_type(tile_pos.x + 1, tile_pos.y) > WaterUpdater.WATER_TYPE
	) and (
		TileManager.get_liquid_level(tile_pos.x, tile_pos.y - 2) > WaterUpdater.MAX_WATER_LEVEL * 0.50 or \
		TileManager.get_liquid_level(tile_pos.x + 1, tile_pos.y - 2) > WaterUpdater.MAX_WATER_LEVEL * 0.50
	)
	
	# check if any tile is touching lava
	check_lava(tile_pos)
	
	# start drowning
	if head_in_water and not multiplayer.is_server():
		breath_timer -= delta
		
		if breath_timer <= 0.0:
			breath_timer = 0.0
			hp.take_damage(water_drown_damage, DamageSource.DamageSourceType.WORLD)
	else:
		breath_timer = water_breath
	
	# fixes a NetFox bug with is_on_floor()
	update_is_on_floor()
	if $'input_sync'.input_jump:
		if is_on_floor():
			sfx.play_sfx(&'jump')
			if in_water:
				velocity.y = -jump_power * water_jump_mod
			else:
				velocity.y = -jump_power
			pass
	
	# gravity
	if in_water:
		base_velocity.y = min(
			velocity.y + gravity * delta * water_gravity_mod, 
			terminal_velocity * water_gravity_mod
		)
	else:
		base_velocity.y = min(velocity.y + gravity * delta, terminal_velocity)
	
	# try to drop through platforms
	if is_on_floor() and $'input_sync'.input_direction.y > 0.0:
		position.y += 1.0
	
	# check free cam
	if $'input_sync'.input_free_cam:
		if not free_cam_pressed:
			free_cam_pressed = true
			set_free_cam_mode(not free_cam_mode)
	else:
		free_cam_pressed = false
	
	# move right
	var water_mod := 1.0
	if in_water:
		water_mod = water_movement_mod
	
	if $'input_sync'.input_direction.x > 0.0:
		# turn around quicker
		if base_velocity.x < -move_slowdown * delta:
			base_velocity.x += move_slowdown * delta
		# apply movement if not at max speed
		if base_velocity.x < move_max_speed:
			base_velocity.x += move_acceleration * delta * water_mod
	# move left
	elif $'input_sync'.input_direction.x < 0.0:
		# turn around quicker
		if base_velocity.x > move_slowdown * delta:
			base_velocity.x -= move_slowdown * delta
		# apply movement if not at max speed
		if base_velocity.x > -move_max_speed:
			base_velocity.x -= move_acceleration * delta * water_mod
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
		base_velocity.x = $'input_sync'.input_direction.x * move_max_speed * 10.0
		base_velocity.y = $'input_sync'.input_direction.y * move_max_speed * 10.0
	
	# clamp velocity
	velocity.x = clamp(velocity.x, -move_max_speed * water_mod, move_max_speed * water_mod)
	
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

func check_lava(tile_pos: Vector2i) -> void:
	for x in range(2):
		for y in range(3):
			# check if lava
			if TileManager.get_liquid_type(tile_pos.x + x, tile_pos.y - y):
				if TileManager.get_liquid_level(tile_pos.x + x, tile_pos.y - y) > 32:
					hp.take_damage(1, DamageSource.DamageSourceType.WORLD)
					return

## Force an [method is_on_floor] update since NetFox can have some issues when running
## rollbacks and detecting the floor.
func update_is_on_floor() -> void:
	# force an update of is_on_floor after rollbacks occur
	var temp_velocity := velocity
	velocity = Vector2.ZERO
	move_and_slide()
	velocity = temp_velocity

#endregion

#region Death and Respawn

func _on_player_died() -> void:
	print("Player ", db_id, " died! Respawning...")
	# tell all clients to run the respawn logic
	do_respawn.rpc()

@rpc('authority', 'call_local', 'reliable')
func do_respawn() -> void:
	# restore Health 
	hp.set_hp(hp.max_hp)
	needs_respawn=true
	
	# reset Position to World Spawn
	var world_position := TileManager.tile_to_world(Globals.world_spawn.x, Globals.world_spawn.y)
	global_position = world_position
	
	#kill any leftover momentum so they don't spawn flying
	velocity = Vector2.ZERO
	base_velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	pending_knockback = Vector2.ZERO
	
	#play a respawn sound for the local player
	if owner_id == multiplayer.get_unique_id():
		pass

#endregion

#region Loading
## The [ChunkLoader] has loaded and autotiled the initial region of tiles.
## [br]Enables input, the camera, and sets the camera bounds
func done_initial_load() -> void:
	active = true
	$'camera'.enabled = true
	$'camera'.limit_right  = (Globals.world_size.x) * TileManager.TILE_SIZE
	$'camera'.limit_bottom = (Globals.world_size.y) * TileManager.TILE_SIZE
	
	# hide ui
	Globals.join_ui.hide()
	
	if multiplayer.is_server():
		my_inventory.load_inventory(db_id)
	else:
		# update game state
		Globals.set_game_state(Globals.GameState.IN_GAME)
	
	# only change music for the local client
	if owner_id == multiplayer.get_unique_id():
		enter_biome(Globals.music.Area.FOREST_DAY)
		
		# enable shaders
		$'grid_overlay'.show()
		$'water_overlay'.show()
		$'lava_overlay'.show()
		$'glow_holder/lava_glow'.show()
		#$'light_overlay'.show()

#endregion

func enter_biome(area: MusicManager.Area) -> void:
	Globals.music.reset_area(area)
	Globals.music.play_track(area)

#region Interest
func add_interest(entity_id: int) -> void:
	interested_entities[entity_id] = true

func remove_interest(entity_id: int) -> void:
	interested_entities.erase(entity_id)

#endregion

#region Saving Stuff to Database

func setup_save_timer():
	var timer = Timer.new()
	timer.name = "SaveTimer"
	timer.wait_time = 10.0 # 10 seconds
	timer.autostart = true
	timer.timeout.connect(_on_save_timer_timeout)
	add_child(timer)

#currently only saves inventory stuff
func _on_save_timer_timeout():
	if not multiplayer.is_server():
		return
		
	print("Auto-saving inventory for player DB_ID: ", db_id)
	
	# save inventory to database using the database manager 
	var data = my_inventory.get_save_data()
	DatabaseManager.save_inventory(db_id, data)

func _exit_tree() -> void:
	# Only the server should be allowed to save to the database
	if multiplayer and multiplayer.is_server():
		print("Player disconnecting. Saving inventory for DB_ID: ", db_id)
		var data = my_inventory.get_save_data()
		DatabaseManager.save_inventory(db_id, data)

#region Helper Functions
## Returns whether or not [param point] is in range of this player.
## [br]Has an optional [param range_modifier] which gets added to
## [member base_range]
func is_point_in_range(point: Vector2, range_modifier := 0) -> bool:
	var player_range: float = (base_range + range_modifier) * TileManager.TILE_SIZE
	
	return point.distance_to(center_point) <= player_range

#endregion

#region Armor
func _on_armor_updated(slot_index: int) -> void:
	recalculate_defense()
	update_armor_visuals(slot_index)

func recalculate_defense() -> void:
	var total_defense = 0
	for stack in my_inventory.armor_items:
		if not stack.is_empty():
			var item_data = ItemDatabase.get_item(stack.item_id) as ArmorItem
			if item_data:
				total_defense += item_data.defense
	
	defense = total_defense #this updates your exported defense variable

func update_armor_visuals(slot_index: int) -> void:
	var stack = my_inventory.armor_items[slot_index]
	var equip_name = &'none'
	
	if not stack.is_empty():
		var item_data = ItemDatabase.get_item(stack.item_id) as ArmorItem
		if item_data:
			equip_name = item_data.armor_name
	
	#map the inventory slot index to the OutfitLoader BodySection enum
	var section: OutfitLoader.BodySection
	if slot_index == 0: section = OutfitLoader.BodySection.HEAD
	elif slot_index == 1: section = OutfitLoader.BodySection.BODY
	else: section = OutfitLoader.BodySection.LEGS
	
	#make sure your OutfitLoader node is accessible via $'outfit_loader'
	$'outfit'.load_armor(equip_name, section)
#endregion
