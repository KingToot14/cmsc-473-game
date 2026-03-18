class_name MouseManager
extends Control

# --- Variables --- #
@export var player: PlayerController

@export var grid_overlay: Control
@export var placement_preview: Sprite2D

var current_item: Item
var cursor_locked := false

# --- Functions --- #
func _ready() -> void:
	if player.owner_id == multiplayer.get_unique_id():
		Globals.mouse = self
		
		# listen for inventory updates
		player.my_inventory.inventory_updated.connect(_on_inventory_changed)

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

func _input(event: InputEvent) -> void:
	var mouse_position := player.get_global_mouse_position()
	
	# only used for client-side interaction
	if event.is_action_pressed(&'interact'):
		if Globals.hovered_hitbox and Globals.hovered_hitbox.entity.interact_with(mouse_position):
			return

func _gui_input(event: InputEvent) -> void:
	# calculate global mouse position
	var mouse_position := player.get_global_mouse_position()
		
	if event.is_action_pressed(&'break_place'):
		# check if player can act
		if not player.can_act():
			return
		
		# check if item exists
		if current_item:
			current_item.handle_interact_mouse_press(player, mouse_position)
		
	elif event.is_action_released(&'break_place'):
		# check if item exists
		if current_item:
			current_item.handle_interact_mouse_release(player, mouse_position)

func _on_inventory_changed() -> void:
	var item_stack := player.my_inventory.get_selected_item()
	
	# don't process if item already set
	if current_item and item_stack.item_id == current_item.item_id:
		return
	
	# disable old item
	if current_item:
		current_item.handle_selected_end()
	
	# check for null item
	if item_stack.item_id == -1:
		current_item = null
		return
	
	# otherwise update current item
	current_item = ItemDatabase.get_item(item_stack.item_id)
	current_item.handle_selected_start()
