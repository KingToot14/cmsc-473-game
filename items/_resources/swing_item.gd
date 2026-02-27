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
	# send action to client
	player.snapshot_interpolator.queue_action.rpc_id(1, {
		&'tick': NetworkTime.tick,
		&'item_id': item_id,
		&'action_type': &'interact_mouse',
		&'mouse_position': mouse_position
	})
	
	# do animation
	do_swing(player, mouse_position)
	var selected: Inventory.ItemStack = player.my_inventory.get_selected_item()
	if selected.item_id == 7:
		# checks the range
		if not is_point_in_range(player, mouse_position):
			return

		#grabs the tile position
		var tile_position: Vector2i = TileManager.world_to_tile(
			floori(mouse_position.x),
			floori(mouse_position.y)
		)
		
		# attempt to interact with tile entity
		if Globals.hovered_hitbox and Globals.hovered_hitbox.entity.break_place(tile_position):
			return
		
		#sends the destroy block function.
		if TileManager.destroy_block(tile_position.x, tile_position.y):
			return

	elif selected.item_id == 9:
		# checks the range
		if not is_point_in_range(player, mouse_position):
			return

		#grabs the tile position
		var tile_position: Vector2i = TileManager.world_to_tile(
			floori(mouse_position.x),
			floori(mouse_position.y)
		)

		#sends the destroy block function.
		if TileManager.destroy_wall(tile_position.x, tile_position.y):
			return
	

func simulate_interact_mouse(player: PlayerController, mouse_position: Vector2) -> void:
	# create dummy object
	var object: Node2D = default_swing_object.instantiate()
	if object is ItemToolObject:
		object.set_to_simulate()
	
	# do animation
	do_swing(player, mouse_position, object)

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
