class_name Entity
extends CharacterBody2D

# --- Signals --- #
signal interest_changed(interest: int)
signal lost_all_interest()

signal despawn()

# --- Variables --- #
const NO_RESPONSE: Dictionary = {}

const KILL_ACTION := 0

@onready var interpolator: SnapshotInterpolator = get_node_or_null(^'snapshot_interpolator')

var id := 0
var registry_id := 0
var data: Dictionary
var interested_players: Dictionary[int, bool] = {}
var interest_count := 0

var current_chunk: Vector2i

@export var counts_towards_spawn_cap := true
@export var process_on_client := false

@export var hp_pool: Array[EntityHp]
@export var flash_material: ShaderMaterial

@export var knockback_power := 200.0

@export_group("Despawning")
@export var free_on_despawn := true
@export var despawn_time := 15.0
var _despawn_timer := 0.0

var is_dead := false
var should_free := false

@export_group("Combat")
@export var damage := 25
@export var defense := 0

# --- Functions --- #
func _ready() -> void:
	calculate_chunk()
	
	_despawn_timer = despawn_time
	
	if not (process_on_client or multiplayer.is_server()):
		set_process(false)
		set_physics_process(false)

func initialize(new_id: int, reg_id: int, spawn_data: Dictionary) -> void:
	id = new_id
	registry_id = reg_id
	data = spawn_data
	
	calculate_chunk()
	
	setup_entity()
	
	for hp in hp_pool:
		hp.setup()

func calculate_chunk() -> void:
	current_chunk = TileManager.world_to_chunk(floori(position.x), floori(position.y))

func _process(delta: float) -> void:
	# check despawn
	if interest_count == 0:
		_despawn_timer -= delta
		
		if _despawn_timer <= 0.0:
			if free_on_despawn:
				queue_free()
			
			despawn.emit()
		
		return
	
	# check chunk boundaries
	var prev_chunk: Vector2i = current_chunk
	calculate_chunk()
	
	if prev_chunk != current_chunk:
		EntityManager.move_dynamic_entity(id, prev_chunk, current_chunk)
		scan_interest()

func setup_entity() -> void:
	return

func receive_update(update_data: Dictionary) -> Dictionary:
	if update_data.get(&'kill'):
		standard_death()
	
	match update_data.get(&'type', &'none'):
		&'knockback':
			if multiplayer.is_server():
				return NO_RESPONSE
			
			# apply knockback force
			velocity += update_data.get(&'force', Vector2.ZERO)
		&'pause':
			#paused = true
			process_mode = Node.PROCESS_MODE_DISABLED
			global_position = update_data.get(&'position')
		&'resume':
			#paused = false
			process_mode = Node.PROCESS_MODE_INHERIT
			global_position = update_data.get(&'position')
	
	return NO_RESPONSE

#region Interest
func add_interest(player_id: int) -> void:
	interested_players[player_id] = true
	
	check_interest()

func remove_interest(player_id: int) -> void:
	interested_players.erase(player_id)
	
	check_interest()

func check_interest() -> void:
	# reset interest count
	interest_count = 0
	for player in interested_players:
		if interested_players[player]:
			interest_count += 1
	
	interest_changed.emit(interest_count)
	
	# check if no players are loading
	if interest_count == 0:
		lost_all_interest.emit()
		_despawn_timer = despawn_time
		
		# send signal to client entities
		EntityManager.entity_send_update(id, {
			&'type': &'pause',
			&'position': global_position
		})
	else:
		# send signal to client entities
		EntityManager.entity_send_update(id, {
			&'type': &'resume',
			&'position': global_position
		})

func scan_interest() -> void:
	var load_range := ChunkLoader.LOAD_RANGE
	
	for player_id in ServerManager.connected_players:
		var player: PlayerController = ServerManager.connected_players[player_id]
		var player_chunk := TileManager.world_to_chunk(floori(player.position.x), floori(player.position.y))
		var diff := current_chunk - player_chunk
		
		# skip out of range players
		if abs(diff.x) > load_range.x or abs(diff.y) > load_range.y:
			remove_interest(player_id)
			player.remove_interest(id)
			continue
		
		# set interested
		add_interest(player_id)
		if counts_towards_spawn_cap:
			player.add_interest(id)
	
	check_interest()

func check_player(player_id: int) -> bool:
	# check if player still exists
	if player_id not in ServerManager.connected_players.keys():
		remove_interest(player_id)
		return false
	
	return true

#endregion

#region Life Cycle
func send_kill() -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.resize(2)
	
	# action id
	buffer.put_u16(KILL_ACTION)
	
	interpolator.queue_action(NetworkTime.time, buffer.data_array)

func kill() -> void:
	if is_dead:
		return
	
	is_dead = true
	
	do_death()

func do_death() -> void:
	if multiplayer.is_server():
		should_free = true
	else:
		queue_free()

func standard_death() -> void:
	EntityManager.erase_entity(self)
	
	velocity = Vector2.ZERO
	
	if not multiplayer.is_server() and has_node(^'animator') and $'animator'.has_animation(&'death'):
		$'animator'.play(&'death')
		$'animator'.animation_finished.connect(func(_s): queue_free())
	else:
		queue_free()

func standard_receive_damage(snapshot: Dictionary) -> void:
	# apply knockback (if not dead)
	if not snapshot.get(&'entity_dead', false):
		velocity += snapshot.get(&'knockback', Vector2.ZERO) * knockback_power
	
	if not flash_material:
		return
	
	flash_material.set_shader_parameter(&'intensity', 1.0)
	
	var flash_tween := create_tween()
	
	flash_tween.tween_method(func (x):
		flash_material.set_shader_parameter(&'intensity', x),
		1.0, 0.0, 0.15
	)

#endregion

#region Interaction
func interact_with(_tile_position: Vector2i) -> bool:
	return true

func break_place(_tile_position: Vector2i) -> bool:
	return true

func handle_action(action_info: PackedByteArray) -> void:
	var offset := 0
	
	var action_id := action_info.decode_u16(offset)
	offset += 2
	
	match action_id:
		KILL_ACTION:
			kill()

#endregion

#region Serialization
func serialize() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	
	# reserve space for size
	buffer.put_u16(0)
	
	serialize_base(buffer)
	serialize_extra(buffer)
	
	# prepend size
	buffer.seek(0)
	buffer.put_u16(len(buffer.data_array))
	
	return buffer.data_array

func serialize_base(buffer: StreamPeerBuffer) -> void:
	# uint32 (4) + 2 float32 (2 * 4) + 2 float32 (2 * 4) + uint32 (4) + uint8 (1)
	buffer.resize(4 + (2 * 4) + (2 * 4) + 4 + 1)
	
	# entity id
	buffer.put_u32(id)
	
	# position
	buffer.put_float(global_position.x)
	buffer.put_float(global_position.y)
	
	# velocity
	buffer.put_float(velocity.x)
	buffer.put_float(velocity.y)
	
	# entity hp
	if len(hp_pool) > 0:
		buffer.put_u32(max(hp_pool[0].curr_hp, 0))
	else:
		buffer.put_u32(0)
	
	# flags
	var flags = 0b00000000
	
	# entity is dead
	if is_dead:
		flags |= 1 << 0
		
		if should_free:
			queue_free()
	
	buffer.put_u8(flags)

@warning_ignore("unused_parameter")
func serialize_extra(buffer: StreamPeerBuffer) -> void:
	return

func deserialize(buffer: StreamPeerBuffer, server_time: float) -> void:
	deserialize_base(buffer, server_time)
	deserialize_extra(buffer, server_time)

func deserialize_base(buffer: StreamPeerBuffer, server_time: float) -> void:
	# entity position
	var net_position: Vector2
	net_position.x = buffer.get_float()
	net_position.y = buffer.get_float()
	
	# entity velocity
	velocity.x = buffer.get_float()
	velocity.y = buffer.get_float()
	
	# update snapshot interpolator
	if is_equal_approx(server_time, -1.0):
		global_position = position
	else:
		interpolator.send_snapshot(server_time, {
			&'position': net_position
		})
	
	# entity hp
	if len(hp_pool) > 0:
		hp_pool[0].curr_hp = buffer.get_u32()
	
	# flags
	var flags := buffer.get_u8()
	
	# entity is dead
	#if flags & (1 << 0):
		#kill()

@warning_ignore("unused_parameter")
func deserialize_extra(buffer: StreamPeerBuffer, server_time: float) -> void:
	return

func serialize_spawn_data() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	
	# serialize base info
	serialize_base(buffer)
	
	return buffer.data_array

func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	# deserialize base info
	deserialize_base(buffer, -1.0)

#endregion

#region Spawning
static func spawn_from_rule(rule: SpawnRule) -> void:
	pass

#endregion
