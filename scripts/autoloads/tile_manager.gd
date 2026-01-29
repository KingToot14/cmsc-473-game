extends Node

# --- Variables --- #
const CHUNK_SIZE := 16
var world_size: Vector2i = Vector2i(8400, 2400)

var chunks: Array[PackedInt32Array]
var chunk_map: Dictionary[Vector2i, PackedInt32Array] = {}

# --- Functions --- #

#region Tile Access
func _get_tile(world_x: int, world_y: int) -> int:
	var chunk := get_chunk_from_world(world_x, world_y)
	var x := world_x % CHUNK_SIZE
	var y := world_y % CHUNK_SIZE
	
	return chunk[x + y * CHUNK_SIZE]

func get_wall(world_x: int, world_y: int) -> int:
	var tile := _get_tile(world_x, world_y)
	
	# wall id is bit 10 - 19
	return (tile >> 10) & (2**10 - 1)

func get_block(world_x: int, world_y: int) -> int:
	var tile := _get_tile(world_x, world_y)
	
	# block id is bit 0 - 9
	return (tile >> 0) & (2**10 - 1)

#endregion

#region Chunk Access
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
