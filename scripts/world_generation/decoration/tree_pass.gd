class_name TreePass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Sprouting Trees"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	var x := 160
	
	while x < world_size.x - 160:
		var y := 0
		
		while y < gen.underground_line and TileManager.get_block_unsafe(x, y + 1) == 0:
			y += 1
		
		# only place on blocks
		if TileManager.get_block_unsafe(x, y + 1) == 0:
			x += 1
			continue
		
		# attempt to place trees
		var tile_left := TileManager.get_block_unsafe(x, y + 1)
		var tile_right := TileManager.get_block_unsafe(x + 1, y + 1)
		
		if TileManager.get_block_unsafe(x + 1, y) != 0 or TileManager.get_block_unsafe(x + 1, y + 1) == 0:
			x += 1
			continue
		
		# make sure ground matches
		if tile_left != tile_right:
			x += 1
			continue
		
		# check water level
		if TileManager.get_liquid_level(x, y) > 0 or TileManager.get_liquid_level(x + 1, y) > 0:
			x += 1
			continue
		
		# check for walls
		if TileManager.get_wall_unsafe(x, y) != 0 or TileManager.get_wall_unsafe(x + 1, y) != 0:
			x += 1
			continue
		
		match tile_left:
			# dirt or grass
			1, 2:
				TreeEntity.create(Vector2i(x, y), TreeEntity.TreeVariant.FOREST)
			# snow
			6:
				TreeEntity.create(Vector2i(x, y), TreeEntity.TreeVariant.WINTER)
			# palm
			8:
				TreeEntity.create(Vector2i(x, y), TreeEntity.TreeVariant.PALM)
		
		x += gen.rng.randi_range(4, 8)
