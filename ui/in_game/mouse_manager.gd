class_name MouseManager
extends Control

# --- Variables --- #
@export var player: PlayerController

@export var grid_overlay: Control

var current_item: Item

var cursor_locked := false

# --- Functions --- #
func _ready() -> void:
	if player.owner_id == multiplayer.get_unique_id():
		Globals.mouse = self

func _process(_delta: float) -> void:
	# update grid overlay position (snap to actual tile grid)
	grid_overlay.global_position = Vector2(
		floorf((player.global_position.x - grid_overlay.size.x / 2.0) / 8.0) * 8.0,
		floorf((player.global_position.y - grid_overlay.size.y / 2.0) / 8.0) * 8.0
	)
	
	# update shader mouse position
	var mouse_pos := player.get_global_mouse_position()
	
	RenderingServer.global_shader_parameter_set(&"mouse_position", mouse_pos)
	
	# process item
	if current_item:
		current_item.handle_process(player, mouse_pos)
	
	# update mouse type
	if cursor_locked:
		return
	
	var item := ItemDatabase.get_item(player.my_inventory.get_selected_item().item_id)
	
	# try to match tool
	if item and item is ToolItem:
		# load pickaxe cursor
		if item.tool_type == ToolItem.ToolType.PICKAXE:
			Globals.set_cursor(Globals.CursorType.PICKAXE)
			return
		# load axe cursor
		elif item.tool_type == ToolItem.ToolType.AXE:
			Globals.set_cursor(Globals.CursorType.AXE)
			return
		# load hammer cursor
		elif item.tool_type == ToolItem.ToolType.HAMMER:
			Globals.set_cursor(Globals.CursorType.HAMMER)
			return
	# try to match block
	elif item and item is BlockItem:
		# load block cursor
		if item.tile_type == BlockItem.TileType.BLOCK:
			Globals.set_cursor(Globals.CursorType.BLOCK)
			return
		# load wall cursor
		elif item.tile_type == BlockItem.TileType.WALL:
			Globals.set_cursor(Globals.CursorType.WALL)
			return
	
	Globals.set_cursor(Globals.CursorType.ARROW)

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
