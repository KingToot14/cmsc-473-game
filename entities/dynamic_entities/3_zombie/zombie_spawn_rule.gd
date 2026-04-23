class_name ZombieSpawnRule
extends SpawnRule

# --- Variables --- #
@export var variant := ZombieEntity.ZombieVariant.NORMAL

# --- Functions --- #
func do_spawn(position: Vector2) -> void:
	print("dewit hehe")
	ZombieEntity.spawn(position, variant)
