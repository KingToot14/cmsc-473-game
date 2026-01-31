class_name SpawnPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Spawning Spawn"

func perform_pass(_gen: WorldGeneration) -> void:
	# sets the world spawn position
	var spawn_position := Vector2i(roundi(Globals.world_size.x / 2.0), 0)
	
	for y in range(Globals.world_size.y):
		#print(spawn_position, " | ", TileManager.get_block(spawn_position.x, spawn_position.y + 1))
		
		if TileManager.get_block(spawn_position.x, spawn_position.y + 1) > 0:
			break
		
		spawn_position.y += 1
	
	Globals.world_spawn = spawn_position * 8.0
	
	exit_pass()
