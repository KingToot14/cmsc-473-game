class_name SwingItem
extends Item

# --- Variables --- #
## The base animation length for the swing animations
const BASE_SWING_SPEED := 0.8

## If true, the swing direction will be set to face the mouse instead of
## the player's movement direction
@export var force_towards_mouse := false

## How many seconds this item takes to swing.
@export var use_speed := 0.8

## The object to load if no object is passed into [method do_string]
@export var default_swing_object: PackedScene

# --- Functions --- #
func handle_interact_mouse(player: PlayerController, mouse_position: Vector2) -> void:
	do_swing(player, mouse_position)

## Plays the swing animation on the current player
func do_swing(player: PlayerController, mouse_position: Vector2, swing_object: Node2D = null) -> void:
	var object: Node2D
	var object_root: Node2D = player.get_node(^'outfit/tool_holder')
	
	# set swing object
	if swing_object:
		object = swing_object
	else:
		object = default_swing_object.instantiate()
	
	# remove old objects
	for child in object_root.get_children():
		child.queue_free()
	
	# load new object
	object_root.add_child(object)
	
	# play animation
	var direction := 0
	if force_towards_mouse:
		if (mouse_position.x - player.center_point.x) > 0.0:
			direction = 1
		else:
			direction = -1
	
	player.do_swing(BASE_SWING_SPEED / use_speed, direction)
