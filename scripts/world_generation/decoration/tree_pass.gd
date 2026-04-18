class_name TreePass
extends WorldGenPass

# --- Functions --- #
func get_pass_name() -> String:
	return "Sprouting Trees"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	# --- Added Desert Boundary Logic --- #
	var center_x := floori(world_size.x / 2.0)
	var min_dist := floori(world_size.x * 0.10)
	var edge_buffer := floori(world_size.x * 0.20)
	
	# Logic: Matches DirtToSandPass to identify where the Desert is
	var desert_start = edge_buffer if gen.winter_on_right else (center_x + min_dist)
	var desert_end = (center_x - min_dist) if gen.winter_on_right else (world_size.x - edge_buffer)
	# ------------------------------------ #
	
	var x := 160
	
	while x < world_size.x - 160:
		var y := 0
		
		while y < gen.underground_line and TileManager.get_block_unsafe(x, y + 1) == 0:
			y += 1
		
		# only place on blocks
		if TileManager.get_block_unsafe(x, y + 1) == 0:
			x += 1
			continue
		
		# attempt to place trees
		var tile_left := TileManager.get_block_unsafe(x, y + 1)
		var tile_right := TileManager.get_block_unsafe(x + 1, y + 1)
		
		if TileManager.get_block_unsafe(x + 1, y) != 0 or TileManager.get_block_unsafe(x + 1, y + 1) == 0:
			x += 1
			continue
		
		# make sure ground matches
		if tile_left != tile_right:
			x += 1
			continue
		
		# check water level
		if TileManager.get_liquid_level(x, y) > 0 or TileManager.get_liquid_level(x + 1, y) > 0:
			x += 1
			continue
		
		# check for walls
		if TileManager.get_wall_unsafe(x, y) != 0 or TileManager.get_wall_unsafe(x + 1, y) != 0:
			x += 1
			continue
		
		match tile_left:
			# dirt or grass
			1, 2:
				TreeEntity.create(Vector2i(x, y), TreeEntity.TreeVariant.FOREST)
			# snow
			6:
				TreeEntity.create(Vector2i(x, y), TreeEntity.TreeVariant.WINTER)
			# palm / sand logic
			8:
				var in_desert = x >= desert_start and x <= desert_end
				
				if not in_desert:
					# Standard Palm spawning for beaches
					TreeEntity.create(Vector2i(x, y), TreeEntity.TreeVariant.PALM)
				else:
					# --- Desert Oasis Logic --- #
					# We scan a small radius (e.g., 10 blocks) for water
					var found_water := false
					var scan_radius := 10
					
					for scan_x in range(x - scan_radius, x + scan_radius):
						# Stay within world bounds
						if scan_x < 0 or scan_x >= world_size.x: continue
						
						# Check a small vertical range around the surface to find water pockets
						for scan_y in range(y - 2, y + 5):
							if TileManager.get_liquid_level(scan_x, scan_y) > 0:
								found_water = true
								break
						if found_water: break
					
					if found_water:
						# Spawn a Palm tree only if water was found nearby (Oasis)
						TreeEntity.create(Vector2i(x, y), TreeEntity.TreeVariant.PALM)
					# -------------------------- #
		
		x += gen.rng.randi_range(4, 8)
	
	exit_pass()
