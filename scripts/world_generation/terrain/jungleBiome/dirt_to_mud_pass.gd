class_name DirtToMudPass
extends WorldGenPass

func get_pass_name() -> String:
	return "Establishing the coastal jungle"

func perform_pass(_gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	# 1. Determine which side the jungle is on (randomly)
	# You might want to store 'jungle_on_right' in your gen object 
	# if other passes need to know where the jungle is.
	var jungle_on_right: bool = randf() > 0.5
	
	# 2. Define the "Ocean Border" zone
	# We target the first 15% of the world width on either the far left or far right.
	var zone_width := floori(world_size.x * 0.15)
	var start_x: int
	var end_x: int
	
	if jungle_on_right:
		start_x = world_size.x - zone_width
		end_x = world_size.x
	else:
		start_x = 0
		end_x = zone_width
	
	var total_width = abs(end_x - start_x)
	var progress_step := floori(total_width * 0.25) if total_width > 0 else 1
	
	for x in range(start_x, end_x):
		# Progress updates
		if progress_step > 0 and (x - start_x) % progress_step == 1:
			var progress = (float(x - start_x) / total_width) * 100.0
			push_message("Planting Jungle: %d%%" % progress)
		
		for y in range(world_size.y):
			var block = TileManager.get_block_unsafe(x, y)
			
			# Replace Dirt (1, 2, 9) with Mud (30)
			# We leave walls as Dirt (ID 1) as requested.
			if block in [1, 2, 9]: 
				TileManager.set_block_unsafe(x, y, 30)
	
	push_message("Jungle Mud 100% Complete")
	exit_pass()
