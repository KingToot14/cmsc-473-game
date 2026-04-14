class_name CavePass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Carving Caves"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	# dirt layer caves
	push_message("(1/6) Dirt Caves")

	for i in range(world_size.x * world_size.y * 0.00003):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.rng.randi_range(gen.underground_line, gen.cavern_line)
		
		# limit holes near center of world
		if x > world_size.x * 0.45 and x < world_size.x * 0.55 and y < gen.surface_low + 20:
			y += 20
		
		# limit holes near the edges of the world
		if x < 350 or x > world_size.x - 350:
			y += 80
		
		var size := gen.rng.randi_range(5, 15)
		var steps := gen.rng.randi_range(30, 200)
		
		if gen.rng.randf() < 0.15:
			TileRunner.new(size, steps, x, y, 0).set_replace_layer(TileRunner.ReplaceLayer.LIQUID).start(gen)
		else:
			TileRunner.new(size, steps, x, y, 0).start(gen)
	
	# rock layer caves
	push_message("(2/6) Rock Caves")
	
	for i in range(world_size.x * world_size.y * 0.00013):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.rng.randi_range(gen.cavern_line, world_size.y)
		
		var size := gen.rng.randi_range(6, 20)
		var steps := gen.rng.randi_range(50, 300)
		
		if gen.rng.randf() < 0.10:
			var liquid := WaterUpdater.LAVA_TYPE if (y > gen.lava_line) else WaterUpdater.WATER_TYPE
			TileRunner.new(size, steps, x, y, liquid)\
				.set_replace_layer(TileRunner.ReplaceLayer.LIQUID).start(gen)
		else:
			TileRunner.new(size, steps, x, y, 0).start(gen)
	
	# surface-level caves (small)
	push_message("(3/6) Surface-Level (Small)")
	
	for i in range(world_size.x * 0.002):
		var x := gen.rng.randi_range(320, world_size.x - 320)
		
		# limit holes near center of world
		while x > world_size.x * 0.45 and x < world_size.x * 0.55:
			x = gen.rng.randi_range(320, world_size.x - 320)
		
		var y := 0
		
		# snap to bottom of the world
		while TileManager.get_block_unsafe(x, y) == 0:
			y += 1
		
		var size := gen.rng.randi_range(3, 6)
		var steps := gen.rng.randi_range(5, 50)
		
		var dir := Vector2(gen.rng.randf_range(-1.0, 1.0), 1.0)
		
		TileRunner.new(size, steps, x, y, 0).set_direction(dir.x, dir.y).start(gen)
	
	# surface-level caves (medium)
	push_message("(4/6) Surface-Level (Medium)")
	
	for i in range(world_size.x * 0.0007):
		var x := gen.rng.randi_range(320, world_size.x - 320)
		
		# limit holes near center of world
		while x > world_size.x * 0.43 and x < world_size.x * 0.57:
			x = gen.rng.randi_range(320, world_size.x - 320)
		
		var y := 0
		
		# snap to bottom of the world
		while TileManager.get_block_unsafe(x, y) == 0:
			y += 1
		
		var size := gen.rng.randi_range(10, 15)
		var steps := gen.rng.randi_range(50, 130)
		
		var dir := Vector2(gen.rng.randf_range(-1.0, 1.0), 1.0)
		
		TileRunner.new(size, steps, x, y, 0).set_direction(dir.x, dir.y).start(gen)
	
	# surface-level caves (large)
	push_message("(5/6) Surface-Level (Large)")
	
	for i in range(world_size.x * 0.0003):
		var x := gen.rng.randi_range(320, world_size.x - 320)
		
		# limit holes near center of world
		while x > world_size.x * 0.40 and x < world_size.x * 0.60:
			x = gen.rng.randi_range(320, world_size.x - 320)
		
		var y := 0
		
		# snap to bottom of the world
		while TileManager.get_block_unsafe(x, y) == 0:
			y += 1
		
		TileRunner.new(
			gen.rng.randi_range(12, 25),
			gen.rng.randi_range(150, 500),
			x, y, 0) \
		.set_direction(gen.rng.randf_range(-1.0, 1.0), 4.0) \
		.start(gen)
		
		TileRunner.new(
			gen.rng.randi_range(8, 17),
			gen.rng.randi_range(60, 200),
			x, y, 0) \
		.set_direction(gen.rng.randf_range(-1.0, 1.0), 2.0) \
		.start(gen)
		
		TileRunner.new(
			gen.rng.randi_range(5, 13),
			gen.rng.randi_range(40, 170),
			x, y, 0) \
		.set_direction(gen.rng.randf_range(-1.0, 1.0), 2.0) \
		.start(gen)
	
	# surface-level caves (extra)
	push_message("(6/6) Just a few more")
	for i in range(world_size.x * 0.0004):
		var x := gen.rng.randi_range(320, world_size.x - 320)
		
		# limit holes near center of world
		while x > world_size.x * 0.40 and x < world_size.x * 0.60:
			x = gen.rng.randi_range(320, world_size.x - 320)
		
		var y := 0
		
		# snap to bottom of the world
		while TileManager.get_block_unsafe(x, y) == 0:
			y += 1
		
		var size := gen.rng.randi_range(7, 12)
		var steps := gen.rng.randi_range(150, 250)
		
		var dir := Vector2(gen.rng.randf_range(-1.0, 1.0), 1.0)
		
		TileRunner.new(size, steps, x, y, 0).set_direction(dir.x, dir.y).start(gen)
