class_name LightUpdater
extends Node

# --- Signals --- #
signal propagated()

# --- Variables --- #
const UPDATE_TIME := 0.05
const MAX_UPDATES_PER_FRAME := 300

const MAX_LIGHT_LEVEL := 255
const AIR_FALLOFF := 16
const BLOCK_FALLOFF := 40
const WALL_FALLOFF := 0

const UNDERWORLD_R := 255
const UNDERWORLD_G := 225
const UNDERWORLD_B := 180

var active := false

var update_timer := 0.0
var active_tiles: Dictionary[Vector2i, bool] = {}
var updated_tiles: Dictionary[Vector2i, int]

var point_lights: Dictionary[Vector2i, Color] = {}

# --- Functions --- #
func _ready() -> void:
	Globals.light_updater = self

#region Queue Management
func add_to_queue(position: Vector2i, sky := -1) -> void:
	if sky == -1:
		sky = TileManager.get_light_sky(position.x, position.y)
	
	if not active and sky == 0:
		return
	
	active_tiles[position] = true
	
	queue_update(position.x, position.y, sky)

func remove_from_queue(position: Vector2i, sky := -1) -> void:
	active_tiles.erase(position)
	
	if sky == -1:
		sky = TileManager.get_light_sky(position.x, position.y)
	
	queue_update(position.x, position.y, sky)

#endregion

#region Point Lights
@rpc('any_peer', 'call_remote', 'reliable')
func toggle_point_light(pos: Vector2i, color: Color) -> void:
	if pos in point_lights:
		remove_point_light(pos)
	else:
		add_point_light(pos, color)

func add_point_light(pos: Vector2i, color: Color) -> void:
	point_lights[pos] = color
	
	update_region(pos.x - 16, pos.y - 16, 33, 33)

func remove_point_light(pos: Vector2i) -> void:
	if pos in point_lights:
		point_lights.erase(pos)
		
		update_region(pos.x - 16, pos.y - 16, 33, 33)

#endregion

#region Simulation
func update_region(start_x: int, start_y: int, width: int, height: int) -> void:
	var sky_queue: Dictionary[Vector2i, bool] = {}
	var queue: Dictionary[Vector2i, bool] = {}
	var buffer_sky := PackedByteArray()
	buffer_sky.resize((width + 32) * (height + 32))
	var buffer_r := PackedByteArray()
	buffer_r.resize((width + 32) * (height + 32))
	var buffer_g := PackedByteArray()
	buffer_g.resize((width + 32) * (height + 32))
	var buffer_b := PackedByteArray()
	buffer_b.resize((width + 32) * (height + 32))
	
	# re-seed sky
	for y in range(height + 32):
		for x in range(width + 32):
			var wx = start_x + x - 16
			var wy = start_y + y - 16
			
			# check for surface-level empty tiles
			if wy < Globals.underground and \
				TileManager.get_block(wx, wy) == 0 and TileManager.get_wall(wx, wy) == 0:
				
				var bx := x
				var by := y
				
				buffer_sky[bx + by * (width + 32)] = MAX_LIGHT_LEVEL
				
				sky_queue[Vector2i(bx, by)] = true
			elif wy > (Globals.world_size.y - 150) and \
				TileManager.get_block(wx, wy) == 0 and TileManager.get_wall(wx, wy) == 0:
				
				var bx := x
				var by := y
				
				buffer_r[bx + by * (width + 32)] = UNDERWORLD_R
				buffer_g[bx + by * (width + 32)] = UNDERWORLD_G
				buffer_b[bx + by * (width + 32)] = UNDERWORLD_B
				
				queue[Vector2i(bx, by)] = true
			else:
				buffer_sky[x + y * (width + 32)] = 0
	
	# re-seed relevant point lights
	for pos: Vector2i in point_lights:
		if pos.x < start_x - 16 or pos.x >= start_x + width + 16:
			continue
		if pos.y < start_y - 16 or pos.y >= start_y + height + 16:
			continue
		
		var bx := pos.x - start_x + 16
		var by := pos.y - start_y + 16
		
		var color := point_lights[pos]
		var idx := bx + by * (width + 32)
		
		buffer_r[idx] = color.r8
		buffer_g[idx] = color.g8
		buffer_b[idx] = color.b8
		
		queue[Vector2i(bx, by)] = true
	
	propagate_region_single(buffer_sky, sky_queue, start_x, start_y, width, height)
	propagate_region(
		buffer_r, buffer_g, buffer_b, queue,
		start_x, start_y, width, height
	)
	
	send_region_update(start_x, start_y, start_x + width, start_y + height)

func handle_update(pos: Vector2i) -> void:
	var sky := TileManager.get_light_sky(pos.x, pos.y)
	
	spread_to(pos + Vector2i( 1,  0), sky)
	spread_to(pos + Vector2i( 0,  1), sky)
	spread_to(pos + Vector2i(-1,  0), sky)
	spread_to(pos + Vector2i( 0, -1), sky)
	
	remove_from_queue(pos)

func spread_to(pos: Vector2i, sky: int) -> void:
	# check bounds
	if pos.x < 0 or pos.x > Globals.world_size.x:
		return
	if pos.y < 0 or pos.y > Globals.world_size.y:
		return
	
	var curr_sky := TileManager.get_light_sky(pos.x, pos.y)
	
	# falloff
	if TileManager.get_block(pos.x, pos.y) == 0:
		sky -= AIR_FALLOFF
		
		if TileManager.get_wall(pos.x, pos.y) != 0:
			sky -= WALL_FALLOFF
	else:
		sky -= BLOCK_FALLOFF
	
	if sky > curr_sky:
		TileManager.set_light_sky(pos.x, pos.y, sky)
		add_to_queue(pos)

func spread_to_queue(
		buffer_r: PackedByteArray, buffer_g: PackedByteArray, buffer_b: PackedByteArray,
		queue: Dictionary[Vector2i, bool], pos: Vector2i, width: int, start_x: int, start_y: int,
		r: int, g: int, b: int
	) -> void:
	
	var curr_r := buffer_r[pos.x + pos.y * (width + 32)]
	var curr_g := buffer_g[pos.x + pos.y * (width + 32)]
	var curr_b := buffer_b[pos.x + pos.y * (width + 32)]
	
	# falloff
	if TileManager.get_block(start_x + pos.x - 16, start_y + pos.y - 16) == 0:
		r -= AIR_FALLOFF
		g -= AIR_FALLOFF
		b -= AIR_FALLOFF
		
		if TileManager.get_wall(start_x + pos.x - 16, start_y + pos.y - 16) != 0:
			r -= WALL_FALLOFF
			g -= WALL_FALLOFF
			b -= WALL_FALLOFF
	else:
		r -= BLOCK_FALLOFF
		g -= BLOCK_FALLOFF
		b -= BLOCK_FALLOFF
	
	if r > curr_r:
		buffer_r[pos.x + pos.y * (width + 32)] = r
		queue[pos] = true
	if g > curr_g:
		buffer_g[pos.x + pos.y * (width + 32)] = g
		queue[pos] = true
	if b > curr_b:
		buffer_b[pos.x + pos.y * (width + 32)] = b
		queue[pos] = true

func spread_to_queue_single(
		buffer: PackedByteArray,
		queue: Dictionary[Vector2i, bool], pos: Vector2i, width: int, start_x: int, start_y: int,
		sky: int
	) -> void:
	
	var curr_sky := buffer[pos.x + pos.y * (width + 32)]
	
	# falloff
	if TileManager.get_block(start_x + pos.x - 16, start_y + pos.y - 16) == 0:
		sky -= AIR_FALLOFF
		
		if TileManager.get_wall(start_x + pos.x - 16, start_y + pos.y - 16) != 0:
			sky -= WALL_FALLOFF
	else:
		sky -= BLOCK_FALLOFF
	
	if sky > curr_sky:
		buffer[pos.x + pos.y * (width + 32)] = sky
		queue[pos] = true

#endregion

#region Updating
func queue_update(x: int, y: int, sky: int) -> void:
	if not active:
		return
	
	updated_tiles[Vector2i(x, y)] = sky

func send_update() -> void:
	var update_size := len(updated_tiles)
	
	if update_size == 0:
		return
	
	# send relavent data to players
	for player_id in ServerManager.connected_players.keys():
		# get bounding box
		var player := ServerManager.get_player(player_id)
		
		if not player:
			continue
		
		var center := TileManager.world_to_tile(
			floori(player.center_point.x),
			floori(player.center_point.y)
		)
		var start := center - ChunkLoader.VISUAL_RANGE * TileManager.CHUNK_SIZE
		var end   := center + ChunkLoader.VISUAL_RANGE * TileManager.CHUNK_SIZE
		
		# build buffer
		var buffer := StreamPeerBuffer.new()
		
		# update size placeholer
		var updated := 0
		buffer.put_u16(0)
		
		for tile: Vector2i in updated_tiles:
			if tile.x < start.x or tile.x > end.x or tile.y < start.y or tile.y > end.y:
				continue
			
			updated += 1
			
			buffer.put_u16(tile.x)
			buffer.put_u16(tile.y)
			
			buffer.put_u8(updated_tiles[tile])
			buffer.put_u8(updated_tiles[tile])
			buffer.put_u8(updated_tiles[tile])
		
		# only send data if necessary
		if updated == 0:
			continue
		
		# set update size
		var data := buffer.data_array
		data.encode_u16(0, updated)
		
		TileManager.send_light_update(player_id, data)

func send_region_update(start_x: int, start_y: int, end_x: int, end_y: int) -> void:
	# send relavent data to players
	for player_id in ServerManager.connected_players.keys():
		var player := ServerManager.get_player(player_id)
		
		# get bounding box
		if not player:
			continue
		
		var center := TileManager.world_to_tile(
			floori(player.center_point.x),
			floori(player.center_point.y)
		)
		var start := center - ChunkLoader.VISUAL_RANGE * TileManager.CHUNK_SIZE
		var end   := center + ChunkLoader.VISUAL_RANGE * TileManager.CHUNK_SIZE
		
		# only update intersecting regions
		if start.x > end_x or end.x < start_x:
			continue
		if start.y > end_y or end.y < start_y:
			continue
		
		# build buffer
		var buffer := StreamPeerBuffer.new()
		
		# update size placeholder
		buffer.put_u16(0)
		var updated := 0
		
		for y in range(start_y, end_y):
			for x in range(start_x, end_x):
				if x < start.x or x > end.x or y < start.y or y > end.y:
					continue
				
				updated += 1
				
				buffer.put_u16(x)
				buffer.put_u16(y)
				
				buffer.put_u8(TileManager.get_light_sky(x, y))
				buffer.put_u8(TileManager.get_light_r(x, y))
				buffer.put_u8(TileManager.get_light_g(x, y))
				buffer.put_u8(TileManager.get_light_b(x, y))
				
		# send update
		var data := buffer.data_array
		data.encode_u16(0, updated)
		
		TileManager.send_light_update(player_id, data)

#endregion

#region Activity
func set_active() -> void:
	active = true
	set_process(true)

#endregion

#region Propagation
func propagate_all() -> void:
	var tiles := active_tiles.keys()
	var total_runs := 0
	
	while len(tiles) > 0 and total_runs < 100:
		var index := 0
		total_runs += 1
		
		# process as many tiles as possible
		while index < len(tiles):
			var tile: Vector2i = tiles[index]
			
			# update counter
			index += 1
			
			# make sure tile still exists
			if tile not in active_tiles:
				continue
			
			handle_update(tile)
		
		tiles = active_tiles.keys()
	
	propagated.emit()

func propagate_region(
		buffer_r: PackedByteArray, buffer_g: PackedByteArray, buffer_b: PackedByteArray,
		queue: Dictionary[Vector2i, bool], start_x: int, start_y: int, width: int, height: int
	) -> void:
	
	# standard propagation
	while not queue.is_empty():
		var tiles: Array[Vector2i] = queue.keys()
		
		for tile: Vector2i in tiles:
			# handle update
			var r := buffer_r[tile.x + tile.y * (width + 32)]
			var g := buffer_g[tile.x + tile.y * (width + 32)]
			var b := buffer_b[tile.x + tile.y * (width + 32)]
			
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1) ,Vector2i(0, -1)]:
				var nx := tile.x + offset.x
				var ny := tile.y + offset.y
				
				# only update inside region
				if nx < 0 or nx >= width + 32:
					continue
				if ny < 0 or ny >= height + 32:
					continue
				
				spread_to_queue(
					buffer_r, buffer_g, buffer_b,
					queue, Vector2i(nx, ny), width, start_x, start_y, r, g, b
				)
			
			queue.erase(tile)
	
	# apply buffer
	for y in range(height):
		for x in range(width):
			var idx := (x + 16) + (y + 16) * (width + 32)
			
			TileManager.set_light_r(start_x + x, start_y + y, buffer_r[idx])
			TileManager.set_light_g(start_x + x, start_y + y, buffer_g[idx])
			TileManager.set_light_b(start_x + x, start_y + y, buffer_b[idx])
	
	# send update
	#send_region_update(start_x, start_y, start_x + width, start_y + height)

func propagate_region_single(
		buffer: PackedByteArray,
		queue: Dictionary[Vector2i, bool], start_x: int, start_y: int, width: int, height: int
	) -> void:
	
	# standard propagation
	while not queue.is_empty():
		var tiles: Array[Vector2i] = queue.keys()
		
		for tile: Vector2i in tiles:
			# handle update
			var sky := buffer[tile.x + tile.y * (width + 32)]
			
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1) ,Vector2i(0, -1)]:
				var nx := tile.x + offset.x
				var ny := tile.y + offset.y
				
				# only update inside region
				if nx < 0 or nx >= width + 32:
					continue
				if ny < 0 or ny >= height + 32:
					continue
				
				spread_to_queue_single(
					buffer, queue, Vector2i(nx, ny), width, start_x, start_y, sky
				)
			
			queue.erase(tile)
	
	# apply buffer
	for y in range(height):
		for x in range(width):
			var idx := (x + 16) + (y + 16) * (width + 32)
			
			TileManager.set_light_sky(start_x + x, start_y + y, buffer[idx])
	
	# send update
	#send_region_update(start_x, start_y, start_x + width, start_y + height)

#endregion
