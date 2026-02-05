class_name EntityHp
extends Node

# --- Signals --- #
signal hp_modified()
signal died()

# --- Variables --- #
@export var entity: Entity
@export var max_hp := 100
var curr_hp := 0

var sequence_id := 0
var snapshots: Dictionary[int, Dictionary] = {}

# --- Functions --- #
func _ready() -> void:
	curr_hp = max_hp

func setup() -> void:
	curr_hp = entity.data.get(&'hp', curr_hp)

func take_damage(dmg_info: Dictionary) -> void:
	var damage: int = dmg_info.get(&'damage', 0)
	
	# deal damage
	modify_health(-damage)
	
	print("Took %s damage from %s" % [damage, dmg_info.get(&'player_id', 0)])
	
	# build attack snapshot
	snapshots[sequence_id] = dmg_info.merged({
		&'sequence_id': sequence_id,
	})
	
	sequence_id += 1
	
	# send data to server
	EntityManager.entity_take_damage.rpc_id(1, entity.id, snapshots[sequence_id - 1])

@rpc('authority', 'call_local', 'reliable')
func receive_damage_snapshot(snapshot: Dictionary) -> void:
	var damage: int = snapshot.get(&'damage', 0)
	var player_id: int = snapshot.get(&'player_id', 0)
	var seq_id: int = snapshot.get(&'sequence_id', 0)
	
	print("Received snapshot: ", snapshot)
	
	if player_id == multiplayer.get_unique_id():
		var prev_snapshot: Dictionary = snapshots.get(seq_id)
		
		if not prev_snapshot:
			return
		
		# calculate difference in health
		var diff = snapshot.get(&'damage', 0) - prev_snapshot.get(&'damage', 0)
		
		if diff > 0:
			modify_health(-diff)
	else:
		modify_health(-damage)

func modify_health(delta: int) -> void:
	curr_hp += delta
	hp_modified.emit()
	
	if curr_hp <= 0:
		# TODO: Add effects and prediction to this area
		died.emit()
