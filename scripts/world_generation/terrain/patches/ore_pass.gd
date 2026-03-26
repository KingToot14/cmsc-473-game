class_name OrePass
extends WorldGenPass

# --- Variables --- #
const SLICE_OVERLAP := 0.50

const COPPER_ID := 10
const IRON_ID := 11
const SILVER_ID := 12
const GOLD_ID := 13

# --- Functions --- #
func get_pass_name() -> String:
	return "Ore-der Up"

func perform_pass(gen: WorldGeneration) -> void:
	var world_slice := floori((Globals.world_size.x - gen.underground_high) / 5.0)
	var start := gen.underground_high
	
	# 1: 0.00016 + 0.00008 + 0.00002 + 0.00000 = 0.00026
	
	# generate copper
	generate_ores(gen, COPPER_ID, gen.surface_high, gen.surface_low, 0.00002)
	generate_ores(gen, COPPER_ID, start + world_slice * 0, start + world_slice * 1, 0.00024)
	generate_ores(gen, COPPER_ID, start + world_slice * 1, start + world_slice * 2, 0.00016)
	generate_ores(gen, COPPER_ID, start + world_slice * 2, start + world_slice * 3, 0.00010)
	generate_ores(gen, COPPER_ID, start + world_slice * 3, start + world_slice * 4, 0.00000)
	
	# generate iron
	generate_ores(gen, COPPER_ID, gen.surface_high, gen.surface_low, 0.00002)
	generate_ores(gen, IRON_ID, start + world_slice * 0, start + world_slice * 1, 0.00010)
	generate_ores(gen, IRON_ID, start + world_slice * 1, start + world_slice * 2, 0.00024)
	generate_ores(gen, IRON_ID, start + world_slice * 2, start + world_slice * 3, 0.00010)
	generate_ores(gen, IRON_ID, start + world_slice * 3, start + world_slice * 4, 0.00006)
	
	# generate silver
	generate_ores(gen, SILVER_ID, start + world_slice * 0, start + world_slice * 1, 0.00006)
	generate_ores(gen, SILVER_ID, start + world_slice * 1, start + world_slice * 2, 0.00010)
	generate_ores(gen, SILVER_ID, start + world_slice * 2, start + world_slice * 3, 0.00024)
	generate_ores(gen, SILVER_ID, start + world_slice * 3, start + world_slice * 4, 0.00010)
	
	# generate gold
	generate_ores(gen, GOLD_ID, start + world_slice * 0, start + world_slice * 1, 0.00000)
	generate_ores(gen, GOLD_ID, start + world_slice * 1, start + world_slice * 2, 0.00010)
	generate_ores(gen, GOLD_ID, start + world_slice * 2, start + world_slice * 3, 0.00016)
	generate_ores(gen, GOLD_ID, start + world_slice * 3, start + world_slice * 4, 0.00024)

func generate_ores(
		gen: WorldGeneration, block_id: int, start_y: int, end_y: int, spawn_rate := 0.00002
	) -> void:
	
	var world_size := Globals.world_size
	
	# create tiny patches of sand
	for i in range(world_size.x * world_size.y * spawn_rate):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.rng.randi_range(start_y, end_y)
		
		var size := gen.rng.randi_range(3, 8)
		var steps := gen.rng.randi_range(4, 10)
		
		TileRunner.new(size, steps, x, y, block_id).start(gen)
	
	# create medium patches of sand
	for i in range(world_size.x * world_size.y * spawn_rate):
		var x := gen.rng.randi_range(0, world_size.x - 1)
		var y := gen.rng.randi_range(start_y, end_y)
		
		var size := gen.rng.randi_range(4, 10)
		var steps := gen.rng.randi_range(5, 12)
		
		TileRunner.new(size, steps, x, y, block_id).start(gen)
