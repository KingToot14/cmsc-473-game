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
			if TileManager.get_block_unsafe(x, y) != 0 or TileManager.get_wall_unsafe(x, y) != 0:
				break
			
			TileManager.set_light_sky(x, y, LightUpdater.MAX_LIGHT_LEVEL)
			
			Globals.light_updater.add_to_queue(
				Vector2i(x, y),
				LightUpdater.MAX_LIGHT_LEVEL, LightUpdater.MAX_LIGHT_LEVEL, LightUpdater.MAX_LIGHT_LEVEL
			)
	
	Globals.light_updater.propagate_all()
	
	await Globals.light_updater.propagated
