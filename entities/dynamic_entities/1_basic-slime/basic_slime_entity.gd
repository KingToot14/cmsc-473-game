class_name BasicSlimeEntity
extends Entity

# --- Variables --- #
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
	if is_instance_valid(target_player):
		chase_physics(delta)
	else:
		standard_physics(delta)
	
	# gravity
	velocity.y = clampf(velocity.y + gravity * delta, -terminal_velocity, terminal_velocity)
	
	move_and_slide()

func standard_physics(delta: float) -> void:
	# reset jumps
	if jump_remaining <= 0:
		travel_direction = -travel_direction
		jump_remaining = jump_per_direction_base + floori(rng.randf() * jump_per_direction_variance)
	
	# try to jump
	if is_on_floor():
		jump_timer -= delta
		velocity.x = 0.0
		
		if jump_timer <= 0:
			jump_timer = jump_wait_base + floori(rng.randf() * jump_wait_variance)
			jump_remaining -= 1
			
			# set velocity
			velocity.x = move_power_base + floori(rng.randf() * move_power_variance) * travel_direction
			velocity.y = -(jump_power_base + floori(rng.randf() * jump_power_variance))

func chase_physics(_delta: float) -> void:
	pass

func setup_entity() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = id
	
	# spawn-only logic
	if not data.get(&'spawned', true):
		return
	
	# set initial direction
	travel_direction = 1 if rng.randf() < 0.50 else -1
	jump_remaining = jump_per_direction_base + floori(rng.randf() * jump_per_direction_variance)
	jump_timer = jump_wait_base + floori(rng.randf() * jump_wait_variance)

func receive_update(update_data: Dictionary) -> Dictionary:
	super(update_data)
	
	return NO_RESPONSE
