class_name ChunkLoader
extends Node

# --- Signals --- #
signal area_loaded()

# --- Variables --- #
const UNLOAD_RANGE := Vector2i(10, 8)
const LOAD_RANGE := Vector2i(7, 5)
const VISUAL_RANGE := Vector2i(5, 3)

@export var player: PlayerController
var current_chunk: Vector2i

# --- Functions --- #
func _ready() -> void:
	set_process(false)
	
	await player.ready
	
	current_chunk = TileManager.world_to_chunk(floori(player.position.x), floori(player.position.y))

func _process(_delta: float) -> void:
	var new_chunk = TileManager.world_to_chunk(floori(player.position.x), floori(player.position.y))
	
	var diff: Vector2i = new_chunk - current_chunk
	var size := absi(diff.x) + absi(diff.y)
	
	if size >= 1:
		current_chunk = new_chunk
		
		# don't process overly large boundary jumps
		if size > 4:
			return
		
		if not multiplayer.is_server() and player.owner_id == multiplayer.get_unique_id():
			BiomeManager.check_biome(player.global_position)
		
		if multiplayer.is_server():
			# server sends chunk updates
			if diff.x != 0:
				var boundary := diff
				boundary.y = 0
				send_boundary(boundary)
				unload_boundary(boundary)
			if diff.y != 0:
				var boundary := diff
				boundary.x = 0
				send_boundary(boundary)
				unload_boundary(boundary)
		else:
			# client autotiles
			if diff.x != 0:
				var boundary := diff
				boundary.y = 0
				autotile_boundary(boundary)
				unload_boundary(boundary)
			if diff.y != 0:
				var boundary := diff
				boundary.x = 0
				autotile_boundary(boundary)
				unload_boundary(boundary)

#region Boundaries
func clear_boundary(boundary: Vector2i) -> void:
	var start_chunk := current_chunk - UNLOAD_RANGE
	var end_chunk := current_chunk + UNLOAD_RANGE + Vector2i.ONE
	
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
	var start_chunk := current_chunk - LOAD_RANGE
	var end_chunk := current_chunk + LOAD_RANGE + Vector2i.ONE
	
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
	var start_chunk := current_chunk - VISUAL_RANGE
	var end_chunk := current_chunk + VISUAL_RANGE + Vector2i.ONE
	
	if boundary.x < 0:
		end_chunk.x = start_chunk.x - boundary.x
	elif boundary.x > 0:
		start_chunk.x = end_chunk.x - boundary.x
	if boundary.y < 0:
		end_chunk.y = start_chunk.y - boundary.y
	elif boundary.y > 0:
		start_chunk.y = end_chunk.y - boundary.y
	
	for x in range(start_chunk.x, end_chunk.x):
		for y in range(start_chunk.y, end_chunk.y):
			Globals.world_map.queued_chunks[Vector2i(x, y)] = true
	
	#autotile_region(start_chunk.x, start_chunk.y, end_chunk.x, end_chunk.y)

func unload_boundary(boundary: Vector2i) -> void:
	var start_chunk := current_chunk - UNLOAD_RANGE
	var end_chunk := current_chunk + UNLOAD_RANGE
	
	if abs(boundary.x) > 1 or abs(boundary.y) > 1:
		return
	
	if boundary.x < 0:
		start_chunk.x = end_chunk.x + boundary.x
	elif boundary.x > 0:
		end_chunk.x = start_chunk.x + boundary.x
	if boundary.y < 0:
		start_chunk.y = end_chunk.y + boundary.y
	elif boundary.y > 0:
		end_chunk.y = start_chunk.y + boundary.y
	
	if multiplayer.is_server():
		# clear server map
		pass
	else:
		# clear world map
		start_chunk.x = clampi(start_chunk.x, 0, Globals.world_chunks.x)
		start_chunk.y = clampi(start_chunk.y, 0, Globals.world_chunks.y)
		end_chunk.x = clampi(end_chunk.x, 0, Globals.world_chunks.x)
		end_chunk.y = clampi(end_chunk.y, 0, Globals.world_chunks.y)
		
		var width  := end_chunk.x - start_chunk.x
		var height := end_chunk.y - start_chunk.y
		
		if width <= 0 or height <= 0:
			return
		
		Globals.world_map.clear_region(
			start_chunk.x * TileManager.CHUNK_SIZE,
			start_chunk.y * TileManager.CHUNK_SIZE,
			width * TileManager.CHUNK_SIZE,
			height * TileManager.CHUNK_SIZE
		)

#endregion

#region Regions
func autotile_region(start_x: int, start_y: int, end_x: int, end_y: int) -> void:
	var dirty_chunks: Array[Vector2i] = []
	
	# only tile dirty chunks
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var state = Globals.world_map.chunk_states.get(Vector2i(x, y), WorldTileMap.UpdateState.UNLOADED)
			if state != WorldTileMap.UpdateState.TILED:
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
	var start_chunk := (current_chunk - LOAD_RANGE)
	var end_chunk := current_chunk + LOAD_RANGE + Vector2i.ONE
	
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
	
	# update server tilemap (allow buffer to keep entities in the world)
	Globals.server_map.load_tiles(
		(start_chunk.x - 1) * TileManager.CHUNK_SIZE,
		(start_chunk.y - 1) * TileManager.CHUNK_SIZE,
		(width + 2) * TileManager.CHUNK_SIZE,
		(height + 2) * TileManager.CHUNK_SIZE
	)
	
	# send tile data
	load_chunks.rpc_id(player.owner_id, meta, data)

#endregion

#region Chunks
@rpc("authority", "call_remote", "reliable")
func load_chunks(meta: int, data: PackedByteArray) -> void:
	# decode data
	var start_x  := (meta >> 0)  & (2**10 - 1)
	var start_y  := (meta >> 10) & (2**10 - 1)
	var width    := (meta >> 20) & (2**10 - 1)
	var height   := (meta >> 30) & (2**10 - 1)
	var autotile := (meta >> 40) == 1
	
	@warning_ignore('integer_division')
	var center_x = start_x + width / 2
	@warning_ignore('integer_division')
	var center_y = start_y + height / 2
	
	data = data.decompress(
		width * height * TileManager.CHUNK_AREA * 6,
		FileAccess.COMPRESSION_ZSTD
	)
	
	var world_start_x = start_x * TileManager.CHUNK_SIZE
	var world_start_y = start_y * TileManager.CHUNK_SIZE
	var world_width   = width * TileManager.CHUNK_SIZE
	var world_height  = height * TileManager.CHUNK_SIZE
	
	await TileManager.load_region(data, world_start_x, world_start_y, world_width, world_height)
	
	# autotile initial packet
	if autotile:
		await get_tree().process_frame
		
		@warning_ignore('integer_division')
		await autotile_region(
			center_x - VISUAL_RANGE.x,
			center_y - VISUAL_RANGE.y,
			center_x + VISUAL_RANGE.x + 1,
			center_y + VISUAL_RANGE.y + 1
		)
	
	# build water texture
	#TileManager.build_water_texture()
	
	# load entities
	EntityManager.load_region.rpc_id(
		Globals.SERVER_ID,
		Vector2i(start_x, start_y), width, height,
		player.owner_id
	)
	
	# this probably isn't a perfect solution, but should allow the server to load entities
	await get_tree().create_timer(2.0).timeout
	
	# send update to server
	done_loading.rpc_id(Globals.SERVER_ID, &'initial-load')
	await get_tree().create_timer(0.5).timeout
	
	set_process(true)
	area_loaded.emit()

@rpc('any_peer', 'call_remote', 'reliable')
func done_loading(message: StringName) -> void:
	if message == &'initial-load':
		set_process(true)
		area_loaded.emit()
		ServerManager.finalized_players[player.owner_id] = true

#endregion
