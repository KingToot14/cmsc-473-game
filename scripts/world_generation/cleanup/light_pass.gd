class_name LightPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Changing the Lightbulbs"

func perform_pass(_gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	for x in range(0, world_size.x):
		for y in range(0, world_size.y):
			if TileManager.get_block_unsafe(x, y):
				break
			
			TileManager.set_light_level(x, y, LightUpdater.MAX_LIGHT_LEVEL)
	
	
