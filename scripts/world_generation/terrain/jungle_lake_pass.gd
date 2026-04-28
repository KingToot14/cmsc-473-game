class_name JungleLakePass
extends WorldGenPass

const SCAN_DEPTH := 4

func get_name() -> String:
	return "Flooding Jungle Lagoons"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	var jungle_on_right := gen.jungle_on_right
	
	# --- Define Jungle Boundaries (Consistent with your ShapePass) ---
	var ocean_width_buffer := 320 
	var zone_width := floori(world_size.x * 0.18)
	var start_x = (world_size.x - zone_width) if jungle_on_right else ocean_width_buffer
	var end_x = (world_size.x - ocean_width_buffer) if jungle_on_right else zone_width
	
	# Increase density for a "watery" feel: 8-12 lakes just in the jungle zone
	var lakes_to_generate := gen.rng.randi_range(6, 8)
	
	for lake in range(lakes_to_generate):
		push_message("(%d/%d) Creating Jungle Lagoon" % [lake + 1, lakes_to_generate])
		
		# Wider, shallower lagoons feel more like a flooded jungle
		var lake_width := gen.rng.randi_range(20, 40)
		var lake_depth := gen.rng.randi_range(6, 12)
		
		# Try many times to find a spot within the jungle bounds
		for attempt in range(100):
			if place_jungle_lake(gen, start_x, end_x, lake_width, lake_depth):
				break

func place_jungle_lake(gen: WorldGeneration, start_x: int, end_x: int, lake_width: int, lake_depth: int) -> bool:
	var world_size := Globals.world_size
	
	var lake_x := gen.rng.randi_range(start_x + lake_width, end_x - lake_width)
	var lake_y := 0
	
	# don't place lakes near center
	while lake_x > world_size.x * 0.45 and lake_x < world_size.x * 0.55:
		lake_x = gen.rng.randi_range(400, world_size.x - 400)
	
	# don't place near other lakes
	for lake_pos in gen.lake_positions:
		if absi(lake_pos.x - lake_x) < 20:
			return false
	
	# snap to surface
	while TileManager.get_block_unsafe(lake_x, lake_y) == 0 and lake_y < world_size.y:
		lake_y += 1
	
	if lake_y >= world_size.y:
		return false
	
	# dig out lake
	for x in range(lake_x - lake_width, lake_x + lake_width):
		for y in range(lake_y + lake_depth + 1, lake_y - SCAN_DEPTH, -1):
			var func_x := x - lake_x
			var func_y := lake_y - y
			
			var water_func := floori(((lake_depth + SCAN_DEPTH) / 2.0) * \
				(sin(((PI * func_x) / lake_width) - PI / 2.0) - 1)) + SCAN_DEPTH
			
			if func_y < water_func * gen.rng.randf_range(0.9, 1.1) and \
				TileManager.get_block_unsafe(x, y + 1) != 0:
				continue
			
			if func_y >= water_func:
				TileManager.set_block_unsafe(x, y, 0)
				TileManager.set_wall_unsafe(x, y, 0)
				
				if func_y < 0:
					TileManager.set_liquid_level(x, y, WaterUpdater.MAX_WATER_LEVEL)
					TileManager.set_liquid_type(x, y, WaterUpdater.WATER_TYPE)

	# save position for later
	gen.lake_positions.append(Vector2i(lake_x, lake_y))
	
	return true
