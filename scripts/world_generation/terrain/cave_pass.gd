class_name CavePass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Carving Caves"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	# dirt layer caves
	for i in range(world_size.x * world_size.y * 0.00003):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.rng.randi_range(gen.surface_low, gen.underground_low)
		
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
	for i in range(world_size.x * world_size.y * 0.00013):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.rng.randi_range(gen.underground_low, world_size.y)
		
		var size := gen.rng.randi_range(6, 20)
		var steps := gen.rng.randi_range(50, 300)
		
		if gen.rng.randf() < 0.10:
			TileRunner.new(size, steps, x, y, 0).set_replace_layer(TileRunner.ReplaceLayer.LIQUID).start(gen)
		else:
			TileRunner.new(size, steps, x, y, 0).start(gen)
