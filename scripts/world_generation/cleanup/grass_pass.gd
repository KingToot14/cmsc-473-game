class_name GrassPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Growing Grass"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	# create sliding window
	var prev := TileManager.get_block_row(0, 0, world_size.x)
	var curr := TileManager.get_block_row(0, 1, world_size.x)
	var next := TileManager.get_block_row(0, 2, world_size.x)
	
	for y in range(1, gen.surface_low + 1):
		for x in range(1, world_size.x - 1):
			# only run on dirt tiles
			if TileManager.get_block_unsafe(x, y) != 2:
				continue
			
			# set grass if there are non-solid tiles above
			if prev[x - 1] <= 0 or prev[x] <= 0 or prev[x + 1] <= 0 or curr[x - 1] <= 0 or \
			curr[x + 1] <= 0 or next[x - 1] <= 0 or next[x] <= 0 or next[x + 1] <= 0:
				TileManager.set_block_unsafe(x, y, 1)
		
		# update window
		prev = curr
		curr = next
		next = TileManager.get_block_row(0, y + 2, world_size.x)
