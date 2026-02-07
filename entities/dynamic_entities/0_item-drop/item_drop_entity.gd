class_name ItemDropEntity
extends Entity

# --- Variables --- #
@export var gravity := 980.0
@export var air_resistance := 0.5
@export var terminal_velocity := 980.0

var texture: Texture2D
var item_id := 0
var quantity := 1

# --- Functions --- #
func _process(delta: float) -> void:
	super(delta)
	
	if interest_count == 0:
		return
	
	# air resistance
	if velocity.x < 0:
		velocity.x = minf(0.0, velocity.x + air_resistance * delta)
	elif velocity.x > 0:
		velocity.x = maxf(0.0, velocity.x - air_resistance * delta)
	
	# gravity
	velocity.y = clampf(velocity.y + gravity * delta, -terminal_velocity, terminal_velocity)
	
	move_and_slide()

func setup_entity() -> void:
	velocity = data.get(&'velocity', Vector2.ZERO)
	item_id  = data.get(&'item_id', -1)
	quantity = data.get(&'quantity', 1)
	
	if item_id == -1:
		standard_death()
