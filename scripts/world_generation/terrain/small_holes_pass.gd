class_name SmallHolesPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Poking Small Holes"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	# create tiny rocks
	push_message("(1/2) Tiny Rocks")

	for i in range(world_size.x * world_size.y * 0.0015):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.rng.randi_range(gen.surface_low, world_size.y)
		
		# limit holes near center of world
		if x > world_size.x * 0.45 and x < world_size.x * 0.55 and y < gen.surface_low + 20:
			y += 20
		
		# limit holes near the edges of the world
		if x < 350 or x > world_size.x - 350:
			y += 80
		
		var size := gen.rng.randi_range(2, 5)
		var steps := gen.rng.randi_range(2, 20)
		
		TileRunner.new(size, steps, x, y, 0).start(gen)
	
	# create small rocks
	push_message("(2/2) Small Rocks")
	
	for i in range(world_size.x * world_size.y * 0.0015):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.rng.randi_range(gen.surface_low, world_size.y)
		
		# limit holes near center of world
		if x > world_size.x * 0.45 and x < world_size.x * 0.55 and y < gen.surface_low + 20:
			y += 20
		
		# limit holes near the edges of the world
		if x < 350 or x > world_size.x - 350:
			y += 80
		
		var size := gen.rng.randi_range(8, 15)
		var steps := gen.rng.randi_range(7, 30)
		
		TileRunner.new(size, steps, x, y, 0).start(gen)
