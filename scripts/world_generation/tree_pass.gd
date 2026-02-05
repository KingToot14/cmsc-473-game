class_name TreePass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Sprouting Trees"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	for x in range(300, world_size.x - 300, 4):
		var y := 0
		
		while y < gen.underground_high and TileManager.get_block_unsafe(x, y + 1) == 0:
			y += 1
		
		# attempt to place trees
		if TileManager.get_block_unsafe(x + 1, y) != 0 or TileManager.get_block_unsafe(x + 1, y + 1) == 0:
			return
		
		EntityManager.create_tile_entity(0, Vector2i(x, y), {})
