class_name PlayerHp
extends EntityHp

# --- Variables --- #
## Replaces [member entity] for players since they require different logic
@export var player: PlayerController

# --- Functions --- #
func apply_knockback(knockback: Vector2) -> void:
	player.pending_knockback = knockback * player.knockback_power

func send_damage_data(data: PackedByteArray) -> void:
	receive_damage.rpc_id(Globals.SERVER_ID, data)
