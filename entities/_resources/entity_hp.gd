class_name EntityHp
extends Node

# --- Signals --- #
## Emitted when this node receives a damage snapshot
signal received_damage(snapshot: Dictionary)
## Emitted when this node has it's hp value modified
signal hp_modified(from_server: bool)
## Emitted when this node's hp has been reduced to 0
signal died(from_server: bool)

# --- Variables --- #
## The entity this node is tied to
@export var entity: Node2D
## The index of this node in the [member entity.hp_pool]
@export var pool_id := 0

## The max health of this node
@export var max_hp := 100
var curr_hp := 0

var sequence_id := 0
var snapshots: Dictionary[int, Dictionary] = {}

## How long before this hp can take damage from each different damage source
@export var invincibility_time := 0.50

var invincibility_timers: Dictionary[DamageSource.DamageSourceType, float] = {}

# --- Functions --- #
func _ready() -> void:
	curr_hp = max_hp

func _process(delta: float) -> void:
	# update invincibility timers
	for source_type in invincibility_timers.keys():
		if invincibility_timers[source_type] > 0.0:
			invincibility_timers[source_type] -= delta
			
			if invincibility_timers[source_type] <= 0.0:
				invincibility_timers[source_type] = 0.0

func setup() -> void:
	var hp_pools: Dictionary = entity.data.get(&'hp', {})
	
	if hp_pools.is_empty() or pool_id not in hp_pools:
		return
	
	curr_hp = hp_pools[pool_id]
	
	if curr_hp <= 0:
		died.emit(true)

## Called from external damage sources. [param dmg_info] is a dictionary containing at least:
## [br] - [code]&'damage'[/code]: The base damage to deal. This is modified by [member entity.defense]
## [br] - [code]&'player_id'[/code]: The local player's unique id. Used for damage reconciliation
func take_damage(dmg_info: Dictionary) -> void:
	var damage: int = dmg_info.get(&'damage', 0)
	var source_type: DamageSource.DamageSourceType = dmg_info.get(
		&'source_type', DamageSource.DamageSourceType.WORLD
	)
	
	# check invincibility
	if invincibility_timers.get(source_type, 0.0) > 0.0:
		return
	
	# add invincibility
	invincibility_timers[source_type] = invincibility_time
	
	# deal damage
	modify_health(-damage, false)
	
	# build attack snapshot
	snapshots[sequence_id] = dmg_info.merged({
		&'sequence_id': sequence_id,
		&'pool_id': pool_id
	})
	
	sequence_id += 1
	
	send_damage_snapshot()

func send_damage_snapshot() -> void:
	# add vertical knockback
	var snapshot: Dictionary = snapshots[sequence_id - 1]
	if entity.is_on_floor():
		snapshot[&'knockback'].y = -0.5
	
	snapshot[&'knockback'] = snapshot[&'knockback'].normalized()
	
	# send data to server
	EntityManager.entity_take_damage.rpc_id(1, entity.id, snapshots[sequence_id - 1])

@rpc('authority', 'call_remote', 'reliable')
func receive_damage_snapshot(snapshot: Dictionary) -> void:
	var damage: int = snapshot.get(&'damage', 0)
	var player_id: int = snapshot.get(&'player_id', 0)
	var seq_id: int = snapshot.get(&'sequence_id', 0)
	
	if not multiplayer.is_server() and player_id == multiplayer.get_unique_id():
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

func set_max_hp(hp: int, heal_to_full := false) -> void:
	max_hp = hp
	if heal_to_full:
		curr_hp = hp
	else:
		curr_hp = min(curr_hp, max_hp)

func get_hp_percent() -> float:
	return 1.0 * curr_hp / max_hp

func is_dead() -> bool:
	return curr_hp <= 0
