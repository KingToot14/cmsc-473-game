class_name PlayerHp
extends EntityHp

# --- Variables --- #
## Replaces [member entity] for players since they require different logic
@export var player: PlayerController

# --- Functions --- #
func _ready() -> void:
	super()
	
	received_damage.connect(player.receive_damage_snapshot)

func apply_knockback(knockback: Vector2) -> void:
	player.pending_knockback = knockback * player.knockback_power

func send_damage_snapshot() -> void:
	# send data to server
	if multiplayer.is_server():
		return
	
	# calculate knockback
	var snapshot: Dictionary = snapshots[sequence_id - 1]
	if player.is_on_floor():
		snapshot[&'knockback'].y = -0.5
	
	snapshot[&'knockback'] = snapshot[&'knockback'].normalized()
	
	
	update_player_hp.rpc_id(1, snapshot)

func setup() -> void:
	return

@rpc('any_peer', 'call_remote', 'reliable')
func update_player_hp(snapshot: Dictionary) -> void:
	# TODO: verify attack
	var damage: int = snapshot.get(&'damage', 0)
	
	# apply damage
	player.hp.modify_health(-damage)
	
	# TODO: Store hp in database
	pass
	
	if player.hp.curr_hp <= 0:
		snapshot[&'entity_dead'] = true
	
	# call receive signal on server copy
	player.hp.received_damage.emit(snapshot)
	
	# send to players
	player.hp.receive_damage_snapshot.rpc(snapshot)
