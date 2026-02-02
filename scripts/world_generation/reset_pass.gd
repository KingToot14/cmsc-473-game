class_name ResetPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Preparing World"

func perform_pass(_gen: WorldGeneration) -> void:
	# setup tile manager
	TileManager.load_chunks()
