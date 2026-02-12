class_name TreePass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Sprouting Trees"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	var x := 300
	
	while x < world_size.x - 300:
		var y := 0
		
		while y < gen.underground_high and TileManager.get_block_unsafe(x, y + 1) != 2:
			y += 1
		
		# only place on blocks
		if TileManager.get_block_unsafe(x, y + 1) != 2:
			x += 1
			continue
		
		# attempt to place trees
		if TileManager.get_block_unsafe(x + 1, y) != 0 or TileManager.get_block_unsafe(x + 1, y + 1) != 2:
			x += 1
			continue
		
		EntityManager.create_tile_entity(0, Vector2i(x, y), {
			&'branch_seed': gen.rng.randi()
		})
		
		x += gen.rng.randi_range(4, 8)
