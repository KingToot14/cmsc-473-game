class_name ItemDropEntity
extends Entity

# --- Variables --- #
const UPWARD_RANDOM_POWER := 200.0
const COLLECTION_RADIUS := 4.0**2
const COLLECT_VERIFICATION := (3.0 * 8.0)**2.0
const SNAP_RADIUS := 16.0**2
const SNAP_STRENGTH := 2.0

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
	#$'merge_range'.monitoring = false
	
	if multiplayer.is_server():
		$'merge_range'.area_entered.connect(_on_merge_area_entered)
	else:
		$'collection_range'.area_entered.connect(_on_collect_area_entered)

func _process(delta: float) -> void:
	super(delta)
	
	if interest_count == 0:
		return
	
	# chase player
	if target_player != null:
		chase_physics(delta)
	else:
		standard_physics(delta)
	
	# update server for syncing
	if multiplayer.is_server():
		data[&'velocity'] = velocity
	
	move_and_slide()
	
	# attempt to merge with nearby items
	if is_on_floor() and multiplayer.is_server():
		$'merge_range'.monitoring = true

func standard_physics(delta: float) -> void:
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

func chase_physics(delta: float) -> void:
	var difference: Vector2 = target_player.center_point - global_position
	var distance: float = difference.length_squared()
	
	# don't collect if hidden
	if not visible:
		return
	
	# collect when close enough
	if target_player == Globals.player and distance <= COLLECTION_RADIUS:
		hide()
		
		# add to inventory
		target_player.my_inventory.add_item(item_id, quantity)
		
		EntityManager.entity_send_update.rpc_id(1, id, {
			&'type': &'collect'
		})
	
	if distance <= SNAP_RADIUS:
		velocity += difference.normalized() * fly_speed * delta * min(1.0, SNAP_RADIUS / distance) * SNAP_RADIUS
	else:
		velocity += difference.normalized() * fly_speed * delta
	
	velocity = velocity.limit_length(terminal_velocity)

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
	
	# don't switch targets while chasing
	if target_player:
		return
	
	target_player = area.get_parent()
	
	# start chasing player
	EntityManager.entity_send_update.rpc_id(1, id, {
		&'type': &'chase',
		&'player_id': target_player.owner_id
	})

func _on_merge_area_entered(area: Area2D) -> void:
	if not (area.is_in_group(&'item_merge') and multiplayer.is_server()):
		return
	
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
	
	EntityManager.entity_send_update(id, {
		&'type': &'merge-owner',
		&'quantity': other_item.quantity
	})
	EntityManager.entity_send_update(other_item.id, {
		&'type': &'merge-kill'
	})

func receive_update(update_data: Dictionary) -> Dictionary:
	super(update_data)
	
	var type: StringName = update_data.get(&'type', &'none')
	
	match type:
		&'merge-owner':
			print(quantity, " | ", id, " | ", multiplayer.get_unique_id())
			
			quantity += update_data.get(&'quantity', 0)
			data[&'quantity'] = quantity
		&'merge-kill':
			merged = true
			standard_death()
		&'collect':
			# verify collection
			var distance: float = target_player.center_point.distance_squared_to(global_position)
			if multiplayer.is_server() and distance > COLLECTION_RADIUS * COLLECT_VERIFICATION:
				# item too far out of range, reject collection
				return {
					&'success': false
				}
			
			# undo collection
			if not data.get(&'success', true) and target_player == Globals.player:
				show()
				
				# restore inventory state
				target_player.my_inventory.remove_item(item_id, quantity)
				
				return NO_RESPONSE
			
			standard_death()
		&'chase':
			target_player = ServerManager.connected_players[update_data.get(&'player_id', 0)]
	
	return NO_RESPONSE
