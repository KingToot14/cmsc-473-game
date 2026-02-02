class_name RocksInDirtPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Filling Dirt With Rocks"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	# create surface-level rocks
	for i in range(world_size.x * 0.015):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.surface_high
		
		# place slightly below ground
		while TileManager.get_block_unsafe(x, y - 1) == 0:
			y += 1
		
		var size := gen.rng.randi_range(6, 10)
		var steps := gen.rng.randi_range(5, 20)
		
		TileRunner.new(size, steps, x, y, 3).set_replace_mode(TileRunner.ReplaceMode.BOTH).start(gen)
	
	# create small rocks
	for i in range(world_size.x * 0.45):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.rng.randi_range(gen.surface_high, gen.surface_low)
		
		# must be at least 10 blocks below surface
		if TileManager.get_block_unsafe(x, y - 10) == 0:
			continue
		
		var size := gen.rng.randi_range(4, 10)
		var steps := gen.rng.randi_range(5, 30)
		
		TileRunner.new(size, steps, x, y, 3).start(gen)
	
	# create tiny rocks
	for i in range(world_size.x * 10):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.rng.randi_range(gen.surface_low, gen.underground_low)
		var size := gen.rng.randi_range(2, 7)
		var steps := gen.rng.randi_range(2, 23)
		
		TileRunner.new(size, steps, x, y, 3).start(gen)
