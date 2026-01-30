class_name SpawnPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func perform_pass(gen: WorldGeneration) -> void:
	# sets the world spawn position
	gen.world_spawn = gen.world_size / 2.0
