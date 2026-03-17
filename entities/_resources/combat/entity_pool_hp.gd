class_name EntityPoolHp
extends EntityHp

# --- Variables --- #
@export var is_group := false
@export var pool_id := 0

@export var hp_pool: Dictionary[int, EntityPoolHp] = {}
@export var main_hp: EntityPoolHp

# --- Functions --- #
func take_damage(
		damage: int, source_type: DamageSource.DamageSourceType, knockback := Vector2.ZERO
	) -> void:
	
	# don't process on group nodes
	if is_group:
		return
	
	# check invincibility
	if invincibility_timers.get(source_type, 0.0) > 0.0:
		return
	
	# add invincibility
	if source_type == DamageSource.DamageSourceType.WORLD:
		invincibility_timers[source_type] = world_invincibility_time
	else:
		invincibility_timers[source_type] = invincibility_time
	
	# deal damage
	modify_health(-damage)
	
	# send damage to server
	main_hp.send_damage_to_id(damage, pool_id, source_type, knockback)

func send_damage_to_id(
		damage: int, id: int, source_type: DamageSource.DamageSourceType, knockback := Vector2.ZERO
	) -> void:
	
	# uint32 (4) + uint16 (2) + 2 floats (2 * 4)
	var buffer := StreamPeerBuffer.new()
	buffer.resize(4 + 2 + (2 * 4))
	
	# damage info
	buffer.put_u32(damage)
	buffer.put_u16(source_type)
	
	# knockback
	buffer.put_float(knockback.x)
	buffer.put_float(knockback.y)
	
	# pool id
	buffer.put_u8(id)
	
	send_damage_data(buffer.data_array)

@rpc('any_peer', 'call_remote', 'reliable')
func receive_damage(damage_info: PackedByteArray) -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = damage_info
	
	# damage info
	var damage := buffer.get_u32()
	var source_type := buffer.get_u16() as DamageSource.DamageSourceType
	
	# knockback
	var knockback := Vector2.ZERO
	knockback.x = buffer.get_float()
	knockback.y = buffer.get_float()
	
	# pool id
	var target_id := buffer.get_u8()
	
	# deal damage
	var target_hp: EntityPoolHp = hp_pool.get(target_id)
	
	if not target_hp:
		return
	
	target_hp.modify_health(-damage)
	target_hp.apply_knockback(knockback)
	
	# server-side response to damage
	received_damage.emit(damage, source_type, knockback, multiplayer.get_remote_sender_id())
