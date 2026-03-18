extends Node
# The biome manager signals when it detects a biome change.
# --- Signals --- #
signal biome_changed(new_biome: StringName)
signal layer_changed(new_layer: StringName)

# --- Constants --- #
const WINTER_THRESHOLD := 250 # number of blocks to be in scanning radius before signaling
const SCAN_RADIUS := 3 # number of chunks to scan around the player

# --- Variables --- #
var current_biome: StringName = &"forest"
var current_layer: StringName = &'surface'

func check_biome(player_pos: Vector2) -> void:
	var center_tile = TileManager.world_to_tile(player_pos.x, player_pos.y) 
	print("tile y: ", center_tile.y, " | underground: ", Globals.underground, " | surface: ", Globals.surface, " | space: ", Globals.space)
	# check layer (lower y = higher elevation)
	if center_tile.y > Globals.underground:
		set_layer(&'cavern')
	elif center_tile.y > Globals.surface:
		set_layer(&'underground')
	elif center_tile.y > Globals.space:
		set_layer(&'surface')
	else:
		set_layer(&'space')
	
	# check biome
	var snow_ice_count := 0
	
	var scan_range = SCAN_RADIUS * TileManager.CHUNK_SIZE
	var start_x = clampi(center_tile.x - scan_range, 0, Globals.world_size.x)
	var start_y = clampi(center_tile.y - scan_range, 0, Globals.world_size.y)
	var end_x = clampi(center_tile.x + scan_range, 0, Globals.world_size.x)
	var end_y = clampi(center_tile.y + scan_range, 0, Globals.world_size.y)
	
	# loop through tiles in range
	var processed := 0
	
	# TODO: Add remaining biome checks
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			var block_id = TileManager.get_block_unsafe(x, y) 
			if block_id == 6 or block_id == 7: # Snow or Ice
				snow_ice_count += 1
				
			if snow_ice_count >= WINTER_THRESHOLD:
				set_biome(&"winter")
				return
			
			processed += 1
			
			if processed == 256:
				await get_tree().process_frame
			
	set_biome(&"forest") #default is forest

func set_biome(new_biome: StringName) -> void:
	if current_biome != new_biome:
		current_biome = new_biome
		biome_changed.emit(current_biome)
		print("[BiomeManager] Switched to: ", current_biome)

func set_layer(new_layer: StringName) -> void:
	if current_layer != new_layer:
		current_layer = new_layer
		layer_changed.emit(current_layer)
		print("[BiomeManager] Switched to: ", current_layer)
