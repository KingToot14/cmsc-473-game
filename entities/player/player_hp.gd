class_name PlayerHp
extends EntityHp

# --- Variables --- #
## Replaces [member entity] for players since they require different logic
@export var player: PlayerController

# --- Regen Variables --- #
@export var regen_amount := 2
@export var regen_interval := 1.0
var regen_timer := 0.0

# --- Functions --- #
func _process(delta: float) -> void:
	super._process(delta) 
	
	# only regenerate if the player is alive and currently injured
	if curr_hp > 0 and curr_hp < max_hp:
		regen_timer += delta
		if regen_timer >= regen_interval:
			regen_timer -= regen_interval
			modify_health(regen_amount)
			print("Player healed: ", regen_amount)

func modify_health(delta: int, update := true) -> void:
	super.modify_health(delta, update)
	
	# clamp health so regeneration doesn't overheal the player
	if curr_hp > max_hp:
		curr_hp = max_hp
		
	# debug print for taking damage
	if delta < 0:
		print("[Debug] Player took ", -delta, " damage! Remaining HP: ", curr_hp, " / ", max_hp)

func apply_knockback(knockback: Vector2) -> void:
	player.pending_knockback = knockback * player.knockback_power

func send_damage_data(data: PackedByteArray) -> void:
	receive_damage.rpc_id(Globals.SERVER_ID, data)
