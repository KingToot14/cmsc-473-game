class_name DirtWallPass
extends WorldGenPass

# --- Variables --- #
const DIRT_WALL_ID := 1

# --- Functions --- #
func get_pass_name() -> String:
	return "Backing Dirt"

func perform_pass(_gen: WorldGeneration) -> void:
	var world_width := Globals.world_size.x
	var world_height := Globals.world_size.y
	
	for x in range(world_width):
		var placing := false
		
		for y in range(world_height):
			if placing:
				TileManager.set_wall_unsafe(x, y, DIRT_WALL_ID)
			else:
				placing = TileManager.get_block_unsafe(x, y) != 0
