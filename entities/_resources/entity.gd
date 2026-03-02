class_name Entity
extends CharacterBody2D

# --- Signals --- #
signal interest_changed(interest: int)
signal lost_all_interest()

signal despawn()

# --- Variables --- #
const NO_RESPONSE: Dictionary = {}

const KILL_ACTION := 0
const PAUSE_ACTION := 1
const RESUME_ACTION := 2

@onready var interpolator: SnapshotInterpolator = get_node_or_null(^'snapshot_interpolator')

var id := 0
var registry_id := 0
var data: Dictionary
var interested_players: Dictionary[int, bool] = {}
var interest_count := 0

var current_chunk: Vector2i

@export var counts_towards_spawn_cap := true
@export var process_on_client := false

@export var hp: EntityHp
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
		send_action_basic(PAUSE_ACTION)
	else:
		send_action_basic(RESUME_ACTION)

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
func send_action_basic(action_id: int) -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.resize(2)
	
	# action id
	buffer.put_u16(action_id)
	
	interpolator.queue_action(NetworkTime.time, buffer.data_array)

func send_kill() -> void:
	send_action_basic(KILL_ACTION)

func kill() -> void:
	if is_dead:
		return
	
	is_dead = true
	
	# remove entity on client
	if not multiplayer.is_server():
		EntityManager.erase_entity(self)
	
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

func do_flash() -> void:
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
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = action_info
	
	var action_id := buffer.get_u16()
	
	match action_id:
		KILL_ACTION:
			kill()
		PAUSE_ACTION:
			process_mode = Node.PROCESS_MODE_DISABLED
		RESUME_ACTION:
			process_mode = Node.PROCESS_MODE_INHERIT

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
	buffer.resize(len(buffer.data_array) + 4 + (2 * 4) + (2 * 4) + 4)
	
	# entity id
	buffer.put_u32(id)
	
	# position
	buffer.put_float(global_position.x)
	buffer.put_float(global_position.y)
	
	# velocity
	buffer.put_float(velocity.x)
	buffer.put_float(velocity.y)
	
	# entity hp
	if hp:
		buffer.put_u32(hp.curr_hp)
	else:
		buffer.put_u32(0)
	
	if is_dead and should_free:
		send_kill()
		EntityManager.erase_entity(self)
		queue_free()

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
	if hp:
		hp.curr_hp = buffer.get_u32()
	else:
		buffer.get_u32()

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
static func spawn_from_rule(pos: Vector2, rule: SpawnRule) -> void:
	pass

#endregion
