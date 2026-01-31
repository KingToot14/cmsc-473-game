class_name ChunkLoader
extends Node

# --- Variables --- #
const LOAD_RANGE := Vector2i(5, 3)

@export var player: PlayerController
var current_chunk: Vector2i

# --- Functions --- #
func _ready() -> void:
	if not multiplayer.is_server():
		set_process(false)
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
	
	if new_chunk != current_chunk and new_chunk.distance_squared_to(current_chunk) < 2:
		send_boundary_cross(new_chunk - current_chunk)
	
	current_chunk = new_chunk

func send_boundary_cross(boundary: Vector2i) -> void:
	var center_chunk := TileManager.world_to_chunk(
		roundi(player.position.x / 8),
		roundi(player.position.y / 8)
	)
	var start_chunk := (center_chunk - LOAD_RANGE)
	var end_chunk := center_chunk + LOAD_RANGE
	
	match boundary:
		Vector2i(-1,  0):
			end_chunk.x = start_chunk.x
		Vector2i( 1,  0):
			start_chunk.x = end_chunk.x
		Vector2i( 0, -1):
			end_chunk.y = start_chunk.y
		Vector2i( 0,  1):
			start_chunk.y = end_chunk.y
	
	# pack data
	var meta = (
		(start_chunk.x << 0) |
		(start_chunk.y << 10) |
		((end_chunk.x - start_chunk.x) << 20) |
		((end_chunk.y - start_chunk.y) << 30)
	)
	var data := TileManager.pack_chunks(start_chunk.x, start_chunk.y, end_chunk.x, end_chunk.y)
	
	load_chunks.rpc_id(player.owner_id, meta, data)

func send_whole_area() -> void:
	var center_chunk := TileManager.world_to_chunk(
		roundi(player.position.x / 8),
		roundi(player.position.y / 8)
	)
	var start_chunk := (center_chunk - LOAD_RANGE)
	var end_chunk := center_chunk + LOAD_RANGE
	
	# clamp positions
	start_chunk.x = clampi(start_chunk.x, 0, Globals.world_chunks.x)
	start_chunk.y = clampi(start_chunk.y, 0, Globals.world_chunks.y)
	end_chunk.x = clampi(end_chunk.x, 0, Globals.world_chunks.x)
	end_chunk.y = clampi(end_chunk.y, 0, Globals.world_chunks.y)
	
	# pack data
	var meta = (
		(start_chunk.x << 0) |
		(start_chunk.y << 10) |
		((end_chunk.x - start_chunk.x) << 20) |
		((end_chunk.y - start_chunk.y) << 30)
	)
	var data := TileManager.pack_chunks(start_chunk.x, start_chunk.y, end_chunk.x, end_chunk.y)
	
	load_chunks.rpc_id(player.owner_id, meta, data)

@rpc("authority", "call_remote", "reliable")
func load_chunks(meta: int, data: PackedByteArray) -> void:
	# decode data
	var start_x := (meta >> 0)  & (2**10 - 1)
	var start_y := (meta >> 10) & (2**10 - 1)
	var width   := (meta >> 20) & (2**10 - 1)
	var height  := (meta >> 30) & (2**10 - 1)
	
	data = data.decompress(
		(width + 1) * (height + 1) * TileManager.CHUNK_SIZE * TileManager.CHUNK_SIZE * 4,
		FileAccess.COMPRESSION_ZSTD
	)
	
	var chunks: Array[PackedInt32Array] = []
	var offset := 0
	
	while offset < len(data):
		chunks.append(
			data.slice(offset, offset + TileManager.CHUNK_SIZE * TileManager.CHUNK_SIZE * 4).to_int32_array()
		)
		offset += TileManager.CHUNK_SIZE * TileManager.CHUNK_SIZE * 4
	
	TileManager.load_chunk_region(chunks, start_x, start_y, width, height)
