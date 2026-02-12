class_name ItemDropEntity
extends Entity

# --- Variables --- #
const UPWARD_RANDOM_POWER := 200.0

@export var gravity := 980.0
@export var air_resistance := 100.0
@export var terminal_velocity := 380.0

@export var fly_speed := 500.0

var texture: Texture2D
var item_id := 0
var quantity := 1
var merged := false
var spawned := false

var target_player: PlayerController

# --- Functions --- #
func _ready() -> void:
	$'merge_range'.monitoring = false
	$'merge_range'.area_entered.connect(_on_merge_area_entered)

func _process(delta: float) -> void:
	super(delta)
	
	if interest_count == 0:
		return
	
	# chase player
	if target_player:
		pass
		
		return
	
	# air resistance
	if velocity.x < 0:
		velocity.x = minf(0.0, velocity.x + air_resistance * delta)
	elif velocity.x > 0:
		velocity.x = maxf(0.0, velocity.x - air_resistance * delta)
	
	# gravity
	if not is_on_floor():
		velocity.y = clampf(velocity.y + gravity * delta, -terminal_velocity, terminal_velocity)
	else:
		velocity.y = 0.0
	
	# update server for synching
	if multiplayer.is_server():
		data[&'velocity'] = velocity
	
	move_and_slide()
	
	# attempt to merge with nearby items
	if is_on_floor() and multiplayer.is_server():
		$'merge_range'.monitoring = true

func setup_entity() -> void:
	# load from data
	item_id  = data.get(&'item_id', -1)
	quantity = data.get(&'quantity', 1)
	merged   = data.get(&'merged', false)
	velocity = data.get(&'velocity', Vector2.ZERO)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = id
	
	var spawn_type: StringName = data.get(&'spawn_type', &'upward_random')
	
	if item_id == -1:
		standard_death()
		return
	
	# item info
	var item: Item = ItemDatabase.get_item(item_id)
	if item:
		var sprite_node = $sprite
		sprite_node.texture = item.texture
	
	# don't run spawn logic if already spawned
	if not data.get(&'spawned', true):
		return
	
	# spawn behavior
	match spawn_type:
		&'upward_random':
			velocity = Vector2(rng.randf_range(-0.5, 0.5), -1.0).normalized() * UPWARD_RANDOM_POWER

func _on_collect_area_entered(area: Area2D) -> void:
	if not area.is_in_group(&'item_collect'):
		return
	
	var player: PlayerController = area.get_parent()
	
	# collect item
	EntityManager.entity_send_update(id, {
		&'type': &'collect',
		&'player_id': player.owner_id
	})

func _on_merge_area_entered(area: Area2D) -> void:
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
	
	quantity += other_item.quantity
	data[&'quantity'] = quantity
	
	EntityManager.entity_send_update(id, {
		&'type': &'merge-owner',
		&'quantity': other_item.quantity
	})
	EntityManager.entity_send_update(other_item.id, {
		&'type': &'merge-kill'
	})
	
	# clear other item
	other_item.merged = true
	other_item.standard_death()

func receive_update(update_data: Dictionary) -> void:
	super(update_data)
	
	var type: StringName = update_data.get(&'type', &'none')
	
	match type:
		&'merge-owner':
			quantity += update_data.get(&'quantity', 0)
		&'merge-kill':
			standard_death()
		&'collect':
			target_player = ServerManager.connected_players[update_data.get(&'player_id', 0)]
