class_name MouseManager
extends Control

# --- Variables --- #
@export var player: PlayerController

@export var grid_overlay: Control

# --- Functions --- #
func _process(delta: float) -> void:
	grid_overlay.global_position = Vector2(
		floorf((player.global_position.x - grid_overlay.size.x / 2.0) / 8.0) * 8.0,
		floorf((player.global_position.y - grid_overlay.size.y / 2.0) / 8.0) * 8.0
	)
	
	RenderingServer.global_shader_parameter_set(&"mouse_position", player.get_global_mouse_position())

func _gui_input(event: InputEvent) -> void:
	# calculate global mouse position
	var mouse_position := get_global_mouse_position()
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
		var item_stack: Inventory.ItemStack = player.my_inventory.get_selected_item()
		if item_stack.is_empty():
			return
		
		# check if item exists
		var item: Item = ItemDatabase.get_item(item_stack.item_id)
		if item:
			item.handle_interact_mouse(player, mouse_position)
