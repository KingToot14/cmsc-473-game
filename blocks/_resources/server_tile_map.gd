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
			set_cell(
				Vector2i(start_x + x, start_y + y),
				TileManager.get_block_unsafe(start_x + x, start_y + y),
				Vector2i(0, 0)
			)
			
			processed += 1
			
			if processed == 32:
				await get_tree().process_frame
				processed = 0
