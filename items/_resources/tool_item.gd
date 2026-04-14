class_name ToolItem
extends SwingItem

# --- Enums --- #
enum ToolType {
	AXE = 1,
	PICKAXE = 2,
	HAMMER = 4
}

# --- Variables --- #
@export_flags("Axe:1", "Pickaxe:2", "Hammer:4") var tool_type := 0
@export var tool_power := 25

# --- Functions --- #
func handle_process(player: PlayerController, mouse_position: Vector2) -> void:
	# only autoswing when enabled
	if not autoswing:
		return
	
	# only autoswing when mouse is held and player is not acting
	if not (mouse_pressed and player.can_act()):
		return
	
	# check range
	var tile_position: Vector2i = TileManager.world_to_tile(
		floori(mouse_position.x),
		floori(mouse_position.y)
	)
	
	use_tool(player, mouse_position, tile_position)

func handle_interact_mouse_press(player: PlayerController, mouse_position: Vector2) -> void:
	var tile_position: Vector2i = TileManager.world_to_tile(
		floori(mouse_position.x),
		floori(mouse_position.y)
	)
	
	mouse_pressed = true
	player.interpolator.queue_mouse_press(NetworkTime.time, item_id, mouse_position)
	
	# attempt to use tool
	use_tool(player, mouse_position, tile_position)

## this function just checks the tool_type and breaks the appropriate block.
func use_tool(player: PlayerController, mouse_position: Vector2, tile_position: Vector2i) -> void:
	# play swing animation
	do_swing(player, mouse_position)
	
	if not player.is_point_in_range(mouse_position):
		return # this checks to make sure the player is in range of the block.
	
	if tool_type & ToolType.AXE:
		# check if hitbox exists
		if Globals.hovered_hitbox and Globals.hovered_hitbox.entity.break_place(mouse_position):
			return
	
	if tool_type & ToolType.PICKAXE:
		print(Globals.hovered_hitbox)
		# check if hitbox exists
		if Globals.hovered_hitbox and Globals.hovered_hitbox.entity.break_place(mouse_position):
			return
		
		# if hitbox doesn't exist, break block
		if TileManager.hurt_block(tile_position.x, tile_position.y, tool_power):
			return
	
	if tool_type & ToolType.HAMMER:
		# destroy wall if hammer
		if TileManager.hurt_wall(tile_position.x, tile_position.y, tool_power):
			return
