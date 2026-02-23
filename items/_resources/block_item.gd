class_name BlockItem
extends Item

# --- Enums --- #
enum TileType {
	BLOCK,
	WALL,
	TILE
}

# --- Variables --- #
@export var tile_type := TileType.BLOCK
@export var tile_id := 0

# --- Functions --- #
func handle_interact_mouse(mouse_position: Vector2) -> void:
	# check range
	if not is_point_in_range(mouse_position):
		return
	
	# get tile range
	var tile_position: Vector2i = TileManager.world_to_tile(
		floori(mouse_position.x),
		floori(mouse_position.y)
	)
	
	# attempt to place block
	match tile_type:
		TileType.BLOCK:
			TileManager.place_block(tile_position.x, tile_position.y, tile_id)
		TileType.WALL:
			TileManager.place_wall(tile_position.x, tile_position.y, tile_id)
		TileType.TILE:
			print("TILE ENTITIES NOT IMPLEMENTED YET")
