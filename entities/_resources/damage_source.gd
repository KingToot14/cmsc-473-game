class_name DamageSource
extends Area2D

# --- Enums --- #
enum DamageSourceType {
	ENTITY,
	PLAYER,
	WORLD
}

# --- Variables --- #
@export var source_type := DamageSourceType.WORLD

## The base damage of the damage source.
## [br]May be overwritten by classes that extend [class DamageSource]
@export var damage := 25
## [br]Whether or not this damage source is owned by an enemy
@export var is_enemy := true

# --- Functions --- #
func _ready() -> void:
	area_entered.connect(_on_area_entered)

## Returns the amount of damage this damage source deals.
## [br]May be overwritten by classes that extend [class DamageSource]
func get_damage() -> int:
	return damage

## Returns the unique source id of this damage source.
## [br]May be overwritten by classes that extend [class DamageSource]
func get_source_id() -> int:
	return hash(global_position.x + global_position.y)

func _on_area_entered(area: Area2D) -> void:
	if area is not EntityHitbox:
		return
	
	var hitbox: EntityHitbox = area
	
	# don't process on incorrect types
	if is_enemy and hitbox.player == null:
		return
	if not is_enemy and hitbox.entity == null:
		return
	
	# deal damage to entity
	hitbox.deal_damage(get_damage(), get_source_id(), source_type)
