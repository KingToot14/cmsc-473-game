class_name LightPass
extends WorldGenPass

# --- Variables --- #

# --- Functions --- #
func get_pass_name() -> String:
	return "Changing the Lightbulbs"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	var progress_step := floori(world_size.x * 0.25)
	
	# set sky light
	for x in range(0, world_size.x):
		if x % progress_step == 0:
			push_message("%d%% Complete (Sky)" % (float(x) / world_size.x * 100))
		
		for y in range(0, gen.surface_low + 32):
			if TileManager.get_block_unsafe(x, y) != 0 or TileManager.get_wall_unsafe(x, y) != 0:
				break
			
			TileManager.set_light_sky(x, y, LightUpdater.MAX_LIGHT_LEVEL)
			
			# don't add to queue if all around is full
			if TileManager.get_block_unsafe(x - 1, y) and TileManager.get_wall_unsafe(x - 1, y) and \
				TileManager.get_block_unsafe(x, y - 1) and TileManager.get_wall_unsafe(x, y - 1) and \
				TileManager.get_block_unsafe(x + 1, y) and TileManager.get_wall_unsafe(x + 1, y) and \
				TileManager.get_block_unsafe(x, y + 1) and TileManager.get_wall_unsafe(x, y + 1):
			
				continue
			
			Globals.light_updater.add_to_queue(Vector2i(x, y), LightUpdater.MAX_LIGHT_LEVEL)
	
	push_message("100% Complete (Sky)")
	
	for x in range(0, world_size.x):
		if x % progress_step == 0:
			push_message("%d%% Complete (Underworld)" % (float(x) / world_size.x * 100))
		
		for y in range(world_size.y - 150, world_size.y):
			if TileManager.get_block_unsafe(x, y) != 0 or TileManager.get_wall_unsafe(x, y) != 0:
				continue
			
			TileManager.set_light_color(x, y, 
				LightUpdater.UNDERWORLD_R,
				LightUpdater.UNDERWORLD_G,
				LightUpdater.UNDERWORLD_B
			)
			
			Globals.light_updater.add_to_queue(Vector2i(x, y), LightUpdater.MAX_LIGHT_LEVEL)
	
	push_message("100% Complete (Underworld)")
	push_message("Propagating")
	
	Globals.light_updater.propagate_all()
	
	await Globals.light_updater.propagated
