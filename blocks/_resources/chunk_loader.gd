class_name ChunkLoader
extends Node

# --- Variables --- #
const UNLOAD_RANGE := Vector2i(10, 8)
const LOAD_RANGE := Vector2i(7, 5)
const VISUAL_RANGE := Vector2i(5, 3)

@export var player: PlayerController
var current_chunk: Vector2i

# --- Functions --- #
func _ready() -> void:
	if not multiplayer.is_server():
		if len(TileManager.tiles) == 0:
			TileManager.load_chunks()
		
		return
	
	await player.ready
	
	current_chunk = TileManager.tile_to_chunk(
		roundi(player.position.x / 8.0),
		roundi(player.position.y / 8.0)
	)

func _process(_delta: float) -> void:
	var new_chunk = TileManager.tile_to_chunk(
		roundi(player.position.x / 8.0),
		roundi(player.position.y / 8.0)
	)
	
	var diff := (new_chunk - current_chunk).abs()
	if diff.x + diff.y >= 1:
		if multiplayer.is_server():
			# server sends chunk updates
			send_boundary(new_chunk - current_chunk)
		else:
			# client autotiles
			autotile_boundary(new_chunk - current_chunk)
		
		current_chunk = new_chunk

func clear_boundary(boundary: Vector2i) -> void:
	var center_chunk := TileManager.tile_to_chunk(
		roundi(player.position.x / 8),
		roundi(player.position.y / 8)
	)
	var start_chunk := (center_chunk - LOAD_RANGE)
	var end_chunk := center_chunk + LOAD_RANGE + Vector2i.ONE
	
	if boundary.x < 0:
		end_chunk.x = start_chunk.x - boundary.x
	elif boundary.x > 0:
		start_chunk.x = end_chunk.x - boundary.x
	if boundary.y < 0:
		end_chunk.y = start_chunk.y - boundary.y
	elif boundary.y > 0:
		start_chunk.y = end_chunk.y - boundary.y
	
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
	var center_chunk := TileManager.tile_to_chunk(
		roundi(player.position.x / 8),
		roundi(player.position.y / 8)
	)
	var start_chunk := (center_chunk - LOAD_RANGE)
	var end_chunk := center_chunk + LOAD_RANGE + Vector2i.ONE
	
	if boundary.x < 0:
		end_chunk.x = start_chunk.x - boundary.x
	elif boundary.x > 0:
		start_chunk.x = end_chunk.x - boundary.x
	if boundary.y < 0:
		end_chunk.y = start_chunk.y - boundary.y
	elif boundary.y > 0:
		start_chunk.y = end_chunk.y - boundary.y
	
	send_region(start_chunk, end_chunk)

func autotile_boundary(boundary: Vector2i) -> void:
	var center_chunk := TileManager.tile_to_chunk(
		roundi(player.position.x / 8),
		roundi(player.position.y / 8)
	)
	var start_chunk := (center_chunk - VISUAL_RANGE)
	var end_chunk := center_chunk + VISUAL_RANGE + Vector2i.ONE
	
	if boundary.x < 0:
		end_chunk.x = start_chunk.x - boundary.x
	elif boundary.x > 0:
		start_chunk.x = end_chunk.x - boundary.x
	if boundary.y < 0:
		end_chunk.y = start_chunk.y - boundary.y
	elif boundary.y > 0:
		start_chunk.y = end_chunk.y - boundary.y
	
	autotile_region(start_chunk.x, start_chunk.y, end_chunk.x, end_chunk.y)

func autotile_region(start_x: int, start_y: int, end_x: int, end_y: int) -> void:
	var dirty_chunks: Array[Vector2i] = []
	
	# only tile dirty chunks
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var state = Globals.world_map.chunk_states.get(Vector2i(x, y), WorldTileMap.UpdateState.UNLOADED)
			if state == WorldTileMap.UpdateState.DIRTY:
				dirty_chunks.append(Vector2i(x, y))
	
	# sort chunks by distance
	dirty_chunks.sort_custom(func(a: Vector2i, b: Vector2i):
		return a.distance_squared_to(current_chunk) < b.distance_squared_to(current_chunk)
	)
	
	# autotile each chunk
	for chunk in dirty_chunks:
		Globals.world_map.autotile_region(
			chunk.x * TileManager.CHUNK_SIZE - 1,
			chunk.y * TileManager.CHUNK_SIZE - 1,
			TileManager.CHUNK_SIZE + 2,
			TileManager.CHUNK_SIZE + 2
		)
		
		# mark as tiled
		Globals.world_map.chunk_states[Vector2i(chunk.x, chunk.y)] = WorldTileMap.UpdateState.TILED
		
		await get_tree().process_frame

func send_whole_area() -> void:
	var center_chunk := TileManager.tile_to_chunk(
		roundi(player.position.x / 8),
		roundi(player.position.y / 8)
	)
	var start_chunk := (center_chunk - LOAD_RANGE)
	var end_chunk := center_chunk + LOAD_RANGE + Vector2i.ONE
	
	send_region(start_chunk, end_chunk, true)

func send_region(start_chunk: Vector2i, end_chunk: Vector2i, autotile := false) -> void:
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
	if autotile:
		meta |= (1 << 40)
	
	var data := TileManager.pack_chunks(start_chunk.x, start_chunk.y, width, height)
	
	if len(data) == 0:
		return
	
	# update server tilemap
	Globals.server_map.load_tiles(
		start_chunk.x * TileManager.CHUNK_SIZE,
		start_chunk.y * TileManager.CHUNK_SIZE,
		width * TileManager.CHUNK_SIZE,
		height * TileManager.CHUNK_SIZE
	)
	
	# send tile data
	load_chunks.rpc_id(player.owner_id, meta, data)
	
	# load chunk entities
	for x in range(start_chunk.x, end_chunk.x):
		for y in range(start_chunk.y, end_chunk.y):
			EntityManager.load_chunk(Vector2i(x, y), player.owner_id)

@rpc("authority", "call_remote", "reliable")
func load_chunks(meta: int, data: PackedByteArray) -> void:
	# decode data
	var start_x  := (meta >> 0)  & (2**10 - 1)
	var start_y  := (meta >> 10) & (2**10 - 1)
	var width    := (meta >> 20) & (2**10 - 1)
	var height   := (meta >> 30) & (2**10 - 1)
	var autotile := (meta >> 40) == 1
	
	data = data.decompress(
		width * height * TileManager.CHUNK_AREA * 4,
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
	
	await TileManager.load_region(tiles, start_x, start_y, width, height)
	
	# autotile initial packet
	if autotile:
		await get_tree().process_frame
		set_process(true)
		
		@warning_ignore('integer_division')
		autotile_region(
			start_x / TileManager.CHUNK_SIZE,
			start_y / TileManager.CHUNK_SIZE,
			(start_x + width) / TileManager.CHUNK_SIZE,
			(start_y + height) / TileManager.CHUNK_SIZE
		)
