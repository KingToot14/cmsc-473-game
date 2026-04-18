class_name DirtToSandPass
extends WorldGenPass

func get_pass_name() -> String:
	return "Sifting through the dunes"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	var center_x := floori(world_size.x / 2.0)
	
	# Constraints
	var min_dist := floori(world_size.x * 0.10)
	var edge_buffer := floori(world_size.x * 0.20)
	
	# Logic: If winter is on the right, sand goes on the left (and vice versa)
	var start_x = edge_buffer if gen.winter_on_right else (center_x + min_dist)
	var end_x = (center_x - min_dist) if gen.winter_on_right else (world_size.x - edge_buffer)
	
	var total_width = abs(end_x - start_x)
	var progress_step := floori(total_width * 0.25) if total_width > 0 else 1
	
	for x in range(start_x, end_x):
		# Progress updates
		if progress_step > 0 and (x - start_x) % progress_step == 1:
			var progress = (float(x - start_x) / total_width) * 100.0
			push_message("%d%% Complete" % progress)
		
		# Iterate from the bottom up or top down; top-down is usually safer for gravity checks
		for y in range(world_size.y):
			var block = TileManager.get_block_unsafe(x, y)
			
			# 1. Replace Dirt (1, 2, 9) with Sand (8)
			if block in [1, 2, 9]: 
				TileManager.set_block_unsafe(x, y, 8)
				
				# 2. GRAVITY PROTECTION: Check the block immediately below
				if y + 1 < world_size.y:
					var block_below = TileManager.get_block_unsafe(x, y + 1)
					# If the block below is air (0), fill it with Sandstone (29) 
					# so the sand we just placed doesn't fall.
					if block_below == 0:
						TileManager.set_block_unsafe(x, y + 1, 29)
			
			# 3. Overwrite dirt walls (ID 1) with Sand walls (ID 5)
			if TileManager.get_wall_unsafe(x, y) == 1:
				TileManager.set_wall_unsafe(x, y, 5)
	
	push_message("100% Complete")
	exit_pass()
