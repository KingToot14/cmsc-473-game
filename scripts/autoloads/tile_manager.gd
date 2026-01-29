extends Node

# --- Variables --- #
const CHUNK_SIZE := 16
var world_size: Vector2i = Vector2i(8400, 2400)

var chunks: Array[PackedInt32Array]
var chunk_map: Dictionary[Vector2i, PackedInt32Array] = {}

# --- Functions --- #
func _ready() -> void:
	if multiplayer.is_server():
		add_chunk()

#region Positions
func chunk_to_world(chunk_x: int, chunk_y: int, x: int, y: int) -> void:
	pass

#endregion

#region Tile Access
func _get_tile(world_x: int, world_y: int) -> int:
	var chunk := get_chunk_from_world(world_x, world_y)
	var x := world_x % CHUNK_SIZE
	var y := world_y % CHUNK_SIZE
	
	return chunk[x + y * CHUNK_SIZE]

func get_wall(world_x: int, world_y: int) -> int:
	# check bounds
	if world_x < 0 or world_x >= world_size.x or world_y < 0 or world_y >= world_size.y:
		return 0
	
	var tile := _get_tile(world_x, world_y)
	
	# wall id is bit 10 - 19
	return (tile >> 10) & (2**10 - 1)

func get_block(world_x: int, world_y: int) -> int:
	# check bounds
	if world_x < 0 or world_x >= world_size.x or world_y < 0 or world_y >= world_size.y:
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
	if world_x < 0 or world_x >= world_size.x or world_y < 0 or world_y >= world_size.y:
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
	if world_x < 0 or world_x >= world_size.x or world_y < 0 or world_y >= world_size.y:
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

func get_chunk(x: int, y: int) -> PackedInt32Array:
	if multiplayer.is_server():
		@warning_ignore("integer_division")
		return chunks[x + y * (world_size.y / CHUNK_SIZE)]
	else:
		return chunk_map.get(Vector2i(x, y))

func get_chunk_from_world(world_x: int, world_y: int) -> PackedInt32Array:
	@warning_ignore("integer_division")
	var chunk_x := floori(world_x / CHUNK_SIZE)
	@warning_ignore("integer_division")
	var chunk_y := floori(world_y / CHUNK_SIZE)
	
	return get_chunk(chunk_x, chunk_y)

#endregion
