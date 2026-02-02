class_name SmoothPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Smoothing World"

func perform_pass(_gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	for x in range(20, world_size.x - 20):
		for y in range(20, world_size.y - 20):
			if TileManager.get_block_unsafe(x, y) > 0:
				# remove single blocks
				if TileManager.get_block_unsafe(x - 1, y) <= 0 and TileManager.get_block_unsafe(x + 1, y) <= 0:
					TileManager.set_block_unsafe(x, y, 0)
	
	exit_pass()
