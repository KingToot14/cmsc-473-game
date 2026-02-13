class_name BasicSlimeEntity
extends Entity

# --- Variables --- #
const POSITION_REMAIN_RANGE := (2.0 * TileManager.TILE_SIZE)**2
const POSITION_ADJUST_RANGE := (6.0 * TileManager.TILE_SIZE)**2

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

var target_player: PlayerController

var travel_direction := -1
var jump_remaining := 0
var jump_timer := 0.0
var landed := false

var rng: RandomNumberGenerator

# --- Functions --- #
func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		get_travel_direction()
		try_jump(delta)
	
	# gravity
	velocity.y = clampf(velocity.y + gravity * delta, -terminal_velocity, terminal_velocity)
	
	move_and_slide()
	
	# snap to ground
	if is_on_floor():
		velocity.x = 0.0

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
			jump_timer = jump_wait_base + floori(rng.randf() * jump_wait_variance)
			jump_remaining -= 1
			
			# set velocity
			velocity.x =  (move_power_base + rng.randf_range(0, move_power_variance)) * travel_direction
			velocity.y = -(jump_power_base + rng.randf_range(0, jump_power_variance))
			
			EntityManager.entity_send_update(id, {
				&'type': &'jump-start',
				&'velocity': velocity,
				&'position': global_position
			})

func chase_physics(_delta: float) -> void:
	if not multiplayer.is_server():
		return

func setup_entity() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = id
	
	# spawn-only logic
	if not data.get(&'spawned', true):
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
			# slighly adjust to server position
			if distance > POSITION_REMAIN_RANGE:
				global_position = global_position.lerp(position, 0.25)
			
			# update velocity
			velocity = update_data.get(&'velocity', Vector2.ZERO)
	
	return NO_RESPONSE
