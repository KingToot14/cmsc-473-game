class_name EntityHitbox
extends Area2D

# --- Variables --- #
@export var entity: Entity
@export var player: PlayerController
@export var pool_id := 0

# --- Functions --- #
func _ready() -> void:
	pass

func deal_damage(
		damage: int, source_id: int, source_type: DamageSource.DamageSourceType, knockback := Vector2.ZERO
	) -> void:
	if entity:
		# deal damage
		entity.hp_pool[0].take_damage({
			&'damage': damage - entity.defense,
			&'player_id': multiplayer.get_unique_id(),
			&'source_id': source_id,
			&'source_type': source_type,
			&'knockback': knockback
		})
	if player:
		# deal damage
		player.hp.take_damage({
			&'damage': damage - player.defense,
			&'player_id': multiplayer.get_unique_id(),
			&'source_id': source_id,
			&'source_type': source_type,
			&'knockback': knockback
		})
