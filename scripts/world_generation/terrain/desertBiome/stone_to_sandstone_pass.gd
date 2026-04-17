class_name StoneToSandstonePass
extends WorldGenPass

func get_pass_name() -> String:
	return "Solidifying the dunes"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	var center_x := floori(world_size.x / 2.0)
	
	# Constraints - Matching your DirtToSandPass exactly
	var min_dist := floori(world_size.x * 0.10)
	var edge_buffer := floori(world_size.x * 0.20)
	
	# Logic: If winter is on the right, sandstone goes on the left (and vice versa)
	var start_x = edge_buffer if gen.winter_on_right else (center_x + min_dist)
	var end_x = (center_x - min_dist) if gen.winter_on_right else (world_size.x - edge_buffer)
	
	var total_width = abs(end_x - start_x)
	var progress_step := floori(total_width * 0.25) if total_width > 0 else 1
	
	for x in range(start_x, end_x):
		# Progress updates
		if progress_step > 0 and (x - start_x) % progress_step == 1:
			var progress = (float(x - start_x) / total_width) * 100.0
			push_message("%d%% Complete" % progress)
		
		for y in range(world_size.y):
			var block = TileManager.get_block_unsafe(x, y)
			
			# Replace Stone (3) with Sandstone (29)
			if block == 3:
				TileManager.set_block_unsafe(x, y, 29)
				
			# Optional: If you have a specific Sandstone Wall, 
			# you would add the set_wall_unsafe logic here as well.
	
	push_message("100% Complete")
	
	exit_pass()
