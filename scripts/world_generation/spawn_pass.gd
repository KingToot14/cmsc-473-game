class_name SpawnPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Spawning Spawn"

func perform_pass(_gen: WorldGeneration) -> void:
	# sets the world spawn position
	Globals.world_spawn = Globals.world_size / 2.0 * 8
