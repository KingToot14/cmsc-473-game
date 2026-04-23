class_name JungleShapePass
extends WorldGenPass

func get_pass_name() -> String:
	return "Sculpting Jungle Geography"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	var jungle_on_right: bool = gen.winter_on_right
	
	# --- Ocean Awareness ---
	# We use a value slightly larger than OceanPass.OCEAN_WIDTH 
	# to ensure a smooth transition and no mud overlaps.
	var ocean_width_buffer := 320 
	var zone_width := floori(world_size.x * 0.18)
	
	var start_x: int
	var end_x: int
	
	if jungle_on_right:
		# End before the right ocean starts
		start_x = (world_size.x - zone_width)
		end_x = world_size.x - ocean_width_buffer 
	else:
		# Start after the left ocean ends
		start_x = ocean_width_buffer
		end_x = zone_width

	# Setup Smooth Perlin Noise
	var j_noise = FastNoiseLite.new()
	j_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	j_noise.frequency = 0.012 # Very smooth rolling hills
	j_noise.seed = gen.get("seed") if "seed" in gen else randi()

	for x in range(start_x, end_x):
		# 1. Find the surface y
		var surface_y := 0
		for y in range(world_size.y):
			if TileManager.get_block_unsafe(x, y) != 0:
				surface_y = y
				break
		
		# 2. Linear Fade (Alpha Mask)
		# This prevents abrupt cliffs where the jungle starts/ends
		var dist_to_start = abs(x - start_x)
		var dist_to_end = abs(x - end_x)
		var edge_fade = clamp(min(dist_to_start, dist_to_end) / 50.0, 0.0, 1.0)
		
		var noise_val = j_noise.get_noise_1d(x) * edge_fade
		
		# 3. Sculpting
		if noise_val > 0.12: # Hills
			var hill_height = floori(noise_val * 22)
			for i in range(1, hill_height):
				var ty = surface_y - i
				if ty > 0:
					TileManager.set_block_unsafe(x, ty, 1) # Mud
					TileManager.set_wall_unsafe(x, ty, 11) # Jungle Wall
				
		elif noise_val < -0.15: # Lagoons
			var depth = floori(abs(noise_val) * 14)
			for i in range(depth):
				var ty = surface_y + i
				if ty < world_size.y:
					TileManager.set_block_unsafe(x, ty, 0) # Clear Mud
					if i > 5: # Fill deep pits with water
						TileManager.set_liquid_level(x, ty, 16)
						TileManager.set_liquid_type(x, ty, 0)

	push_message("Jungle Terrain Sculpted (Ocean Protected)")
	exit_pass()
