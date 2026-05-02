class_name OceanPass
extends WorldGenPass

# --- Variables --- #
const OCEAN_DEPTH := 80
const OCEAN_WIDTH := 300

const WATER_DEPTH := 60
const WATER_WIDTH := 23

var ocean_start := 0

# --- Functions --- #
func get_pass_name() -> String:
	return "Blub Blub"

func perform_pass(_gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	# find left ocean start
	ocean_start = 0
	
	while TileManager.get_block_unsafe(0, ocean_start) == 0:
		ocean_start += 1
	
	# create left ocean
	push_message("(1/2) Left Ocean")

	for x in range(0, OCEAN_WIDTH):
		for y in range(ocean_start, ocean_start + OCEAN_DEPTH):
			if is_water(x, y):
				TileManager.set_block_unsafe(x, y, 0)
				TileManager.set_wall_unsafe(x, y, 0)
				TileManager.set_liquid_level(x, y, WaterUpdater.MAX_WATER_LEVEL)
				TileManager.set_liquid_type(x, y, WaterUpdater.WATER_TYPE)
			elif is_sand(x, y):
				TileManager.set_block_unsafe(x, y, 8)
	
	# find right ocean start
	ocean_start = 0
	
	while TileManager.get_block_unsafe(world_size.x - 1, ocean_start) == 0:
		ocean_start += 1
	
	# create right ocean
	push_message("(2/2) Right Ocean")
	
	for x in range(0, OCEAN_WIDTH):
		for y in range(ocean_start, ocean_start + OCEAN_DEPTH):
			if is_water(x, y):
				TileManager.set_block_unsafe(world_size.x - x - 1, y, 0)
				TileManager.set_wall_unsafe(world_size.x - x - 1, y, 0)
				TileManager.set_liquid_level(world_size.x - x - 1, y, WaterUpdater.MAX_WATER_LEVEL)
				TileManager.set_liquid_type(world_size.x - x - 1, y, WaterUpdater.WATER_TYPE)
			elif is_sand(x, y):
				TileManager.set_block_unsafe(world_size.x - x - 1, y, 8)

func is_water(x: int, y: int) -> bool:
	y = OCEAN_DEPTH - (y - ocean_start)
	
	var water_func := floori(OCEAN_DEPTH - WATER_DEPTH + (float(x) / WATER_WIDTH) ** 2)
	
	return y > water_func

func is_sand(x: int, y: int) -> bool:
	y = OCEAN_DEPTH - (y - ocean_start)
	
	var sand_func := floori((OCEAN_DEPTH / 2.0) * (sin((PI * x) / OCEAN_WIDTH - PI / 2.0) + 1))
	
	return y > sand_func
