class_name ClayPatchPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Clumping Clay"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	# create tiny patches of clay
	push_message("(1/3) Small Patches")

	for i in range(world_size.x * world_size.y * 0.00002):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.rng.randi_range(gen.surface_low, world_size.y)
		
		# limit holes near center of world
		if x > world_size.x * 0.45 and x < world_size.x * 0.55 and y < gen.surface_low + 20:
			y += 20
		
		var size := gen.rng.randi_range(4, 14)
		var steps := gen.rng.randi_range(10, 50)
		
		TileRunner.new(size, steps, x, y, 9).start(gen)
	
	# create tiny patches of clay
	push_message("(2/3) Thin Patches")

	for i in range(world_size.x * world_size.y * 0.00005):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.rng.randi_range(gen.surface_low, world_size.y)
		
		# limit holes near center of world
		if x > world_size.x * 0.45 and x < world_size.x * 0.55 and y < gen.surface_low + 20:
			y += 20
		
		var size := gen.rng.randi_range(8, 15)
		var steps := gen.rng.randi_range(15, 40)
		
		TileRunner.new(size, steps, x, y, 9).start(gen)
	
	# create medium patches of clay
	push_message("(3/3) Small Patches")
	
	for i in range(world_size.x * world_size.y * 0.00002):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.rng.randi_range(gen.surface_low, world_size.y)
		
		# limit holes near center of world
		if x > world_size.x * 0.45 and x < world_size.x * 0.55 and y < gen.surface_low + 20:
			y += 20
		
		var size := gen.rng.randi_range(8, 15)
		var steps := gen.rng.randi_range(5, 30)
		
		TileRunner.new(size, steps, x, y, 9).start(gen)
