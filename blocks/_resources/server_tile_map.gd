class_name ServerTileMap
extends TileMapLayer

# --- Variables --- #


# --- Functions --- #
func _ready() -> void:
	Globals.server_map = self

func load_tiles(start_x: int, start_y: int, width: int, height: int) -> void:
	var processed := 0
	
	for x in range(width):
		for y in range(height):
			var block = TileManager.get_block_unsafe(start_x + x, start_y + y)
			
			if block == 0:
				erase_cell(Vector2i(start_x + x, start_y + y))
			else:
				set_cell(Vector2i(start_x + x, start_y + y), block, Vector2i(0, 0))
			
			processed += 1
			
			if processed == 256 * 4:
				await get_tree().process_frame
				processed = 0

func update_tile(x: int, y: int) -> void:
	var block = TileManager.get_block_unsafe(x, y)
	
	if not block:
		erase_cell(Vector2i(x, y))
	else:
		set_cell(Vector2i(x, y), block, Vector2i(0, 0))
