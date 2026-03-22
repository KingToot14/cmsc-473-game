class_name LakePass
extends WorldGenPass

# --- Variables --- #
const SCAN_DEPTH := 4

# --- Functions --- #
func get_pass_name() -> String:
	return "Scooping Lakes"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	var world_scale := world_size.x / 4200.0
	var lakes_to_generate := gen.rng.randi_range(floori(3 * world_scale), floori(6 * world_scale))
	
	for lake in range(lakes_to_generate):
		var attempts := floori(world_size.x * 0.20)
		var lake_width := gen.rng.randi_range(20, 30)
		var lake_depth := gen.rng.randi_range(10, 20)
		
		for attempt in range(attempts):
			if place_lake(gen, lake_width, lake_depth):
				break

func place_lake(gen: WorldGeneration, lake_width: int, lake_depth: int) -> bool:
	var world_size := Globals.world_size
	
	var lake_x := gen.rng.randi_range(400, world_size.x - 400)
	var lake_y := 0
	
	# don't place lakes near center
	while lake_x > world_size.x * 0.45 and lake_x < world_size.x * 0.55:
		lake_x = gen.rng.randi_range(400, world_size.x - 400)
	
	# don't place near other lakes
	for lake_pos in gen.lake_positions:
		if absi(lake_pos.x - lake_x) < 100:
			return false
	
	# snap to surface
	while TileManager.get_block_unsafe(lake_x, lake_y) == 0 and lake_y < world_size.y:
		lake_y += 1
	
	if lake_y >= world_size.y:
		return false
	
	# scan for flat areas
	var lake_valid := true
	
	for scan in range(SCAN_DEPTH):
		lake_valid = true
		
		for x in range(lake_x - lake_width, lake_x + lake_width):
			if TileManager.get_block_unsafe(x, lake_y + scan) == 0:
				lake_valid = false
				break
		
		if lake_valid:
			break
	
	if not lake_valid:
		return false
	
	# check for clear range
	for x in range(lake_x - lake_width, lake_x + lake_width):
		if TileManager.get_block_unsafe(x, lake_y - SCAN_DEPTH) != 0:
			return false
	
	# check for clear radius
	for x in range(lake_x - lake_width, lake_x + lake_width):
		for y in range(lake_y, lake_y + lake_depth):
			if TileManager.get_block_unsafe(x, y) == 0:
				return false
	
	# dig out lake
	for x in range(lake_x - lake_width, lake_x + lake_width):
		for y in range(lake_y + lake_depth + 1, lake_y - SCAN_DEPTH, -1):
			if y >= lake_y:
				var dist := (float(x - lake_x) / lake_width) ** 2 + \
					(float(y - lake_y) / lake_depth) ** 2
				
				if dist > randf_range(0.9, 1.1) and TileManager.get_block_unsafe(x, y + 1) != 0:
					continue
				
				TileManager.set_water_level(x, y, WaterUpdater.MAX_WATER_LEVEL)
			
			TileManager.set_block_unsafe(x, y, 0)
			TileManager.set_wall_unsafe(x, y, 0)
	
	# smooth out lake
	var index := 0
	
	for x in range(lake_x - lake_width - SCAN_DEPTH, lake_x + lake_width + SCAN_DEPTH):
		for y in range(lake_y - SCAN_DEPTH, lake_y):
			if abs(x - lake_x) > lake_width - index:
				continue
			
			TileManager.set_block_unsafe(x, y, 0)
			TileManager.set_wall_unsafe(x, y, 0)
			
			index += 1
	
	# save position for later
	gen.lake_positions.append(Vector2i(lake_x, lake_y))
	
	return true
