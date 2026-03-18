class_name DirtToSnowPass
extends WorldGenPass

func get_pass_name() -> String:
	return "I'm chilly"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	var center_x := floori(world_size.x / 2)
	
	# Constraints
	var min_dist := floori(world_size.x * 0.10)
	var edge_buffer := floori(world_size.x * 0.20)
	
	# Use the pre-calculated side from world_generation.gd
	var start_x = (center_x + min_dist) if gen.winter_on_right else edge_buffer
	var end_x = (world_size.x - edge_buffer) if gen.winter_on_right else (center_x - min_dist)
	
	for x in range(start_x, end_x):
		for y in range(world_size.y):
			var block = TileManager.get_block_unsafe(x, y)
			
			if block in [1, 2, 8, 9]: 
				TileManager.set_block_unsafe(x, y, 6)
	
	exit_pass() # Signals completion to world_generation.gd [cite: 1]
