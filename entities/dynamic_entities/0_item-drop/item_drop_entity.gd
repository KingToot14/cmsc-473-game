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
var merged := false

# --- Functions --- #
func _ready() -> void:
	$'merge_range'.monitoring = false
	$'merge_range'.area_entered.connect(_on_area_entered)

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
	
	# attempt to merge with nearby items
	if is_on_floor() and multiplayer.is_server():
		$'merge_range'.monitoring = true

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

func _on_area_entered(area: Area2D) -> void:
	if not (area.is_in_group(&'item_merge') and multiplayer.is_server()):
		return
	
	# don't merge already merged items
	if merged:
		return
	
	var other_item: ItemDropEntity = area.get_parent()
	
	# make sure item ids match
	if item_id != other_item.item_id:
		return
	
	# make sure there's enough space
	if quantity + other_item.quantity > 9999:
		return
	
	other_item.merged = true
	quantity += other_item.quantity
	
	EntityManager.entity_send_update(id, {
		&'type': &'merge-owner',
		&'quantity': other_item.quantity
	})
	EntityManager.entity_send_update(other_item.id, {
		&'type': &'merge-kill'
	})

func receive_update(update_data: Dictionary) -> void:
	super(update_data)
	
	var type: StringName = update_data.get(&'type', &'none')
	
	match type:
		&'merge-owner':
			quantity += update_data.get(&'quantity', 0)
		&'merge-kill':
			standard_death()
