class_name StoneToIcePass
extends WorldGenPass

func get_pass_name() -> String:
	return "I'm chillier"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	var center_x := floori(world_size.x / 2)
	
	var min_dist := floori(world_size.x * 0.10)
	var edge_buffer := floori(world_size.x * 0.20)
	
	var start_x = (center_x + min_dist) if gen.winter_on_right else edge_buffer
	var end_x = (world_size.x - edge_buffer) if gen.winter_on_right else (center_x - min_dist)
	
	for x in range(start_x, end_x):
		for y in range(world_size.y):
			var block = TileManager.get_block_unsafe(x, y)
			# Replace Stone (3) with Ice (7) 
			if block == 3:
				TileManager.set_block_unsafe(x, y, 7)
	
	exit_pass()
