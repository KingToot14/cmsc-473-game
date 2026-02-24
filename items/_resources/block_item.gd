class_name BlockItem
extends SwingItem

# --- Enums --- #
enum TileType {
	BLOCK,
	WALL,
	TILE
}

# --- Variables --- #
## The tile type this item represents. Changes how [member tile_id] is interpreted:
## [br] - [enum TileType.BLOCK]: [member tile_id] represents [code]block_id[/code]
## [br] - [enum TileType.WALL]: [member tile_id] represents [code]wall_id[/code]
## [br] - [enum TileType.TILE]: [member tile_id] represents [code]tile_entity_id[/code]
@export var tile_type := TileType.BLOCK
## The tile_id that this item points to. Changes based on [member tile_type]
@export var tile_id := 0

# --- Functions --- #
func handle_interact_mouse(player: PlayerController, mouse_position: Vector2) -> void:
	# check range
	if not is_point_in_range(player, mouse_position):
		return
	
	# get tile range
	var tile_position: Vector2i = TileManager.world_to_tile(  
		floori(mouse_position.x),
		floori(mouse_position.y)
	)
	
	# create swing object
	var item_object = preload('res://items/_resources/item_tool.tscn').instantiate()
	item_object.get_node(^'sprite').texture = texture
	
	do_swing(player, mouse_position, item_object)
	
	# attempt to place block
	match tile_type:
		TileType.BLOCK:
			if TileManager.place_block(tile_position.x, tile_position.y, item_id):
				# decrement item TODO: check held item first
				var hotbar_slot: int = player.my_inventory.hotbar_slot
				
				player.my_inventory.remove_item_at(item_id, 1, hotbar_slot)
		TileType.WALL:
			if TileManager.place_wall(tile_position.x, tile_position.y, item_id):
				# decrement item TODO: check held item first
				var hotbar_slot: int = player.my_inventory.hotbar_slot
				
				player.my_inventory.remove_item_at(item_id, 1, hotbar_slot)
		TileType.TILE:
			print("TILE ENTITIES NOT IMPLEMENTED YET")
