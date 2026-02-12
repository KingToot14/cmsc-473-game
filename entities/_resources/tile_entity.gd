class_name TileEntity
extends Node2D

# --- Signals --- #
signal interest_changed(interest: int)

# --- Variables --- #
const NO_RESPONSE: Dictionary = {}

var id := 0
var registry_id := 0
var data: Dictionary[StringName, Variant]
var interested_players: Dictionary[int, bool] = {}
var interest_count := 0

var current_chunk: Vector2i
var tile_position: Vector2i

@export var hp_pool: Array[EntityHp]

# --- Functions --- #
func _ready() -> void:
	current_chunk = TileManager.world_to_chunk(floori(position.x), floori(position.y))

func initialize(new_id: int, reg_id: int, spawn_data: Dictionary[StringName, Variant]) -> void:
	id = new_id
	registry_id = reg_id
	data = spawn_data
	
	setup_entity()
	tile_position = TileManager.world_to_tile(floori(position.x), floori(position.y))
	
	for hp in hp_pool:
		hp.setup()

func setup_entity() -> void:
	return

func receive_update(update_data: Dictionary) -> Dictionary:
	if update_data.get(&'kill'):
		standard_death()
	
	return NO_RESPONSE

#region Interest
func add_interest(player_id: int) -> void:
	interested_players[player_id] = true
	
	check_interest()

func remove_interest(player_id: int) -> void:
	interested_players[player_id] = false
	
	check_interest()

func check_interest() -> void:
	# reset interest count
	interest_count = 0
	for player in interested_players:
		if interested_players[player]:
			interest_count += 1
	
	interest_changed.emit(interest_count)

func scan_interest() -> void:
	var load_range := ChunkLoader.LOAD_RANGE
	
	for player_id in ServerManager.connected_players:
		var player: PlayerController = ServerManager.connected_players[player_id]
		var player_chunk := TileManager.world_to_chunk(floori(player.position.x), floori(player.position.y))
		var diff := current_chunk - player_chunk
		
		# skip out of range players
		if abs(diff.x) > load_range.x or abs(diff.y) > load_range.y:
			interested_players[player_id] = false
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
