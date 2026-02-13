class_name EntityHp
extends Node

# --- Signals --- #
signal received_damage(snapshot: Dictionary)
signal hp_modified(from_server: bool)
signal died(from_server: bool)

# --- Variables --- #
@export var entity: Node2D
@export var pool_id := 0

@export var max_hp := 100
var curr_hp := 0

var sequence_id := 0
var snapshots: Dictionary[int, Dictionary] = {}

# --- Functions --- #
func _ready() -> void:
	curr_hp = max_hp

func setup() -> void:
	var hp_pools: Dictionary = entity.data.get(&'hp', {})
	
	if hp_pools.is_empty() or pool_id not in hp_pools:
		return
	
	curr_hp = hp_pools[pool_id]
	
	if curr_hp <= 0:
		died.emit(true)

func take_damage(dmg_info: Dictionary) -> void:
	var damage: int = dmg_info.get(&'damage', 0)
	
	# deal damage
	modify_health(-damage, false)
	
	# build attack snapshot
	snapshots[sequence_id] = dmg_info.merged({
		&'sequence_id': sequence_id,
		&'pool_id': pool_id
	})
	
	sequence_id += 1
	
	# send data to server
	EntityManager.entity_take_damage.rpc_id(1, entity.id, snapshots[sequence_id - 1])

@rpc('authority', 'call_remote', 'reliable')
func receive_damage_snapshot(snapshot: Dictionary) -> void:
	var damage: int = snapshot.get(&'damage', 0)
	var player_id: int = snapshot.get(&'player_id', 0)
	var seq_id: int = snapshot.get(&'sequence_id', 0)
	
	if player_id == multiplayer.get_unique_id():
		var prev_snapshot: Dictionary = snapshots.get(seq_id, {})
		
		if prev_snapshot.is_empty():
			return
		
		# calculate difference in health
		var diff = snapshot.get(&'damage', 0) - prev_snapshot.get(&'damage', 0)
		
		modify_health(-diff, true)
	else:
		modify_health(-damage, true)
	
	received_damage.emit(snapshot)

func modify_health(delta: int, from_server: bool) -> void:
	curr_hp += delta
	hp_modified.emit(from_server)
	
	if curr_hp <= 0:
		# TODO: Add effects and prediction to this area
		died.emit(from_server)

func set_max_hp(hp: int) -> void:
	max_hp = hp
	curr_hp = hp

func get_hp_percent() -> float:
	return 1.0 * curr_hp / max_hp
