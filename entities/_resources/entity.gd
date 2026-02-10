class_name Entity
extends CharacterBody2D

# --- Signals --- #
signal interest_changed(interest: int)
signal lost_all_interest()

signal despawn()

# --- Variables --- #
var id := 0
var registry_id := 0
var data: Dictionary[StringName, Variant]
var interested_players: Dictionary[int, bool] = {}
var interest_count := 0

var current_chunk: Vector2i

@export var process_on_client := false

@export var hp_pool: Array[EntityHp]

@export_group("Despawning")
@export var free_on_despawn := true
@export var despawn_time := 300.0
var _despawn_timer := 0.0

# --- Functions --- #
func _ready() -> void:
	current_chunk = TileManager.world_to_chunk(floori(position.x), floori(position.y))
	
	_despawn_timer = despawn_time
	
	if not process_on_client and not multiplayer.is_server():
		set_process(false)

func initialize(new_id: int, reg_id: int, spawn_data: Dictionary[StringName, Variant]) -> void:
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

func receive_update(update_data: Dictionary) -> void:
	if update_data.get(&'kill'):
		standard_death()

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
	
	# update interpolator
	var interpolator: SnapshotInterpolator = get_node_or_null(^'snapshot_interpolator')
	if interpolator:
		interpolator.interested_players = interested_players.keys()

func scan_interest() -> void:
	var load_range := ChunkLoader.LOAD_RANGE
	
	for player_id in ServerManager.connected_players:
		var player: PlayerController = ServerManager.connected_players[player_id]
		var player_chunk := TileManager.world_to_chunk(floori(player.position.x), floori(player.position.y))
		var diff := current_chunk - player_chunk
		
		# skip out of range players
		if abs(diff.x) > load_range.x or abs(diff.y) > load_range.y:
			interested_players.erase(player_id)
			continue
		
		# set interested
		interested_players[player_id] = true
	
	check_interest()

#endregion

#region Life Cycle
func standard_death() -> void:
	EntityManager.erase_entity(self)
	queue_free()

#endregion

#region Interaction
func interact_with(_tile_position: Vector2i) -> bool:
	return true

func break_place(_tile_position: Vector2i) -> bool:
	return true

#endregion
