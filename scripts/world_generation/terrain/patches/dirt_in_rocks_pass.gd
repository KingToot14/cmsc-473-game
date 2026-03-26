class_name DirtInRocksPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Filling Rocks with Dirt"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	# create tiny streaks of dirt
	for i in range(floori(world_size.x * world_size.y * 0.005)):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.rng.randi_range(gen.underground_high, world_size.y)
		var size := gen.rng.randi_range(2, 6)
		var steps := gen.rng.randi_range(2, 40)
		
		TileRunner.new(size, steps, x, y, 2).start(gen)
