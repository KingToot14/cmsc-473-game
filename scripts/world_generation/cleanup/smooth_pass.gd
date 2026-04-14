class_name SmoothPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Smoothing World"

func perform_pass(_gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	var progress_step := floori((world_size.x - 40) * 0.25)

	for x in range(20, world_size.x - 20):
		if (x - 20) % progress_step == 0:
			push_message("%d%% Complete" % (x / float(world_size.x - 40) * 100))
		
		for y in range(20, world_size.y - 20):
			if TileManager.get_block_unsafe(x, y) > 0:
				# remove single blocks
				if TileManager.get_block_unsafe(x - 1, y) <= 0 and TileManager.get_block_unsafe(x + 1, y) <= 0:
					TileManager.set_block_unsafe(x, y, 0)
	
	push_message("100% Complete")
