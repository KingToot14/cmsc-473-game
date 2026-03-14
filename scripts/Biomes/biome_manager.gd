extends Node
# The biome manager signals when it detects a biome change.
# --- Signals --- #
signal biome_changed(new_biome: StringName)

# --- Constants --- #
const WINTER_THRESHOLD := 250 # number of blocks to be in scanning radius before signaling
const SCAN_RADIUS := 3 # number of chunks to scan around the player

# --- Variables --- #
var current_biome: StringName = &"forest"

func check_biome(player_pos: Vector2) -> void:
	var center_tile = TileManager.world_to_tile(player_pos.x, player_pos.y) 
	var snow_ice_count := 0
	
	var scan_range = SCAN_RADIUS * TileManager.CHUNK_SIZE
	var start_x = clampi(center_tile.x - scan_range, 0, Globals.world_size.x)
	var start_y = clampi(center_tile.y - scan_range, 0, Globals.world_size.y)
	var end_x = clampi(center_tile.x + scan_range, 0, Globals.world_size.x)
	var end_y = clampi(center_tile.y + scan_range, 0, Globals.world_size.y)
	
	# loop through tiles in range
	# TODO: Optimize this loop
	# TODO: Add remaining biome checks
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			var block_id = TileManager.get_block_unsafe(x, y) 
			if block_id == 6 or block_id == 7: # Snow or Ice
				snow_ice_count += 1
				
			if snow_ice_count >= WINTER_THRESHOLD:
				set_biome(&"winter")
				return
			
	set_biome(&"forest") #default is forest

func set_biome(new_biome: StringName) -> void:
	if current_biome != new_biome:
		current_biome = new_biome
		biome_changed.emit(current_biome)
		print("[BiomeManager] Switched to: ", current_biome)
