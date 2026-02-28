class_name ItemDropEntity
extends Entity

# --- Variables --- #
const UPWARD_RANDOM_POWER := 200.0

const COLLECTION_RADIUS := 4.0**2
const SNAP_RADIUS := 16.0**2
const SNAP_STRENGTH := 2.0

const ABSORB_TIME := 0.15

@export var gravity := 980.0
@export var air_resistance := 100.0
@export var terminal_velocity := 380.0

@export var fly_speed := 500.0

var texture: Texture2D
var item_id := 0
var quantity := 1
var merged := false
var spawned := false

var stationary := false

var target_player: PlayerController

var absorb_timer := ABSORB_TIME

# --- Functions --- #
func _ready() -> void:
	super()
	
	$'merge_range'.monitoring = false
	
	if multiplayer.is_server():
		$'merge_range'.area_entered.connect(_on_merge_area_entered)
		$'collection_range'.area_entered.connect(_on_collect_area_entered)

func _process(delta: float) -> void:
	if multiplayer.is_server():
		super(delta)
	else:
		# run absorption code
		absorb_timer -= delta
		
		global_position = global_position.lerp(
			target_player.center_point,
			1.0 - (absorb_timer / ABSORB_TIME)
		)
		scale = scale.lerp(Vector2.ZERO, 1.0 - (absorb_timer / ABSORB_TIME))
		
		if absorb_timer <= 0.0:
			global_position = target_player.center_point
			queue_free()
			
			if target_player == Globals.player:
				target_player.sfx.play_sfx(&'collect', 6.0)

func _physics_process(delta: float) -> void:
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
	
	if is_on_floor() and not stationary:
		stationary = true
		$'merge_range'.monitoring = true
	elif not is_on_floor() and stationary:
		stationary = false
		$'merge_range'.monitoring = false

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
	if distance <= COLLECTION_RADIUS:
		kill()
		send_kill()
		
		# add to inventory
		target_player.my_inventory.add_item(item_id, quantity)
	
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

func do_death() -> void:
	if multiplayer.is_server():
		should_free = true
	else:
		if target_player:
			interpolator.enabled = false
			set_process(true)
		else:
			queue_free()

func _on_collect_area_entered(area: Area2D) -> void:
	if not area.is_in_group(&'item_collect'):
		return
	
	# don't switch targets while chasing
	if target_player:
		return
	
	# start chasing player
	target_player = area.get_parent()

func _on_merge_area_entered(area: Area2D) -> void:
	if not (area.is_in_group(&'item_merge') and multiplayer.is_server()):
		return
	
	# don't merge already merged items
	if merged:
		return
	
	# get other item from collision
	var other_item: ItemDropEntity = area.get_parent()
	if not is_instance_valid(other_item) or other_item.merged:
		return
	
	# prioritize older items
	if id > other_item.id:
		return
	
	# make sure items can stack
	if (item_id != other_item.item_id) or (quantity + other_item.quantity > 9999):
		return
	
	quantity += other_item.quantity
	
	other_item.merged = true
	other_item.quantity = 0
	other_item.kill()
	other_item.send_kill()

#region Serialization
func serialize_extra(buffer: PackedByteArray, offset: int) -> int:
	# uint32 (target)
	buffer.resize(len(buffer) + 4)
	
	# target player id
	if target_player:
		buffer.encode_u32(offset, target_player.owner_id)
	else:
		buffer.encode_u32(offset, 0)
	offset += 4
	
	return offset

func deserialize_extra(buffer: PackedByteArray, offset: int, _server_time: float) -> int:
	# target player id
	var player_id := buffer.decode_u32(offset)
	offset += 4
	
	if player_id == 0:
		target_player = null
	else:
		target_player = ServerManager.get_player(player_id)
	
	return offset

#endregion
