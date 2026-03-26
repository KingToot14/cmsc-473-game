class_name HillPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Rolling Up Hills"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	# create large hills
	for i in range(world_size.x * 0.001):
		# get random position
		var x := 0
		
		for j in range(world_size.x * 0.20):
			x = floori(world_size.x * randf_range(0.20, 0.80))
			
			if place_hill(gen, x):
				break

func place_hill(gen: WorldGeneration, hill_x: int) -> bool:
	var world_size := Globals.world_size
	var middle_low := floori(world_size.x * 0.45)
	var middle_high := floori(world_size.x * 0.55)
	
	# avoid center of the world
	if hill_x > middle_low and hill_x < middle_high:
		return false
	
	# avoid placing near other hills
	for hill in gen.hill_positions:
		if abs(hill.x - hill_x) < 90:
			return false
	
	# snap to surface
	var hill_y := 0
	
	while TileManager.get_block_unsafe(hill_x, hill_y) == 0:
		hill_y += 1
	
	# create hill
	gen.hill_positions.append(Vector2i(hill_x, hill_y))
	
	var radius := gen.rng.randi_range(80, 100)
	var offset := gen.rng.randi_range(40, 50)
	
	var pos := Vector2(hill_x, hill_y + offset / 2.0)
	
	var speed_x := gen.rng.randf_range(-1.0, 1.0)
	var speed_y := gen.rng.randf_range(-3.0, -1.5)
	
	while radius > 0 and offset > 0:
		var radius_mod := gen.rng.randf_range(0.80, 1.20)
		
		for y in range(-radius * 0.50, radius * 0.50):
			for x in range(-radius * 0.50, radius * 0.50):
				var dist := pos.distance_to(Vector2(hill_x + x, hill_y - y))
				
				if dist > radius * 0.40 * radius_mod * gen.rng.randf_range(0.95, 1.05):
					continue
				
				# set tile to dirt
				var curr_y := -y
				while TileManager.get_block_unsafe(hill_x + x, hill_y + curr_y) == 0:
					TileManager.set_block_unsafe(hill_x + x, hill_y + curr_y, 2)
					curr_y += 1
		
		# decrement radius
		radius -= gen.rng.randi_range(1, 4)
		offset -= 1
		
		# increment position
		pos.x += speed_x
		pos.y += speed_y
		
		# increment speed
		speed_x += gen.rng.randf_range(-0.5, 0.5)
		speed_y += gen.rng.randf_range(-0.5, 0.5)
		
		speed_x = clampf(speed_x, -0.5, 0.5)
		speed_y = clampf(speed_y, -3, -1.5)
	
	return true
