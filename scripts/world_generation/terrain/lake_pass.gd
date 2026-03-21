class_name LakePass
extends WorldGenPass

# --- Variables --- #
const SCAN_DEPTH := 4

# --- Functions --- #
func get_pass_name() -> String:
	return "Scooping Lakes"

func perform_pass(gen: WorldGeneration) -> void:
	# steps: randomly generate 3-6 lakes across the world (scaled by world scale)
	# select a random position away from beaches and away from center of the world
	# for each position, snap to surface and check width on each side for solid tiles
	# for each position, check a few blocks above the surface for air (6 blocks above)
	# check area under width down to depth to make sure all blocks are solid
	# add to list of lakes to prevent lakes being too close
	# dig out a parabolic shape in the ground, removing blocks walls and setting water levels
	
	var world_size := Globals.world_size
	var world_scale := world_size.x / 4200.0
	var lakes_to_generate := gen.rng.randi_range(floori(3 * world_scale), floori(6 * world_scale))
	
	for lake in range(lakes_to_generate):
		var attempts := floori(world_size.x * 0.20)
		var lake_width := gen.rng.randi_range(20, 30)
		var lake_depth := gen.rng.randi_range(10, 20)
		
		for attempt in range(attempts):
			var lake_x := gen.rng.randi_range(400, world_size.x - 400)
			var lake_y := 0
			var lake_valid := true
			
			# don't place lakes near center
			while lake_x > world_size.x * 0.45 and lake_x < world_size.x * 0.55:
				lake_x = gen.rng.randi_range(400, world_size.x - 400)
			
			# don't place near other lakes
			for lake_pos in gen.lake_positions:
				if absi(lake_pos.x - lake_x) < 100:
					lake_valid = false
					break
			
			if not lake_valid:
				continue
			
			# snap to surface
			while TileManager.get_block_unsafe(lake_x, lake_y) == 0 and lake_y < world_size.y:
				lake_y += 1
			
			if lake_y >= world_size.y:
				continue
			
			# scan for flat areas
			for scan in range(SCAN_DEPTH):
				lake_valid = true
				
				for x in range(lake_x - lake_width, lake_x + lake_width):
					if TileManager.get_block_unsafe(x, lake_y + scan) == 0:
						lake_valid = false
						break
				
				if lake_valid:
					break
			
			if not lake_valid:
				continue
			
			# check for clear range
			for x in range(lake_x - lake_width, lake_x + lake_width):
				if TileManager.get_block_unsafe(x, lake_y - SCAN_DEPTH) != 0:
					lake_valid = false
					break
			
			if not lake_valid:
				continue
			
			# check for clear radius
			for x in range(lake_x - lake_width, lake_x + lake_width):
				for y in range(lake_y, lake_y + lake_depth):
					if TileManager.get_block_unsafe(x, y) == 0:
						lake_valid = false
						break
			
			if not lake_valid:
				continue
			
			# dig out lake
			for x in range(lake_x - lake_width, lake_x + lake_width):
				for y in range(lake_y + lake_depth + 1, lake_y - SCAN_DEPTH, -1):
					if y >= lake_y:
						var dist := (float(x - lake_x) / lake_width) ** 2 + \
							(float(y - lake_y) / lake_depth) ** 2
						
						if dist > randf_range(0.9, 1.1) and TileManager.get_block_unsafe(x, y + 1) != 0:
							continue
					
					TileManager.set_block_unsafe(x, y, 0)
					TileManager.set_wall_unsafe(x, y, 0)
					
					if y > lake_y:
						TileManager.set_water_level(x, y, WaterUpdater.MAX_WATER_LEVEL)
			
			# save position for later
			gen.lake_positions.append(Vector2i(lake_x, lake_y))
			break
