class_name DamageSource
extends Area2D

# --- Enums --- #
enum DamageSourceType {
	ENTITY,
	PLAYER,
	WORLD
}

# --- Signals --- #
signal dealt_damage

# --- Variables --- #
const SCAN_TIME := 0.10

var scan_timer := 0.0

@export var source_type := DamageSourceType.WORLD

## The base damage of the damage source.
## [br]May be overwritten by classes that extend [DamageSource]
@export var damage := 25

var overlapping_hitboxes: Array[EntityHitbox] = []

# --- Functions --- #
func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _process(delta: float) -> void:
	if scan_timer <= 0.0:
		for hitbox in overlapping_hitboxes:
			damage_hitbox(hitbox)
		
		scan_timer = SCAN_TIME
	else:
		scan_timer -= delta

## Returns the amount of damage this damage source deals.
## [br]May be overwritten by classes that extend [DamageSource]
func get_damage() -> int:
	return damage

## Returns the knockback direction given the [param target] that this damage
## source has interacted with.
func get_knockback(target: Node2D) -> Vector2:
	return Vector2(sign(target.global_position.x - global_position.x), -0.50).normalized()

func _on_area_entered(area: Area2D) -> void:
	if area is EntityHitbox:
		overlapping_hitboxes.append(area)
		
		damage_hitbox(area)

func _on_area_exited(area: Area2D) -> void:
	if area is EntityHitbox:
		overlapping_hitboxes.erase(area)

func damage_hitbox(hitbox: EntityHitbox) -> void:
	if multiplayer.is_server():
		return
	
	# don't process on incorrect types
	if source_type == DamageSourceType.ENTITY and hitbox.player == null:
		return
	if source_type == DamageSourceType.PLAYER and hitbox.entity == null:
		return
	
	# deal damage to entity
	hitbox.deal_damage(get_damage(), source_type, get_knockback(hitbox))
	dealt_damage.emit()
	send_dealt_damage.rpc_id(Globals.SERVER_ID)

@rpc('any_peer', 'call_remote', 'reliable')
func send_dealt_damage() -> void:
	dealt_damage.emit()
