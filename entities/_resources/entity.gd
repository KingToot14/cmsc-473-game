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
	current_chunk = TileManager.world_to_chunk(floori(position.x), floori(position.y))
	
	_despawn_timer = despawn_time
	
	if not (process_on_client or multiplayer.is_server()):
		set_process(false)
		set_physics_process(false)

func initialize(new_id: int, reg_id: int, spawn_data: Dictionary) -> void:
	id = new_id
	registry_id = reg_id
	data = spawn_data
	
	current_chunk = TileManager.world_to_chunk(floori(position.x), floori(position.y))
	
	setup_entity()
	
	for hp in hp_pool:
		hp.setup()

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
	var new_chunk: Vector2i = TileManager.world_to_chunk(floori(position.x), floori(position.y))
	
	if new_chunk != current_chunk:
		EntityManager.move_dynamic_entity(id, current_chunk, new_chunk)
		
		current_chunk = new_chunk
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
	var buffer := PackedByteArray()
	var offset := 0
	buffer.resize(2)
	
	# action id
	buffer.encode_u16(offset, KILL_ACTION)
	offset += 2
	
	interpolator.queue_action(NetworkTime.time, buffer)

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
	var buffer := PackedByteArray()
	var offset := 0
	
	offset = serialize_base(buffer, offset)
	offset = serialize_extra(buffer, offset)
	
	return buffer

func serialize_base(buffer: PackedByteArray, offset: int) -> int:
	# uint32 (4) + 2 float32 (2 * 4) + 2 float32 (2 * 4) + uint32 (4) + uint8 (1)
	buffer.resize(4 + (2 * 4) + (2 * 4) + 4 + 1)
	
	# entity id
	buffer.encode_u32(offset, id)
	offset += 4
	
	# entity position
	buffer.encode_float(offset, global_position.x)
	offset += 4
	buffer.encode_float(offset, global_position.y)
	offset += 4
	
	# entity velocity
	buffer.encode_float(offset, velocity.x)
	offset += 4
	buffer.encode_float(offset, velocity.y)
	offset += 4
	
	# entity hp
	if len(hp_pool) > 0:
		buffer.encode_u32(offset, max(hp_pool[0].curr_hp, 0))
	offset += 4
	
	# flags
	var flags = 0b00000000
	
	# entity is dead
	if is_dead:
		flags |= 1 << 0
		
		if should_free:
			queue_free()
	
	buffer.encode_u8(offset, flags)
	offset += 1
	
	return offset

func serialize_extra(_buffer: PackedByteArray, offset: int) -> int:
	return offset

func deserialize(buffer: PackedByteArray, offset: int, server_time: float) -> int:
	offset = deserialize_base(buffer, offset, server_time)
	offset = deserialize_extra(buffer, offset, server_time)
	
	return offset

func deserialize_base(buffer: PackedByteArray, offset: int, server_time: float) -> int:
	# entity position
	var net_position: Vector2
	net_position.x = buffer.decode_float(offset)
	offset += 4
	net_position.y = buffer.decode_float(offset)
	offset += 4
	
	# entity velocity
	velocity.x = buffer.decode_float(offset)
	offset += 4
	velocity.y = buffer.decode_float(offset)
	offset += 4
	
	# update snapshot interpolator
	interpolator.send_snapshot(server_time, {
		&'position': net_position
	})
	
	# entity hp
	if len(hp_pool) > 0:
		hp_pool[0].curr_hp = buffer.decode_u32(offset)
	offset += 4
	
	# flags
	var flags := buffer.decode_u8(offset)
	offset += 1
	
	# entity is dead
	#if flags & (1 << 0):
		#kill()
	
	return offset

func deserialize_extra(_buffer: PackedByteArray, offset: int, _server_time: float) -> int:
	return offset

#endregion
