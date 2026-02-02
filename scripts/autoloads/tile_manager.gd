extends Node

# --- Variables --- #
const CHUNK_SIZE := 16
const TILE_SIZE := 8

const MASK_TEN := (20**10 - 1)
const MASK_WALL  := ((2**10 - 1) << 10)
const MASK_BLOCK := ((2**10 - 1) << 0)

var tiles: PackedInt32Array

# --- Functions --- #
#region Positions
func chunk_to_world(chunk_x: int, chunk_y: int, x: int, y: int) -> Vector2i:
	return Vector2i(chunk_x * CHUNK_SIZE + x, chunk_y * CHUNK_SIZE + y)

func world_to_chunk(world_x: int, world_y: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(
		clampi(world_x / CHUNK_SIZE, 0, Globals.world_chunks.x),
		clampi(world_y / CHUNK_SIZE, 0, Globals.world_chunks.y)
	)

#endregion

#region Tile Access
func get_wall_unsafe(x: int, y: int) -> int:
	# get wall id (10 to 19)
	return (tiles[x + y * Globals.world_size.x] >> 10) & MASK_TEN

func get_wall(x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= Globals.world_size.x or y < 0 or y >= Globals.world_size.y:
		return 0
	
	# get wall id (10 to 19)
	return (tiles[x + y * Globals.world_size.x] >> 10) & MASK_TEN

func get_block_unsafe(x: int, y: int) -> int:
	# get block id (0 to 9)
	return (tiles[x + y * Globals.world_size.x] >> 0) & MASK_TEN

func get_block(x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= Globals.world_size.x or y < 0 or y >= Globals.world_size.y:
		return 0
	
	# get block id (0 to 9)
	return (tiles[x + y * Globals.world_size.x] >> 0) & MASK_TEN

func set_wall_unsafe(x: int, y: int, wall_id: int) -> void:
	# clear tile id
	tiles[x + y * Globals.world_size.x] &= ~MASK_WALL
	tiles[x + y * Globals.world_size.x] |= (wall_id << 10)

func set_wall(x: int, y: int, wall_id: int) -> void:
	# check bounds
	if x < 0 or x >= Globals.world_size.x or y < 0 or y >= Globals.world_size.y:
		return
	
	# clear tile id
	tiles[x + y * Globals.world_size.x] &= ~MASK_WALL
	tiles[x + y * Globals.world_size.x] |= (wall_id << 10)

func set_block_unsafe(x: int, y: int, block_id: int) -> void:
	# clear tile id
	tiles[x + y * Globals.world_size.x] &= ~MASK_BLOCK
	tiles[x + y * Globals.world_size.x] |= (block_id << 0)

func set_block(x: int, y: int, block_id: int) -> void:
	# check bounds
	if x < 0 or x >= Globals.world_size.x or y < 0 or y >= Globals.world_size.y:
		return
	
	# clear tile id
	tiles[x + y * Globals.world_size.x] &= ~MASK_BLOCK
	tiles[x + y * Globals.world_size.x] |= (block_id << 0)

func get_row(start_x: int, y: int, width: int, default := 1) -> PackedInt32Array:
	var world_size = Globals.world_size
	var underflow := 0
	var overflow := 0
	
	if start_x < 0:
		underflow = -start_x
		start_x = 0
	
	if start_x + width > world_size.x:
		overflow = (start_x + width) - world_size.x
		start_x = world_size.x - width
	
	var row := tiles.slice(start_x + y * world_size.x, (start_x + width) + y * world_size.x)
	
	for x in range(underflow):
		row[x] = default
	for x in range(overflow):
		row[-(x + 1)] = default
	
	return row

#endregion

#region Chunk Access
func load_chunks() -> void:
	tiles = []
	tiles.resize(Globals.world_size.x * Globals.world_size.y)

#endregion

#region Multiplayer
func pack_chunks(start_x: int, start_y: int, width: int, height: int) -> PackedByteArray:
	return pack_region(
		start_x * TileManager.CHUNK_SIZE,
		start_y * TileManager.CHUNK_SIZE,
		width   * TileManager.CHUNK_SIZE,
		height  * TileManager.CHUNK_SIZE
	)

func pack_region(start_x: int, start_y: int, width: int, height: int) -> PackedByteArray:
	var packed = PackedByteArray()
	#var offset := 0
	
	for y in range(height):
		var x = start_x + (start_y + y) * Globals.world_size.x
		
		packed.append_array(tiles.slice(x, x + width).to_byte_array())
	
	return packed.compress(FileAccess.COMPRESSION_ZSTD)

func load_region(data: PackedInt32Array, start_x: int, start_y: int, width: int, height: int) -> void:
	var processed := 0
	var dirty_y := start_y + height
	var dirty_x := start_x + width
	var dirty_height := 0
	var dirty_width := 0
	
	for y in range(height):
		for x in range(width):
			var new_block = data[x + y * width]
			
			if new_block != get_block_unsafe(start_x + x, start_y + y):
				set_block_unsafe(start_x + x, start_y + y, new_block)
				
				# shrink update region
				dirty_x = min(dirty_x, start_x + x)
				dirty_y = min(dirty_y, start_y + y)
				dirty_width = max(dirty_width, start_x + x - dirty_x + 1)
				dirty_height = start_y + y - dirty_y + 1
				
				processed += 1
			
			if processed >= 128:
				processed = 0
				await get_tree().process_frame
	
	# only change updated tiles
	if dirty_width == 0 or dirty_height == 0:
		return
	
	Globals.world_map.load_region(dirty_x, dirty_y, dirty_width, dirty_height)

#endregion
