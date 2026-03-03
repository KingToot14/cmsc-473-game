class_name ToolItem
extends SwingItem

# --- Enums --- #
enum ToolType {
	AXE,
	PICKAXE,
	HAMMER
}

@export var tool_type := ToolType.AXE
@export var tool_power := 25
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
#this function just checks the tool_type and breaks the appropriate block.
func use_tool(player: PlayerController, mouse_position: Vector2, tile_position: Vector2i) -> void:
	if not is_point_in_range(player, mouse_position):
		return #this checks to make sure the player is in range of the block.
	if tool_type == ToolType.AXE:
			if Globals.hovered_hitbox and Globals.hovered_hitbox.entity.break_place(tile_position):
				return
	elif tool_type == ToolType.PICKAXE:
			TileManager.destroy_block(tile_position.x, tile_position.y)
	elif tool_type == ToolType.HAMMER:
			TileManager.destroy_wall(tile_position.x, tile_position.y)
