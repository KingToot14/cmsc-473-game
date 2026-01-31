extends Node

# --- Variables --- #
const CHUNK_SIZE := 16
const TILE_SIZE := 8

var chunks: Array[PackedInt32Array]:
	set(_chunks):
		print_stack()
		chunks = _chunks
var chunk_map: Dictionary[int, PackedInt32Array] = {}
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
func _get_tile(world_x: int, world_y: int) -> int:
	var chunk := get_chunk_from_world(world_x, world_y)
	var x := world_x % CHUNK_SIZE
	var y := world_y % CHUNK_SIZE
	
	if chunk.is_empty():
		return 0
	
	return chunk[x + y * CHUNK_SIZE]

func get_wall(world_x: int, world_y: int) -> int:
	# check bounds
	if world_x < 0 or world_x >= Globals.world_size.x or world_y < 0 or world_y >= Globals.world_size.y:
		return 0
	
	var tile := _get_tile(world_x, world_y)
	
	# wall id is bit 10 - 19
	return (tile >> 10) & (2**10 - 1)

func get_block(world_x: int, world_y: int) -> int:
	# check bounds
	if world_x < 0 or world_x >= Globals.world_size.x or world_y < 0 or world_y >= Globals.world_size.y:
		return 0
	
	var tile := _get_tile(world_x, world_y)
	
	# block id is bit 0 - 9
	return (tile >> 0) & (2**10 - 1)

func get_wall_in_chunk(chunk: PackedInt32Array, x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE:
		return 0
	
	if len(chunk) < x + y * CHUNK_SIZE:
		return 0
	
	var tile := chunk[x + y * CHUNK_SIZE]
	
	# wall id is bit 10 - 19
	return (tile >> 10) & (2**10 - 1)

func get_block_in_chunk(chunk: PackedInt32Array, x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE:
		return 0
	
	if len(chunk) <= x + y * CHUNK_SIZE:
		return 0
	
	var tile := chunk[x + y * CHUNK_SIZE]
	
	# block id is bit 0 - 9
	return (tile >> 0) & (2**10 - 1)

func set_wall(world_x: int, world_y: int, wall_id: int) -> void:
	# check bounds
	if world_x < 0 or world_x >= Globals.world_size.x or world_y < 0 or world_y >= Globals.world_size.y:
		return
	
	var chunk := get_chunk_from_world(world_x, world_y)
	var x := world_x % CHUNK_SIZE
	var y := world_y % CHUNK_SIZE
	
	# clear wall id
	chunk[x + y * CHUNK_SIZE] &= ~((2**10 - 1) << 10)
	
	# set wall id
	chunk[x + y * CHUNK_SIZE] |= (wall_id << 10)

func set_block(world_x: int, world_y: int, block_id: int) -> void:
	# check bounds
	if world_x < 0 or world_x >= Globals.world_size.x or world_y < 0 or world_y >= Globals.world_size.y:
		return
	
	var chunk := get_chunk_from_world(world_x, world_y)
	var x := world_x % CHUNK_SIZE
	var y := world_y % CHUNK_SIZE
	
	# clear block id
	chunk[x + y * CHUNK_SIZE] &= ~((2**10 - 1) << 0)
	
	# set block id
	chunk[x + y * CHUNK_SIZE] |= (block_id << 0)

func set_wall_in_chunk(chunk: PackedInt32Array, x: int, y: int, wall_id: int) -> void:
	# check bounds
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE:
		return
	
	# clear wall id
	chunk[x + y * CHUNK_SIZE] &= ~((2**10 - 1) << 10)
	
	# set wall id
	chunk[x + y * CHUNK_SIZE] |= (wall_id << 10)

func set_block_in_chunk(chunk: PackedInt32Array, x: int, y: int, block_id: int) -> void:
	# check bounds
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE:
		return
	
	# clear block id
	chunk[x + y * CHUNK_SIZE] &= ~((2**10 - 1) << 0)
	
	# set block id
	chunk[x + y * CHUNK_SIZE] |= (block_id << 0)

#endregion

#region Chunk Access
@warning_ignore_start("integer_division")
func empty_chunk(chunk_x: int, chunk_y: int) -> void:
	var tiles := PackedInt32Array()
	
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			tiles.append(0)
	
	chunks[chunk_x + chunk_y * Globals.world_chunks.x] = tiles

func get_chunk(x: int, y: int) -> PackedInt32Array:
	if x < 0 or x >= Globals.world_chunks.x or y < 0 or y >= Globals.world_chunks.y:
		return PackedInt32Array()
	
	if multiplayer.is_server():
		return chunks[x + y * (Globals.world_chunks.x)]
	else:
		var chunk = chunk_map.get(x | y << 20, PackedInt32Array())
		return chunk

func get_chunk_from_world(world_x: int, world_y: int) -> PackedInt32Array:
	var chunk_x := floori(world_x / CHUNK_SIZE)
	var chunk_y := floori(world_y / CHUNK_SIZE)
	
	return get_chunk(chunk_x, chunk_y)

func get_visual_chunk(x: int, y: int) -> WorldChunk:
	return visual_chunks.get(x | y << 20)

func set_chunk(x: int, y: int, data: PackedInt32Array) -> void:
	if x < 0 or x >= Globals.world_chunks.x or y < 0 or y >= Globals.world_chunks.y:
		return
	
	if multiplayer.is_server():
		chunks[x + y * (Globals.world_chunks.x)] = data
	else:
		chunk_map[x | y << 20] = data

func set_chunk_from_world(world_x: int, world_y: int, data: PackedInt32Array) -> void:
	var chunk_x := floori(world_x / CHUNK_SIZE)
	var chunk_y := floori(world_y / CHUNK_SIZE)
	
	set_chunk(chunk_x, chunk_y, data)

func create_chunk_object(x: int, y: int) -> WorldChunk:
	var chunk := preload("uid://m5kcmqx3t3dm").instantiate() as WorldChunk
	chunk.name = "chunk_%s_%s" % [x, y]
	chunk.chunk_pos = Vector2i(x, y)
	chunk.position = Vector2(x * 8 * CHUNK_SIZE, y * 8 * CHUNK_SIZE)
	
	get_tree().current_scene.get_node(^'tiles').add_child(chunk)
	
	chunk.autotile_block_chunk()
	
	return chunk

func load_chunks() -> void:
	var width := roundi(Globals.world_chunks.x)
	var height := roundi(Globals.world_chunks.y)
	
	chunks = []
	chunks.resize(width * height)
	
	for x in range(width):
		for y in range(height):
			empty_chunk(x, y)

func load_chunk_region(
		new_chunks: Array[PackedInt32Array], start_x: int, start_y: int, width: int, height: int
	) -> void:
	
	if multiplayer.is_server():
		pass
	else:
		var index := 0
		var dirty: Array[WorldChunk] = []
		
		for x in range(max(0, start_x), min(Globals.world_chunks.x, start_x + width + 1)):
			for y in range(start_y, min(Globals.world_chunks.x, start_y + height + 1)):
				var chunk := new_chunks[index]
				var map_index = x | y << 20
				
				if map_index in chunk_map and map_index in visual_chunks:
					if chunk != chunk_map[map_index]:
						chunk_map[map_index] = chunk
						dirty.append(visual_chunks[map_index])
				else:
					chunk_map[map_index] = chunk
					visual_chunks[map_index] = create_chunk_object(x, y)
					dirty.append(visual_chunks[map_index])
				
				index += 1
		
		for chunk in dirty:
			chunk.autotile_block_chunk()
			
			if chunk.processing:
				await chunk.done_processing

@warning_ignore_restore("integer_division")

#endregion

#region Multiplayer
func pack_chunks(start_x: int, start_y: int, end_x: int, end_y: int) -> PackedByteArray:
	var packed = PackedByteArray()
	
	for x in range(start_x, end_x + 1):
		for y in range(start_y, end_y + 1):
			packed.append_array(get_chunk(x, y).to_byte_array())
	
	return packed.compress(FileAccess.COMPRESSION_ZSTD)

#endregion
