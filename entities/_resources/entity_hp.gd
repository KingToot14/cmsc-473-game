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
	var dmg: int = dmg_info.get(&'damage', 0)
	
	# deal damage
	curr_hp -= dmg
	hp_modified.emit()
	
	if curr_hp <= 0:
		# TODO: Add effects and prediction to this area
		died.emit()
	
	print("Took %s damage from %s" % [dmg, dmg_info.get(&'player_id', 0)])
	
	# build attack snapshot
	snapshots[sequence_id] = dmg_info.merged({
		&'sequence_id': sequence_id,
	})
	
	sequence_id += 1
	
	# send data to server
	EntityManager.entity_take_damage.rpc_id(1, entity.id, snapshots[sequence_id - 1])

func receive_damage_snapshot(snapshot: Dictionary) -> void:
	pass
