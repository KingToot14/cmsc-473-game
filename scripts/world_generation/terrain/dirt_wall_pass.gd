class_name DirtWallPass
extends WorldGenPass

# --- Variables --- #
const DIRT_WALL_ID := 1

const UNDERGROUND_OFFSET := 64
const UNDERGROUND_RANGE := 16

# --- Functions --- #
func get_pass_name() -> String:
	return "Backing Dirt"

func perform_pass(gen: WorldGeneration) -> void:
	var world_width := Globals.world_size.x
	var world_height := Globals.world_size.y
	var progress_step := Globals.world_size.x * 0.50

	var underground_depth := gen.underground_line + UNDERGROUND_OFFSET
	
	for x in range(world_width):
		if x % floori(progress_step) == 0:
			push_message("%.0f%% Complete" % (float(x) / world_width * 100.0))
		
		var placing := false
		
		for y in range(world_height):
			if y > underground_depth:
				break
			
			if placing:
				TileManager.set_wall_unsafe(x, y, DIRT_WALL_ID)
			else:
				# only start placing if there are no air tiles
				placing = not TileManager.has_block_neighbor(x, y, 0)
		
		# randomize underground position
		if gen.rng.randf() < 0.25:
			underground_depth += gen.rng.randi_range(-1, 1)
		
		underground_depth = clampi(
			underground_depth,
			gen.underground_line + UNDERGROUND_OFFSET - UNDERGROUND_RANGE,
			gen.underground_line + UNDERGROUND_OFFSET + UNDERGROUND_RANGE
		)
	
	push_message("100% complete")
