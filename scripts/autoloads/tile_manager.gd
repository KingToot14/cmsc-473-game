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
#func _get_tile(world_x: int, world_y: int) -> int:
	#var chunk := get_chunk_from_world(world_x, world_y)
	#var x := world_x % CHUNK_SIZE
	#var y := world_y % CHUNK_SIZE
	#
	#if chunk.is_empty():
		#return 0
	#
	#return chunk[x + y * CHUNK_SIZE]

func get_wall(x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= Globals.world_size.x or y < 0 or y >= Globals.world_size.y:
		return 0
	
	# get wall id (10 to 19)
	return (tiles[x + y * Globals.world_size.x] >> 10) & MASK_WALL
	
	## check bounds
	#if world_x < 0 or world_x >= Globals.world_size.x or world_y < 0 or world_y >= Globals.world_size.y:
		#return 0
	#
	#var tile := _get_tile(world_x, world_y)
	#
	## wall id is bit 10 - 19
	#return (tile >> 10) & (2**10 - 1)

func get_block(x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= Globals.world_size.x or y < 0 or y >= Globals.world_size.y:
		return 0
	
	# get block id (0 to 9)
	return (tiles[x + y * Globals.world_size.x] >> 0) & MASK_BLOCK
	
	# check bounds
	#if world_x < 0 or world_x >= Globals.world_size.x or world_y < 0 or world_y >= Globals.world_size.y:
		#return 0
	#
	#var tile := _get_tile(world_x, world_y)
	#
	## block id is bit 0 - 9
	#return (tile >> 0) & (2**10 - 1)

#func get_wall_in_chunk(chunk: PackedInt32Array, x: int, y: int) -> int:
	## check bounds
	#if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE:
		#return 0
	#
	#if len(chunk) < x + y * CHUNK_SIZE:
		#return 0
	#
	#var tile := chunk[x + y * CHUNK_SIZE]
	#
	## wall id is bit 10 - 19
	#return (tile >> 10) & (2**10 - 1)
#
#func get_block_in_chunk(chunk: PackedInt32Array, x: int, y: int) -> int:
	## check bounds
	#if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE:
		#return 0
	#
	#if len(chunk) <= x + y * CHUNK_SIZE:
		#return 0
	#
	#var tile := chunk[x + y * CHUNK_SIZE]
	#
	## block id is bit 0 - 9
	#return (tile >> 0) & (2**10 - 1)

func set_wall(x: int, y: int, wall_id: int) -> void:
	# check bounds
	if x < 0 or x >= Globals.world_size.x or y < 0 or y >= Globals.world_size.y:
		return
	
	# clear tile id
	tiles[x + y * Globals.world_size.x] &= ~MASK_WALL
	tiles[x + y * Globals.world_size.x] |= (wall_id << 10)
	
	# check bounds
	#if world_x < 0 or world_x >= Globals.world_size.x or world_y < 0 or world_y >= Globals.world_size.y:
		#return
	#
	#var chunk := get_chunk_from_world(world_x, world_y)
	#var x := world_x % CHUNK_SIZE
	#var y := world_y % CHUNK_SIZE
	#
	## clear wall id
	#chunk[x + y * CHUNK_SIZE] &= ~((2**10 - 1) << 10)
	#
	## set wall id
	#chunk[x + y * CHUNK_SIZE] |= (wall_id << 10)

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
	
	#var chunk := get_chunk_from_world(world_x, world_y)
	#var x := world_x % CHUNK_SIZE
	#var y := world_y % CHUNK_SIZE
	#
	## clear block id
	#chunk[x + y * CHUNK_SIZE] &= ~((2**10 - 1) << 0)
	#
	## set block id
	#chunk[x + y * CHUNK_SIZE] |= (block_id << 0)

#func set_wall_in_chunk(chunk: PackedInt32Array, x: int, y: int, wall_id: int) -> void:
	## check bounds
	#if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE:
		#return
	#
	## clear wall id
	#chunk[x + y * CHUNK_SIZE] &= ~((2**10 - 1) << 10)
	#
	## set wall id
	#chunk[x + y * CHUNK_SIZE] |= (wall_id << 10)
#
#func set_block_in_chunk(chunk: PackedInt32Array, x: int, y: int, block_id: int) -> void:
	## check bounds
	#if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE:
		#return
	#
	## clear block id
	#chunk[x + y * CHUNK_SIZE] &= ~((2**10 - 1) << 0)
	#
	## set block id
	#chunk[x + y * CHUNK_SIZE] |= (block_id << 0)

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
	#var width := roundi(Globals.world_chunks.x)
	#var height := roundi(Globals.world_chunks.y)
	
	tiles = []
	tiles.resize(Globals.world_size.x * Globals.world_size.y)
	
	#for x in range(width):
		#for y in range(height):
			#empty_chunk(x, y)

#func load_chunk_region(
		#new_chunks: Array[PackedInt32Array], start_x: int, start_y: int, width: int, height: int
	#) -> void:
	#
	#if multiplayer.is_server():
		#pass
	#else:
		#var index := 0
		#var dirty: Array[WorldChunk] = []
		#
		#for x in range(max(0, start_x), min(Globals.world_chunks.x, start_x + width + 1)):
			#for y in range(start_y, min(Globals.world_chunks.x, start_y + height + 1)):
				#var chunk := new_chunks[index]
				#var map_index = x | y << 20
				#
				#if map_index in chunk_map and map_index in visual_chunks:
					#if chunk != chunk_map[map_index]:
						#chunk_map[map_index] = chunk
						#dirty.append(visual_chunks[map_index])
				#else:
					#chunk_map[map_index] = chunk
					#visual_chunks[map_index] = create_chunk_object(x, y)
					#dirty.append(visual_chunks[map_index])
				#
				#index += 1
		#
		#for chunk in dirty:
			#chunk.autotile_block_chunk()
			#
			#if chunk.processing:
				#await chunk.done_processing

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

#func pack_chunks(start_x: int, start_y: int, end_x: int, end_y: int) -> PackedByteArray:
	#var packed = PackedByteArray()
	#
	#for x in range(start_x, end_x + 1):
		#for y in range(start_y, end_y + 1):
			#packed.append_array(get_chunk(x, y).to_byte_array())
	#
	#return packed.compress(FileAccess.COMPRESSION_ZSTD)

#endregion
