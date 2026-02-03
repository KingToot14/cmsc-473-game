extends Node

# --- Variables --- #
const CHUNK_SIZE := 16
const TILE_SIZE := 8

const MASK_TEN := (1 << 10) - 1
const MASK_WALL  := ((1 << 10) - 1) << 10
const MASK_BLOCK := ((1 << 10) - 1) << 0

var tiles: PackedInt32Array
var world_width: int
var world_height: int

# --- Functions --- #
func _ready() -> void:
	Globals.world_size_changed.connect(_update_world_size)
	_update_world_size(Globals.world_size)

func _update_world_size(size: Vector2i) -> void:
	world_width = size.x
	world_height = size.y

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
	return (tiles[x + y * world_width] >> 10) & MASK_TEN

func get_wall(x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= world_width or y < 0 or y >= Globals.world_height:
		return 0
	
	# get wall id (10 to 19)
	return (tiles[x + y * world_width] >> 10) & MASK_TEN

func get_block_unsafe(x: int, y: int) -> int:
	# get block id (0 to 9)
	return (tiles[x + y * world_width] >> 0) & MASK_TEN

func get_block(x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return 0
	
	# get block id (0 to 9)
	return (tiles[x + y * world_width] >> 0) & MASK_TEN

func set_wall_unsafe(x: int, y: int, wall_id: int) -> void:
	# clear tile id
	var idx = x + y * world_width
	tiles[idx] &= ~MASK_WALL
	tiles[idx] |= (wall_id << 10)

func set_wall(x: int, y: int, wall_id: int) -> void:
	# check bounds
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return
	
	# clear tile id
	var idx = x + y * world_width
	tiles[idx] &= ~MASK_WALL
	tiles[idx] |= (wall_id << 10)

func set_block_unsafe(x: int, y: int, block_id: int) -> void:
	# clear tile id
	var idx = x + y * world_width
	tiles[idx] &= ~MASK_BLOCK
	tiles[idx] |= (block_id << 0)

func set_block(x: int, y: int, block_id: int) -> void:
	# check bounds
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return
	
	# clear tile id
	var idx = x + y * world_width
	tiles[idx] &= ~MASK_BLOCK
	tiles[idx] |= (block_id << 0)

func get_block_row(start_x: int, y: int, width: int, default := 1) -> PackedInt32Array:
	var world_w := world_width
	var world_h := world_height
	
	var row := PackedInt32Array()
	row.resize(width)
	
	# return default row if out of bounds
	if y < 0 or y >= world_h:
		row.fill(default)
		return row
	
	var base_index := y * world_w
	var mask := MASK_TEN
	
	var left := maxi(start_x, 0)
	var right := mini(start_x + width, world_w)
	
	# pad left
	for i in range(0, left - start_x):
		row[i] = default
	
	# fill center
	var index := left - start_x
	for i in range(base_index + left, base_index + right):
		row[index] = (tiles[i] >> 0) & mask
		index += 1
	
	# pad right
	for i in range(index, width):
		row[i] = default
	
	return row

#endregion

#region Chunk Access
func load_chunks() -> void:
	tiles = []
	tiles.resize(world_width * world_height)

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
		var x = start_x + (start_y + y) * world_width
		
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
			var idx = (start_x + x) + (start_y + y) * world_width
			
			# only update new blocks
			if new_block != (tiles[x + y * world_width] >> 0) & MASK_TEN:
				# update block
				tiles[idx] &= ~MASK_BLOCK
				tiles[idx] |= (new_block << 0)
				
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
