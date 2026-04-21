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
	push_message("(1/4) Clearing space")
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
	push_message("(2/4) Setting base lava height")
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
	
	push_message("(3/4) Creating Islands")
	for x in range(0, world_size.x):
		if gen.rng.randi_range(0, 12) == 0:
			var y := world_size.y - 65;
			
			# snap to topmost empty tile
			while (TileManager.get_liquid_level(x, y) > 0 or TileManager.get_block_unsafe(x, y) > 0) and \
				y > world_size.y - 140:
				y -= 1
			
			# create small islands moving down
			var size := gen.rng.randi_range(5, 30)
			var steps := 1000
			
			TileRunner.new(size, steps, x, y - gen.rng.randi_range(2, 5), 16)\
				.set_direction(0.0, 1.0).set_direction_change(1.0, 0.0)\
				.set_replace_mode(TileRunner.ReplaceMode.BOTH).start(gen)
			
			var size_mod = gen.rng.randf_range(1.0, 3.0);
			if gen.rng.randi_range(0, 3) == 0:
				size_mod *= 0.5
			
			# streaks of basalt
			if gen.rng.randi_range(0, 1) == 0:
				TileRunner.new(
					floori(gen.rng.randf_range(5.0, 15.0) * size_mod),
					floori(gen.rng.randf_range(10.0, 15.0) * size_mod),
					x, y - gen.rng.randi_range(2, 5), 16
				).set_direction(1.0, 0.3).set_replace_mode(TileRunner.ReplaceMode.BOTH).start(gen)
			if gen.rng.randi_range(0, 1) == 0:
				TileRunner.new(
					floori(gen.rng.randf_range(5.0, 15.0) * size_mod),
					floori(gen.rng.randf_range(10.0, 15.0) * size_mod),
					x, y - gen.rng.randi_range(2, 5), 16
				).set_direction(1.0, 0.3).set_replace_mode(TileRunner.ReplaceMode.BOTH).start(gen)
			
			# streaks of lava
			TileRunner.new(
				gen.rng.randi_range(5, 15),
				gen.rng.randi_range(10, 15),
				x + gen.rng.randi_range(-10, 10),
				y + gen.rng.randi_range(-10, 10),
				2
			).set_replace_layer(TileRunner.ReplaceLayer.LIQUID).set_direction(1.0, 0.3)\
				.set_replace_mode(TileRunner.ReplaceMode.BOTH).start(gen)
			
			if gen.rng.randi_range(0, 2) == 0:
				TileRunner.new(
					gen.rng.randi_range(10, 30),
					gen.rng.randi_range(10, 20),
					x + gen.rng.randi_range(-10, 10),
					y + gen.rng.randi_range(-10, 10),
					2
				).set_replace_layer(TileRunner.ReplaceLayer.LIQUID)\
					.set_direction(randf_range(-1.0, 3.0), randf_range(-1.0, 3.0))\
						.set_replace_mode(TileRunner.ReplaceMode.BOTH).start(gen)
			if gen.rng.randi_range(0, 4) == 0:
				TileRunner.new(
					gen.rng.randi_range(15, 30),
					gen.rng.randi_range(5, 20),
					x + gen.rng.randi_range(-15, 15),
					y + gen.rng.randi_range(-15, 10),
					2
				).set_replace_layer(TileRunner.ReplaceLayer.LIQUID)\
					.set_direction(randf_range(-1.0, 3.0), randf_range(-1.0, 3.0))\
						.set_replace_mode(TileRunner.ReplaceMode.BOTH).start(gen)
		
	# random pockets of lava
	push_message("(4/4) Sprinkling some lava")
	for i in range(0, world_size.x):
		TileRunner.new(
			gen.rng.randi_range(2, 7),
			gen.rng.randi_range(2, 7),
			gen.rng.randi_range(20, world_size.x - 20),
			gen.rng.randi_range(world_size.y - 180, world_size.y - 10),
			2
		).set_replace_layer(TileRunner.ReplaceLayer.LIQUID)\
			.set_replace_mode(TileRunner.ReplaceMode.BOTH).start(gen)
