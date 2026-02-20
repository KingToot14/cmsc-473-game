class_name PlayerHp
extends EntityHp

# --- Variables --- #
## Replaces [member entity] for players since they require different logic
@export var player: PlayerController

# --- Functions --- #
func _ready() -> void:
	super()
	
	received_damage.connect(player.receive_damage_snapshot)

func send_damage_snapshot() -> void:
	# send data to server
	if multiplayer.is_server():
		return
	
	# calculate knockback
	var snapshot: Dictionary = snapshots[sequence_id - 1]
	var source_id: int = snapshot.get(&'source_id', 0)
	var source_type: DamageSource.DamageSourceType = \
		snapshot.get(&'source_type', DamageSource.DamageSourceType.WORLD)
	
	var knockback_force := Vector2(1.0, 0.0)
	if source_type == DamageSource.DamageSourceType.ENTITY:
		var attacker: Node2D = EntityManager.loaded_entities.get(source_id)
		
		if is_instance_valid(attacker):
			if attacker.global_position.x > player.global_position.x:
				knockback_force.x *= -1
		
			# apply slight upward force if leveld
			if player.is_on_floor():
				knockback_force.y = -0.5
		
			snapshot[&'knockback'] = knockback_force.normalized()
	
	# update local client
	#player.hp.receive_damage_snapshot(snapshot)
	
	update_player_hp.rpc_id(1, snapshot)

func setup() -> void:
	return

@rpc('any_peer', 'call_remote', 'reliable')
func update_player_hp(snapshot: Dictionary) -> void:
	# TODO: verify attack
	var damage: int = snapshot.get(&'damage', 0)
	
	# apply damage
	player.hp.modify_health(-damage, true)
	
	# TODO: Store hp in database
	pass
	
	if player.hp.curr_hp <= 0:
		snapshot[&'entity_dead'] = true
	
	# call receive signal on server copy
	player.hp.received_damage.emit(snapshot)
	
	# send to players
	player.hp.receive_damage_snapshot.rpc(snapshot)
