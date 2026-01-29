class_name ResetPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func perform_pass(gen: WorldGeneration) -> void:
	# setup tile manager
	TileManager.world_size = gen.world_size
