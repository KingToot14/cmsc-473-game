class_name ChunkLoader
extends Node

# --- Variables --- #
const LOAD_RANGE := Vector2i(5, 3)

@export var player: PlayerController
var current_chunk: Vector2i

# --- Functions --- #
func _ready() -> void:
	if not multiplayer.is_server():
		if len(TileManager.tiles) == 0:
			TileManager.load_chunks()
		
		return
	
	await player.ready
	
	current_chunk = TileManager.world_to_chunk(
		roundi(player.position.x / 8.0),
		roundi(player.position.y / 8.0)
	)

func _process(_delta: float) -> void:
	var new_chunk = TileManager.world_to_chunk(
		roundi(player.position.x / 8.0),
		roundi(player.position.y / 8.0)
	)
	
	if multiplayer.is_server():
		var diff := (new_chunk - current_chunk).abs()
		if diff.x + diff.y == 1:
			send_boundary(new_chunk - current_chunk)
			current_chunk = new_chunk

func clear_boundary(boundary: Vector2i) -> void:
	var center_chunk := TileManager.world_to_chunk(
		roundi(player.position.x / 8),
		roundi(player.position.y / 8)
	)
	var start_chunk := (center_chunk - LOAD_RANGE)
	var end_chunk := center_chunk + LOAD_RANGE + Vector2i.ONE
	
	match boundary:
		Vector2i(-1,  0):
			end_chunk.x = start_chunk.x + 1
		Vector2i( 1,  0):
			start_chunk.x = end_chunk.x - 1
		Vector2i( 0, -1):
			end_chunk.y = start_chunk.y + 1
		Vector2i( 0,  1):
			start_chunk.y = end_chunk.y - 1
	
	# clamp positions
	start_chunk.x = clampi(start_chunk.x, 0, Globals.world_chunks.x)
	start_chunk.y = clampi(start_chunk.y, 0, Globals.world_chunks.y)
	end_chunk.x = clampi(end_chunk.x, 0, Globals.world_chunks.x)
	end_chunk.y = clampi(end_chunk.y, 0, Globals.world_chunks.y)
	
	var width  = end_chunk.x - start_chunk.x
	var height = end_chunk.y - start_chunk.y
	
	start_chunk *= TileManager.CHUNK_SIZE
	width *= TileManager.CHUNK_SIZE
	height *= TileManager.CHUNK_SIZE
	
	Globals.world_map.clear_region(start_chunk.x, start_chunk.y, width, height)

func send_boundary(boundary: Vector2i) -> void:
	var center_chunk := TileManager.world_to_chunk(
		roundi(player.position.x / 8),
		roundi(player.position.y / 8)
	)
	var start_chunk := (center_chunk - LOAD_RANGE)
	var end_chunk := center_chunk + LOAD_RANGE + Vector2i.ONE
	
	match boundary:
		Vector2i(-1,  0):
			end_chunk.x = start_chunk.x + 1
		Vector2i( 1,  0):
			start_chunk.x = end_chunk.x - 1
		Vector2i( 0, -1):
			end_chunk.y = start_chunk.y + 1
		Vector2i( 0,  1):
			start_chunk.y = end_chunk.y - 1
	
	# clamp positions
	start_chunk.x = clampi(start_chunk.x, 0, Globals.world_chunks.x)
	start_chunk.y = clampi(start_chunk.y, 0, Globals.world_chunks.y)
	end_chunk.x = clampi(end_chunk.x, 0, Globals.world_chunks.x)
	end_chunk.y = clampi(end_chunk.y, 0, Globals.world_chunks.y)
	
	var width  = end_chunk.x - start_chunk.x
	var height = end_chunk.y - start_chunk.y
	
	# pack data
	var meta = (
		(start_chunk.x << 0) |
		(start_chunk.y << 10) |
		(width << 20) |
		(height << 30)
	)
	var data := TileManager.pack_chunks(start_chunk.x, start_chunk.y, width, height)
	
	load_chunks.rpc_id(player.owner_id, meta, data)

func send_whole_area() -> void:
	var center_chunk := TileManager.world_to_chunk(
		roundi(player.position.x / 8),
		roundi(player.position.y / 8)
	)
	var start_chunk := (center_chunk - LOAD_RANGE)
	var end_chunk := center_chunk + LOAD_RANGE + Vector2i.ONE
	
	# clamp positions
	start_chunk.x = clampi(start_chunk.x, 0, Globals.world_chunks.x)
	start_chunk.y = clampi(start_chunk.y, 0, Globals.world_chunks.y)
	end_chunk.x = clampi(end_chunk.x, 0, Globals.world_chunks.x)
	end_chunk.y = clampi(end_chunk.y, 0, Globals.world_chunks.y)
	
	var width  = end_chunk.x - start_chunk.x
	var height = end_chunk.y - start_chunk.y
	
	if width == 0 or height == 0:
		return
	
	# pack data
	var meta = (
		(start_chunk.x << 0) |
		(start_chunk.y << 10) |
		(width << 20) |
		(height << 30)
	)
	var data := TileManager.pack_chunks(start_chunk.x, start_chunk.y, width, height)
	
	if len(data) == 0:
		return
	
	load_chunks.rpc_id(player.owner_id, meta, data)

@rpc("authority", "call_remote", "reliable")
func load_chunks(meta: int, data: PackedByteArray) -> void:
	# decode data
	var start_x := (meta >> 0)  & (2**10 - 1)
	var start_y := (meta >> 10) & (2**10 - 1)
	var width   := (meta >> 20) & (2**10 - 1)
	var height  := (meta >> 30) & (2**10 - 1)
	
	data = data.decompress(
		width * height * TileManager.CHUNK_SIZE * TileManager.CHUNK_SIZE * 4,
		FileAccess.COMPRESSION_ZSTD
	)
	
	start_x *= TileManager.CHUNK_SIZE
	start_y *= TileManager.CHUNK_SIZE
	width *= TileManager.CHUNK_SIZE
	height *= TileManager.CHUNK_SIZE
	
	var tiles := PackedInt32Array()
	var offset := 0
	
	tiles.resize(width * height)
	
	for y in range(height):
		for x in range(width):
			tiles[x + y * width] = data.decode_u32(offset)
			offset += 4
	
	TileManager.load_region(tiles, start_x, start_y, width, height)
