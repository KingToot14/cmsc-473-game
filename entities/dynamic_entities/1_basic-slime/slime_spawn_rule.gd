class_name SlimeSpawnRule
extends SpawnRule

# --- Variables --- #
@export var variant := BasicSlimeEntity.SlimeVariant.GREEN

# --- Functions --- #
func do_spawn(position: Vector2) -> void:
	BasicSlimeEntity.spawn(position, variant)
