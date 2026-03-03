class_name PlayerHp
extends EntityHp

# --- Variables --- #
## Replaces [member entity] for players since they require different logic
@export var player: PlayerController

# --- Functions --- #
func apply_knockback(knockback: Vector2) -> void:
	player.pending_knockback = knockback * player.knockback_power
