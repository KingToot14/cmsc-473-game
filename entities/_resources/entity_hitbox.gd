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
		damage: int, source_type: DamageSource.DamageSourceType, knockback := Vector2.ZERO
	) -> void:
	if entity:
		# deal damage
		entity.hp.take_damage(damage, source_type, knockback)
	if player:
		# deal damage
		player.hp.take_damage(damage, source_type, knockback)
