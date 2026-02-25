class_name DamageSource
extends Area2D

# --- Enums --- #
enum DamageSourceType {
	ENTITY,
	PLAYER,
	WORLD
}

# --- Variables --- #
const SCAN_TIME := 0.10

var scan_timer := 0.0

@export var source_type := DamageSourceType.WORLD

## The base damage of the damage source.
## [br]May be overwritten by classes that extend [class DamageSource]
@export var damage := 25
## [br]Whether or not this damage source is owned by an enemy
@export var is_enemy := true

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
## [br]May be overwritten by classes that extend [class DamageSource]
func get_damage() -> int:
	return damage

## Returns the unique source id of this damage source.
## [br]May be overwritten by classes that extend [class DamageSource]
func get_source_id() -> int:
	return hash(global_position.x + global_position.y)

## Returns the knockback direction given the [param target] that this damage
## source has interacted with.
func get_knockback(target: Node2D) -> Vector2:
	return Vector2(target.global_position.x - global_position.x, 0.0).normalized()

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
	if is_enemy and hitbox.player == null:
		return
	if not is_enemy and hitbox.entity == null:
		return
	
	# deal damage to entity
	hitbox.deal_damage(get_damage(), get_source_id(), source_type, get_knockback(hitbox))
