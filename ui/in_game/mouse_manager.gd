class_name MouseManager
extends Control

# --- Variables --- #
@export var player: PlayerController

@export var grid_overlay: Control

var current_item: Item

# --- Functions --- #
func _process(delta: float) -> void:
	# update grid overlay position (snap to actual tile grid)
	grid_overlay.global_position = Vector2(
		floorf((player.global_position.x - grid_overlay.size.x / 2.0) / 8.0) * 8.0,
		floorf((player.global_position.y - grid_overlay.size.y / 2.0) / 8.0) * 8.0
	)
	
	# update shader mouse position
	RenderingServer.global_shader_parameter_set(&"mouse_position", player.get_global_mouse_position())
	
	# process item
	if current_item:
		current_item.handle_process(player, player.get_global_mouse_position())

func _gui_input(event: InputEvent) -> void:
	# calculate global mouse position
	var mouse_position := player.get_global_mouse_position()
	var tile_position := TileManager.world_to_tile(floori(mouse_position.x), floori(mouse_position.y))
	
	# only used for client-side interaction
	if event.is_action_pressed(&'interact'):
		if Globals.hovered_hitbox and Globals.hovered_hitbox.entity.interact_with(tile_position):
			return
	if event.is_action_pressed(&'break_place'):
		# check if player can act
		if not player.can_act():
			return
		
		# check if hotbar item is empty
		var item_stack := player.my_inventory.get_selected_item()
		
		# check if item exists
		current_item = ItemDatabase.get_item(item_stack.item_id)
		if current_item:
			current_item.handle_interact_mouse_press(player, mouse_position)
	elif event.is_action_released(&'break_place'):
		# check if hotbar item is empty
		var item_stack := player.my_inventory.get_selected_item()
		
		# check if item exists
		current_item = ItemDatabase.get_item(item_stack.item_id)
		if current_item:
			current_item.handle_interact_mouse_release(player, mouse_position)
		
		# clear item
		current_item = null
