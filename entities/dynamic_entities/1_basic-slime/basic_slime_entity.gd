class_name BasicSlimeEntity
extends Entity

# --- Variables --- #
const POSITION_REMAIN_RANGE := (2.0 * TileManager.TILE_SIZE)**2
const POSITION_ADJUST_RANGE := (6.0 * TileManager.TILE_SIZE)**2

const JUMP_POWER_TINY := 0.35
const JUMP_POWER_SMALL := 0.50
const JUMP_POWER_LARGE := 1.50
const JUMP_MODIFIER_ODDS := 0.10

@export_group("Jumps", "jump_")
@export var jump_per_direction_base := 6
@export var jump_per_direction_variance := 4

@export var jump_power_base := 300.0
@export var jump_power_variance := 100.0

@export var jump_wait_base := 2.0
@export var jump_wait_variance := 3.0

@export_group("Movement", "move_")
@export var move_power_base := 100.0
@export var move_power_variance := 50.0

@export var gravity := 980.0
@export var terminal_velocity := 380.0

@export_group("Variants", "variant_")

@export var variant_green_texture: Texture2D
@export var variant_blue_texture: Texture2D
@export var variant_red_texture: Texture2D
@export var variant_purple_texture: Texture2D
@export var variant_cloud_texture: Texture2D
@export var variant_stone_texture: Texture2D
@export var variant_tunnel_texture: Texture2D

var target_player: PlayerController

var travel_direction := -1
var jump_remaining := 0
var jump_timer := 0.0
var jump_velocity: Vector2
var airborne := false

var rng: RandomNumberGenerator

# --- Functions --- #
func _ready() -> void:
	super()
	
	hp_pool[0].died.connect(_on_death)
	hp_pool[0].received_damage.connect(_on_receive_damage)

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		get_travel_direction()
		try_jump(delta)
	
	# gravity
	if not is_on_floor():
		velocity.x = jump_velocity.x
	
	velocity.y = clampf(velocity.y + gravity * delta, -terminal_velocity, terminal_velocity)
	
	# movement
	move_and_slide()
	
	# snap to ground
	if is_on_floor():
		if airborne:
			$'animator'.play(&'land')
			$'animator'.advance(0.0)
			$'animator'.queue(&'idle')
		
		velocity.x = 0.0
		airborne = false

#region Physics
func get_travel_direction() -> void:
	if not multiplayer.is_server():
		return
	
	# jump towards target player
	if is_instance_valid(target_player):
		var distance: Vector2 = target_player.center_point - global_position
		travel_direction = sign(distance.x)
	# if no target, jump randomly
	elif jump_remaining <= 0:
		travel_direction = -travel_direction
		jump_remaining = jump_per_direction_base + rng.randi_range(0, jump_per_direction_variance)

func try_jump(delta: float) -> void:
	# try to jump
	if is_on_floor():
		jump_timer -= delta
		
		if jump_timer <= 0:
			jump_timer = jump_wait_base + rng.randf_range(0, jump_wait_variance)
			jump_remaining -= 1
			
			# set velocity
			jump_velocity.x =  (move_power_base + rng.randf_range(0, move_power_variance)) * travel_direction
			jump_velocity.y = -(jump_power_base + rng.randf_range(0, jump_power_variance))
			
			if is_instance_valid(target_player):
				var distance = global_position.distance_squared_to(target_player.global_position)
				
				if distance < (4 * TileManager.TILE_SIZE)**2:
					jump_velocity.y *= JUMP_POWER_TINY
				elif distance < (12 * TileManager.TILE_SIZE)**2:
					jump_velocity.y *= JUMP_POWER_SMALL
				if distance > (20 * TileManager.TILE_SIZE)**2:
					jump_velocity.y *= JUMP_POWER_LARGE
			else:
				var roll: float = rng.randf()
				
				# random chance to perform a small jump
				if roll < JUMP_MODIFIER_ODDS:
					jump_velocity.y *= JUMP_POWER_SMALL
				# random chance to perform a large jump (if not a small jump)
				elif rng.randf() < JUMP_MODIFIER_ODDS * 2.0:
					jump_velocity.y *= JUMP_POWER_LARGE
			
			$'animator'.play(&'jump')
			EntityManager.entity_send_update(id, {
				&'type': &'jump-start',
				&'velocity': jump_velocity,
				&'position': global_position
			})

func apply_jump() -> void:
	velocity = jump_velocity
	airborne = true

#endregion

#region Damage
func _input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or not event.is_pressed():
		return
	
	if get_global_mouse_position().distance_to(global_position) > 20.0:
		return
	
	# TEMPORARY: deal damage until actual combat system is implemented
	hp_pool[0].take_damage({
		&'damage': 25,
		&'player_id': multiplayer.get_unique_id()
	})

func _on_receive_damage(snapshot: Dictionary) -> void:
	standard_receive_damage(snapshot)
	
	# set target if not already set
	if multiplayer.is_server():
		if not is_instance_valid(target_player):
			target_player = ServerManager.connected_players.get(snapshot[&'player_id'])
			snapshot[&'update_target'] = true
	else:
		if snapshot.get(&'update_target'):
			target_player = ServerManager.connected_players.get(snapshot[&'player_id'])

func _on_death(from_server: bool) -> void:
	if multiplayer.is_server():
		EntityManager.create_entity(0, global_position - Vector2(0, 4), {
			&'item_id': 2,
			&'quantity': rng.randi_range(1, 3)
		})
	
	if from_server:
		standard_death()

#endregion

#region Multiplayer
func setup_entity() -> void:
	var spawned: bool = data.get(&'spawned', true)
	
	rng = RandomNumberGenerator.new()
	rng.seed = id
	
	# variants
	match data.get(&'variant', &'green'):
		&'green':
			$'sprite'.texture = variant_green_texture
			
			# stats
			hp_pool[0].set_max_hp(96, spawned)		# only update hp to max if just spawned
		&'blue':
			$'sprite'.texture = variant_blue_texture
			
			# stats
			hp_pool[0].set_max_hp(138, spawned)		# only update hp to max if just spawned
		&'red':
			$'sprite'.texture = variant_red_texture
			
			# stats
			hp_pool[0].set_max_hp(224, spawned)		# only update hp to max if just spawned
		&'purple':
			$'sprite'.texture = variant_purple_texture
			
			# stats
			hp_pool[0].set_max_hp(296, spawned)		# only update hp to max if just spawned
		&'cloud':
			$'sprite'.texture = variant_cloud_texture
			
			# stats
			hp_pool[0].set_max_hp(158, spawned)		# only update hp to max if just spawned
			
			gravity *= 0.65
			jump_power_base *= 1.10
			jump_power_variance *= 1.10
			move_power_base *= 1.10
			move_power_variance *= 1.10
		&'stone':
			$'sprite'.texture = variant_stone_texture
			
			# stats
			hp_pool[0].set_max_hp(362, spawned)		# only update hp to max if just spawned
			
			gravity *= 1.50
			jump_power_base *= 1.20
			jump_power_variance *= 1.20
			move_power_base *= 1.20
			move_power_variance *= 1.20
		&'tunnel':
			$'sprite'.texture = variant_tunnel_texture
			
			# stats
			hp_pool[0].set_max_hp(172, spawned)		# only update hp to max if just spawned
			
			jump_power_base *= 0.60
			jump_power_variance *= 0.60
			move_power_base *= 1.60
			move_power_variance *= 1.60
	
	# spawn-only logic
	if not spawned:
		return
	
	# set initial direction
	travel_direction = 1 if rng.randf() < 0.50 else -1
	jump_remaining = jump_per_direction_base + rng.randi_range(0, jump_per_direction_variance)
	jump_timer = jump_wait_base + rng.randf_range(0, jump_wait_variance)

func receive_update(update_data: Dictionary) -> Dictionary:
	super(update_data)
	
	match update_data.get(&'type', &'none'):
		&'jump-start':
			if multiplayer.is_server():
				return NO_RESPONSE
			
			var pos: Vector2 = update_data.get(&'position', global_position)
			var distance: float = pos.distance_squared_to(global_position)
			
			# snap to position if too large
			if distance > POSITION_ADJUST_RANGE:
				global_position = pos
			# slightly adjust to server position
			if distance > POSITION_REMAIN_RANGE:
				global_position = global_position.lerp(pos, 0.25)
			
			# store jump velocity
			jump_velocity = update_data.get(&'velocity', Vector2.ZERO)
			#airborne = true
			
			# play jump animation
			$'animator'.play(&'jump')
			$'animator'.advance(0.0)
			$'animator'.queue(&'airborne')
	
	return NO_RESPONSE

#endregion
