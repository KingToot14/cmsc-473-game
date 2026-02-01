extends Node

# --- Variables --- #
const CHUNK_SIZE := 16
const TILE_SIZE := 8

const MASK_WALL  := ((2**10 - 1) << 10)
const MASK_BLOCK := ((2**10 - 1) << 0)

var tiles: PackedInt32Array
var visual_chunks: Dictionary[int, WorldChunk] = {}

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
func get_wall(x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= Globals.world_size.x or y < 0 or y >= Globals.world_size.y:
		return 0
	
	# get wall id (10 to 19)
	return (tiles[x + y * Globals.world_size.x] >> 10) & MASK_WALL

func get_block(x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= Globals.world_size.x or y < 0 or y >= Globals.world_size.y:
		return 0
	
	# get block id (0 to 9)
	return (tiles[x + y * Globals.world_size.x] >> 0) & MASK_BLOCK

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
	
	#start_x = max(0, start_x)
	#width = min(world_size.x, start_x + width) - start_x
	
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
@warning_ignore_start("integer_division")
#func _get_chunk_server(x: int, y: int) -> PackedInt32Array:
	#if x < 0 or x >= Globals.world_chunks.x or y < 0 or y >= Globals.world_chunks.y:
		#return PackedInt32Array()
	#
	#return chunks[x + y * (Globals.world_chunks.x)]
#
#func _get_chunk_client(x: int, y: int) -> PackedInt32Array:
	#var index := x | y << 20
	#
	#if index in chunk_map:
		#return chunk_map[index]
	#else:
		#return PackedInt32Array()
#
#func get_chunk(x: int, y: int) -> PackedInt32Array:
	#return _get_chunk.call(x, y)
#
#func get_chunk_from_world(world_x: int, world_y: int) -> PackedInt32Array:
	#var chunk_x := floori(world_x / CHUNK_SIZE)
	#var chunk_y := floori(world_y / CHUNK_SIZE)
	#
	#return get_chunk(chunk_x, chunk_y)

func get_visual_chunk(x: int, y: int) -> WorldChunk:
	return visual_chunks.get(x | y << 20)

#func set_chunk(x: int, y: int, data: PackedInt32Array) -> void:
	#if x < 0 or x >= Globals.world_chunks.x or y < 0 or y >= Globals.world_chunks.y:
		#return
	#
	#if multiplayer.is_server():
		#chunks[x + y * (Globals.world_chunks.x)] = data
	#else:
		#chunk_map[x | y << 20] = data
#
#func set_chunk_from_world(world_x: int, world_y: int, data: PackedInt32Array) -> void:
	#var chunk_x := floori(world_x / CHUNK_SIZE)
	#var chunk_y := floori(world_y / CHUNK_SIZE)
	#
	#set_chunk(chunk_x, chunk_y, data)

func create_chunk_object(x: int, y: int) -> WorldChunk:
	var chunk := preload("uid://m5kcmqx3t3dm").instantiate() as WorldChunk
	chunk.name = "chunk_%s_%s" % [x, y]
	chunk.chunk_pos = Vector2i(x, y)
	chunk.position = Vector2(x * 8 * CHUNK_SIZE, y * 8 * CHUNK_SIZE)
	
	get_tree().current_scene.get_node(^'tiles').add_child(chunk)
	
	chunk.autotile_block_chunk()
	
	return chunk

func load_chunks() -> void:
	tiles = []
	tiles.resize(Globals.world_size.x * Globals.world_size.y)

@warning_ignore_restore("integer_division")

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
	
	for y in range(height):
		for x in range(width):
			set_block_unsafe(start_x + x, start_y + y, data[x + y * width])
			processed += 1
			
			if processed >= 100:
				processed = 0
				await get_tree().process_frame
	
	Globals.world_map.load_region(start_x, start_y, width, height)

#endregion
