extends Node

# --- Variables --- #
const CHUNK_SIZE := 16
const TILE_SIZE := 8

var chunks: Array[PackedInt32Array]
var chunk_map: Dictionary[Vector2i, PackedInt32Array] = {}
var visual_chunks: Dictionary[Vector2i, WorldChunk] = {}

# --- Functions --- #
#region Positions
func chunk_to_world(chunk_x: int, chunk_y: int, x: int, y: int) -> Vector2i:
	return Vector2i(chunk_x * CHUNK_SIZE + x, chunk_y * CHUNK_SIZE + y)

func world_to_chunk(world_x: int, world_y: int) -> Vector2i:
	return Vector2i(world_x % CHUNK_SIZE, world_y % CHUNK_SIZE)

func load_chunks() -> void:
	chunks = []
	
	@warning_ignore_start("integer_division")
	for x in range(roundi(Globals.world_size.x / CHUNK_SIZE)):
		for y in range(roundi(Globals.world_size.y / CHUNK_SIZE)):
			add_chunk()
	@warning_ignore_restore("integer_division")
	
	#var sub_chunks = chunks.slice(0, 60, 1, true)
	#var packed = PackedByteArray()
	#
	#var start = Time.get_ticks_usec()
	#
	#for chunk in sub_chunks:
		#for x in range(CHUNK_SIZE):
			#for y in range(CHUNK_SIZE):
				#chunk[x + y * CHUNK_SIZE] |= (randi_range(0, 256) << 0)
				#chunk[x + y * CHUNK_SIZE] |= (randi_range(0, 256) << 10)
		#
		#packed.append_array(chunk.to_byte_array())
	#
	#print(packed.size())
	##print(len(packed.compress(FileAccess.COMPRESSION_FASTLZ)))
	##print(len(packed.compress(FileAccess.COMPRESSION_DEFLATE)))
	#print(len(packed.compress(FileAccess.COMPRESSION_ZSTD)))
	##print(len(packed.compress(FileAccess.COMPRESSION_GZIP)))
	#
	#var end = Time.get_ticks_usec()
	#print("Compression: ", end - start)
	#
	#var offset := 0
	#var restored: Array[PackedInt32Array] = []
	#
	#while offset < len(packed):
		#restored.append(packed.slice(offset, offset + CHUNK_SIZE * CHUNK_SIZE * 4).to_int32_array())
		#print(len(restored[-1]))
		#offset += CHUNK_SIZE * CHUNK_SIZE * 4
	#
	#print("Decompression: ", Time.get_ticks_usec() - end)
	#
	#print(restored == sub_chunks)

#endregion

#region Tile Access
func _get_tile(world_x: int, world_y: int) -> int:
	var chunk := get_chunk_from_world(world_x, world_y)
	var x := world_x % CHUNK_SIZE
	var y := world_y % CHUNK_SIZE
	
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
	
	var tile := chunk[x + y * CHUNK_SIZE]
	
	# wall id is bit 10 - 19
	return (tile >> 10) & (2**10 - 1)

func get_block_in_chunk(chunk: PackedInt32Array, x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE:
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
func add_chunk() -> void:
	var tiles := PackedInt32Array()
	
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			tiles.append(0)
	
	chunks.append(tiles)

@warning_ignore_start("integer_division")
func get_chunk(x: int, y: int) -> PackedInt32Array:
	if x < 0 or x >= Globals.world_size.x / CHUNK_SIZE or y < 0 or y >= Globals.world_size.y / CHUNK_SIZE:
		return PackedInt32Array()
	
	if multiplayer.is_server():
		return chunks[x + y * (Globals.world_size.y / CHUNK_SIZE)]
	else:
		return chunk_map.get(Vector2i(x, y))

func get_chunk_from_world(world_x: int, world_y: int) -> PackedInt32Array:
	var chunk_x := floori(world_x / CHUNK_SIZE)
	var chunk_y := floori(world_y / CHUNK_SIZE)
	
	return get_chunk(chunk_x, chunk_y)

func set_chunk(x: int, y: int, data: PackedInt32Array) -> void:
	if x < 0 or x >= Globals.world_size.x / CHUNK_SIZE or y < 0 or y >= Globals.world_size.y / CHUNK_SIZE:
		return
	
	if multiplayer.is_server():
		chunks[x + y * (Globals.world_size.y / CHUNK_SIZE)] = data
	else:
		chunk_map[Vector2i(x, y)] = data

func set_chunk_from_world(world_x: int, world_y: int, data: PackedInt32Array) -> void:
	var chunk_x := floori(world_x / CHUNK_SIZE)
	var chunk_y := floori(world_y / CHUNK_SIZE)
	
	set_chunk(chunk_x, chunk_y, data)

func create_chunk_object(x: int, y: int) -> void:
	var chunk := preload("uid://m5kcmqx3t3dm").instantiate() as WorldChunk
	chunk.chunk_pos = Vector2i(x, y)
	
	chunk.load_from_data()
	
	get_tree().current_scene.get_node(^'tiles').add_child(chunk)

@warning_ignore_restore("integer_division")

#endregion

#region Multiplayer


#endregion
