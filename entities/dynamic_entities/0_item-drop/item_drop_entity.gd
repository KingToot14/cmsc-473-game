class_name ItemDropEntity
extends Entity

# --- Variables --- #
const UPWARD_RANDOM_POWER := 200.0

@export var gravity := 980.0
@export var air_resistance := 100.0
@export var terminal_velocity := 380.0

var texture: Texture2D
var item_id := 0
var quantity := 1

# --- Functions --- #
func _process(delta: float) -> void:
	super(delta)
	
	if interest_count == 0:
		return
	
	if is_on_floor():
		return
	
	# air resistance
	if velocity.x < 0:
		velocity.x = minf(0.0, velocity.x + air_resistance * delta)
	elif velocity.x > 0:
		velocity.x = maxf(0.0, velocity.x - air_resistance * delta)
	
	# gravity
	velocity.y = clampf(velocity.y + gravity * delta, -terminal_velocity, terminal_velocity)
	
	move_and_slide()
	
	if is_on_floor():
		pass

func setup_entity() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = id
	
	item_id  = data.get(&'item_id', -1)
	quantity = data.get(&'quantity', 1)
	var spawn_type: StringName = data.get(&'spawn_type', &'upward_random')
	
	if item_id == -1:
		standard_death()
		return
	
	# spawn behavior
	match spawn_type:
		&'upward_random':
			velocity = Vector2(rng.randf_range(-0.5, 0.5), -1.0).normalized() * UPWARD_RANDOM_POWER
