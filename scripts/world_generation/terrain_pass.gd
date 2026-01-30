class_name TerrainPass
extends WorldGenPass

# --- Variables --- #
const SURFACE_HEIGHT_HIGH := 0.17
const SURFACE_HEIGHT_TARGET := 0.23
const SURFACE_HEIGHT_LOW := 0.26 
const UNDERGROUND_OFFSET := 0.20

# --- Functions --- #
func perform_pass(_gen: WorldGeneration) -> void:
	var surface_depth := floori(TileManager.world_size.y * SURFACE_HEIGHT_TARGET)
	var underground_depth := floori(surface_depth + TileManager.world_size.y * UNDERGROUND_OFFSET)
	
	for x in range(TileManager.world_size.x):
		fill_column(x, surface_depth, underground_depth)

func fill_column(x: int, surface_depth: int, underground_depth: int) -> void:
	for y in range(TileManager.world_size.y):
		if y < surface_depth:
			TileManager.set_block(x, y, 0)
		elif y < underground_depth:
			TileManager.set_block(x, y, 2)
		else:
			TileManager.set_block(x, y, 3)
