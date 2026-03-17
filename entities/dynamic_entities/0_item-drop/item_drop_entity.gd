class_name ItemDropEntity
extends Entity

# --- Enums --- #
enum SpawnBehavior {
	NONE,
	UPWARD_RANDOM,
	THROW_LEFT,
	THROW_RIGHT
}

# --- Variables --- #
const UPWARD_RANDOM_POWER := 200.0
const THROW_POWER := 200.0

const STOP_RADIUS := (12.0 * TileManager.TILE_SIZE)**2
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
var queued_player: PlayerController
var restriction_times: Dictionary[int, float] = {}
var preferred_times: Dictionary[int, float] = {}

var absorb_timer := ABSORB_TIME

# --- Functions --- #
func _ready() -> void:
	super()
	
	$'merge_range'.monitoring = false
	
	if multiplayer.is_server():
		$'merge_range'.area_entered.connect(_on_merge_area_entered)
		$'collection_range'.area_entered.connect(_on_collect_area_entered)
		$'collection_range'.area_exited.connect(_on_collect_area_exited)

func _process(delta: float) -> void:
	if multiplayer.is_server():
		super(delta)
		
		# decrement restricted timers
		var player_ids = restriction_times.keys()
		
		for player_id in player_ids:
			restriction_times[player_id] -= delta
			
			if restriction_times[player_id] <= 0.0:
				restriction_times.erase(player_id)
				
				# attempt to chase queued player
				if not target_player and queued_player and queued_player.owner_id == player_id:
					var difference: Vector2 = queued_player.center_point - global_position
					var distance: float = difference.length_squared()
					
					if distance < STOP_RADIUS:
						start_collection(queued_player)
						queued_player = null
		
		# decrement preferred timers
		player_ids = preferred_times.keys()
		
		for player_id in player_ids:
			preferred_times[player_id] -= delta
			
			if preferred_times[player_id] <= 0.0:
				preferred_times.erase(player_id)
		
		if len(preferred_times) == 0 and queued_player:
			if restriction_times.get(queued_player.owner_id, -1.0) <= 0.0:
				start_collection(queued_player)
				queued_player = null
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
	
	# stop collecting when out of range
	if distance > STOP_RADIUS:
		target_player = null
		stop_collection()
		return
	
	# collect when close enough
	if distance <= COLLECTION_RADIUS:
		kill()
		
		# add to inventory
		target_player.my_inventory.add_item(item_id, quantity)
		quantity = 0
	
	if distance <= SNAP_RADIUS:
		velocity += difference.normalized() * fly_speed * delta * min(1.0, SNAP_RADIUS / distance) * SNAP_RADIUS
	else:
		velocity += difference.normalized() * fly_speed * delta
	
	velocity = velocity.limit_length(terminal_velocity)

func load_item(spawn_behavior := SpawnBehavior.NONE) -> void:
	# load item texture
	var item := ItemDatabase.get_item(item_id)
	
	if item:
		$'sprite'.texture = item.texture
	
	# set spawn behavior
	match spawn_behavior:
		SpawnBehavior.NONE:
			pass
		SpawnBehavior.UPWARD_RANDOM:
			velocity = Vector2(randf_range(-0.5, 0.5), -1.0).normalized() * UPWARD_RANDOM_POWER
		SpawnBehavior.THROW_LEFT:
			velocity = Vector2(-1.0, -1.0).normalized() * THROW_POWER
		SpawnBehavior.THROW_RIGHT:
			velocity = Vector2(1.0, -1.0).normalized() * THROW_POWER

func do_death() -> void:
	if multiplayer.is_server():
		should_free = true
	else:
		if target_player:
			interpolator.enabled = false
			set_process(true)
		else:
			queue_free()

#region Area Handling
func _on_collect_area_entered(area: Area2D) -> void:
	if not area.is_in_group(&'item_collect'):
		return
	
	# don't switch targets while chasing
	if target_player:
		return
	
	# start chasing player
	start_collection(area.get_parent())

func _on_collect_area_exited(area: Area2D) -> void:
	if not area.is_in_group(&'item_collect'):
		return
	
	# de-queue player if out of range
	if area.get_parent() == queued_player:
		queued_player = null

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
	other_item.should_free_instant = false
	other_item.kill()

func start_collection(player: PlayerController) -> void:
	if not player:
		return
	
	# check if player is restricted
	if restriction_times.get(player.owner_id, -1.0) > 0.0:
		# attempt to queue player for later
		if not queued_player:
			queued_player = player
		
		return
	
	# check if player is preferred
	if len(preferred_times) > 0 and player.owner_id not in preferred_times:
		# attempt to queue player for later
		if not queued_player:
			queued_player = player
		
		return
	
	target_player = player
	
	# disable world collision
	$'shape'.set_deferred(&'disabled', true)

func stop_collection() -> void:
	# enable world collision
	$'shape'.set_deferred(&'disabled', false)

#endregion

#region Serialization
func serialize_extra(buffer: StreamPeerBuffer) -> void:
	# uint32 (target)
	buffer.resize(len(buffer.data_array) + 4)
	
	# target player id
	if target_player:
		buffer.put_u32(target_player.owner_id)
	else:
		buffer.put_u32(0)

func deserialize_extra(buffer: StreamPeerBuffer, _server_time: float) -> void:
	# target player id
	var player_id := buffer.get_u32()
	
	if player_id == 0:
		target_player = null
	else:
		target_player = ServerManager.get_player(player_id)

func serialize_spawn_data() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = super()
	
	# snap to end of current buffer
	var cursor := len(buffer.data_array)
	buffer.resize(len(buffer.data_array) + 4 + 2)	# base + uint32 (4) + uint16 (2)
	buffer.seek(cursor)
	
	# target player id
	if target_player:
		buffer.put_u32(target_player.owner_id)
	else:
		buffer.put_u32(0)
	
	# item id
	buffer.put_u16(item_id)
	
	return buffer.data_array

func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	id = buffer.get_u32()
	
	# process base snapshot
	super(buffer)
	
	# target player id
	var player_id := buffer.get_u32()
	
	if player_id == 0:
		target_player = null
	else:
		target_player = ServerManager.get_player(player_id)
	
	# item id
	item_id = buffer.get_u16()
	
	load_item()

#endregion

#region Spawning
@warning_ignore("shadowed_variable")
static func spawn(
		pos: Vector2, item_id: int, quantity: int, spawn_behavior := SpawnBehavior.UPWARD_RANDOM
	) -> void:
	
	# create new item drop entity
	var entity_scene: PackedScene = EntityManager.enemy_registry.get(0).entity_scene
	if not entity_scene:
		return
	
	var entity: ItemDropEntity = entity_scene.instantiate()
	entity.global_position = pos
	
	entity.item_id = item_id
	entity.quantity = quantity
	
	# start entity logic
	entity.load_item(spawn_behavior)
	
	# sync to players
	EntityManager.add_entity(0, entity)

@warning_ignore("shadowed_variable")
static func spawn_restricted(
		pos: Vector2, item_id: int, quantity: int, player_id: int, restricted_time := 1.0,
		spawn_behavior := SpawnBehavior.UPWARD_RANDOM
	) -> void:
	print("Test 5: spawn_restricted static call received for item_id: ", item_id)
	# create new item drop entity
	var entity_scene: PackedScene = EntityManager.enemy_registry.get(0).entity_scene
	if not entity_scene:
		return
	
	var entity: ItemDropEntity = entity_scene.instantiate()
	entity.global_position = pos
	
	entity.item_id = item_id
	entity.quantity = quantity
	
	# set restriction
	entity.restriction_times[player_id] = restricted_time
	
	# start entity logic
	entity.load_item(spawn_behavior)
	
	# sync to players
	EntityManager.add_entity(0, entity)


@warning_ignore("shadowed_variable")
static func spawn_preferred(
		pos: Vector2, item_id: int, quantity: int, player_id: int, preferred_time := 0.10,
		spawn_behavior := SpawnBehavior.UPWARD_RANDOM
	) -> void:
	
	# create new item drop entity
	var entity_scene: PackedScene = EntityManager.enemy_registry.get(0).entity_scene
	if not entity_scene:
		return
	
	var entity: ItemDropEntity = entity_scene.instantiate()
	entity.global_position = pos
	
	entity.item_id = item_id
	entity.quantity = quantity
	
	# set restriction
	entity.preferred_times[player_id] = preferred_time
	
	# start entity logic
	entity.load_item(spawn_behavior)
	
	# sync to players
	EntityManager.add_entity(0, entity)

#endregion
