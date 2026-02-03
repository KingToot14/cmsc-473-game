class_name ResetPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Preparing World"

func perform_pass(_gen: WorldGeneration) -> void:
	# setup tile manager
	if TileManager.world_width == 0 or TileManager.world_height == 0:
		TileManager._update_world_size(Globals.world_size)
	
	TileManager.load_chunks()
