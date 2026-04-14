class_name UnderworldPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Cooking Up the Underworld"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	var depth := world_size.y - gen.rng.randi_range(150, 190)
	
	# clear out initial area
	for x in range(world_size.x):
		depth += gen.rng.randi_range(-3, 3);
		
		# check bounds
		if depth < world_size.y - 190:
			depth = world_size.y - 190
		if depth > world_size.y - 160:
			depth = world_size.y - 160
		
		# clear out area with a band of basalt
		for y in range(depth - 20 - gen.rng.randi_range(0, 3), world_size.y):
			if y >= depth:
				TileManager.set_block_unsafe(x, y, 0)
				TileManager.set_liquid_level(x, y, 0)
				TileManager.set_liquid_type(x, y, 0)
			elif TileManager.get_block_unsafe(x, y) != 0:
				TileManager.set_block_unsafe(x, y, 16)
	
	# set lava height
	depth = world_size.y - gen.rng.randi_range(40, 70)
	
	for x in range(world_size.x):
		depth += gen.rng.randi_range(-10, 10)
		
		if depth < world_size.y - 60:
			depth = world_size.y - 60
		if depth > world_size.y - 120:
			depth = world_size.y - 120
		
		for y in range(depth, world_size.y):
			if TileManager.get_block_unsafe(x, y) == 0:
				TileManager.set_liquid_level(x, y, WaterUpdater.MAX_WATER_LEVEL)
				TileManager.set_liquid_type(x, y, WaterUpdater.LAVA_TYPE)
