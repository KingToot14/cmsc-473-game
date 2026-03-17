class_name EntityDamageSource
extends DamageSource

# --- Variables --- #
## The entity this damage source belongs to
@export var entity: Entity
## A multiplier used in [method get_damage] that multiplies [member entity.damage]
@export var damage_modifier := 1.0

# --- Functions --- #
func get_damage() -> int:
	return floori(entity.damage * damage_modifier)

func get_source_id() -> int:
	return entity.id
