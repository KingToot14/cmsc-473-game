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

var active := false

var update_timer := 0.0
var active_tiles: Dictionary[Vector2i, bool] = {}
var updated_tiles: Dictionary[Vector2i, Color]

var point_lights: Dictionary[Vector2i, Color] = {}

# --- Functions --- #
func _ready() -> void:
	Globals.light_updater = self

#region Queue Management
func add_to_queue(position: Vector2i, r := -1, g := -1, b := -1) -> void:
	if r == -1:
		r = TileManager.get_light_r(position.x, position.y)
	if g == -1:
		g = TileManager.get_light_g(position.x, position.y)
	if b == -1:
		b = TileManager.get_light_b(position.x, position.y)
	
	if not active and r == 0 and g == 0 and b == 0:
		return
	
	active_tiles[position] = true
	
	queue_update(position.x, position.y, r, g, b)

func remove_from_queue(position: Vector2i, r := -1, g := -1, b := -1) -> void:
	active_tiles.erase(position)
	
	if r == -1:
		r = TileManager.get_light_r(position.x, position.y)
	if g == -1:
		g = TileManager.get_light_g(position.x, position.y)
	if b == -1:
		b = TileManager.get_light_b(position.x, position.y)
	
	queue_update(position.x, position.y, r, g, b)

#endregion

#region Point Lights
@rpc('any_peer', 'call_remote', 'reliable')
func add_point_light(pos: Vector2i, color: Color) -> void:
	point_lights[pos] = color
	
	update_region(pos.x - 16, pos.y - 16, 33, 33)

#endregion

#region Simulation
func update_region(start_x: int, start_y: int, width: int, height: int) -> void:
	var queue: Dictionary[Vector2i, bool] = {}
	var buffer_r := PackedByteArray()
	buffer_r.resize((width + 32) * (height + 32))
	var buffer_g := PackedByteArray()
	buffer_g.resize((width + 32) * (height + 32))
	var buffer_b := PackedByteArray()
	buffer_b.resize((width + 32) * (height + 32))
	
	# re-seed sky
	for y in range(height):
		for x in range(width):
			var wx = start_x + x
			var wy = start_y + y
			
			# check for surface-level empty tiles
			if wy < Globals.underground and \
				TileManager.get_block(wx, wy) == 0 and TileManager.get_wall(wx, wy) == 0:
				
				var bx := x + 16
				var by := y + 16
				
				buffer_r[bx + by * (width + 32)] = MAX_LIGHT_LEVEL
				buffer_g[bx + by * (width + 32)] = MAX_LIGHT_LEVEL
				buffer_b[bx + by * (width + 32)] = MAX_LIGHT_LEVEL
				
				queue[Vector2i(bx, by)] = true
			else:
				buffer_r[(x + 16) + (y + 16) * (width + 32)] = 0
				buffer_g[(x + 16) + (y + 16) * (width + 32)] = 0
				buffer_b[(x + 16) + (y + 16) * (width + 32)] = 0
	
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
	
	propagate_region(
		buffer_r, buffer_g, buffer_b, queue,
		start_x, start_y, width, height
	)

func handle_update(pos: Vector2i) -> void:
	var r := TileManager.get_light_r(pos.x, pos.y)
	var g := TileManager.get_light_g(pos.x, pos.y)
	var b := TileManager.get_light_b(pos.x, pos.y)
	
	spread_to(pos + Vector2i( 1,  0), r, g, b)
	spread_to(pos + Vector2i( 0,  1), r, g, b)
	spread_to(pos + Vector2i(-1,  0), r, g, b)
	spread_to(pos + Vector2i( 0, -1), r, g, b)
	
	remove_from_queue(pos)

func spread_to(pos: Vector2i, r: int, g: int, b: int) -> void:
	# check bounds
	if pos.x < 0 or pos.x > Globals.world_size.x:
		return
	if pos.y < 0 or pos.y > Globals.world_size.y:
		return
	
	var curr_r := TileManager.get_light_r(pos.x, pos.y)
	var curr_g := TileManager.get_light_g(pos.x, pos.y)
	var curr_b := TileManager.get_light_b(pos.x, pos.y)
	
	# falloff
	if TileManager.get_block(pos.x, pos.y) == 0:
		r -= AIR_FALLOFF
		g -= AIR_FALLOFF
		b -= AIR_FALLOFF
		
		if TileManager.get_wall(pos.x, pos.y) != 0:
			r -= WALL_FALLOFF
			g -= WALL_FALLOFF
			b -= WALL_FALLOFF
	else:
		r -= BLOCK_FALLOFF
		g -= BLOCK_FALLOFF
		b -= BLOCK_FALLOFF
	
	if r > curr_r:
		TileManager.set_light_r(pos.x, pos.y, r)
		add_to_queue(pos, r, g, b)
	if g > curr_g:
		TileManager.set_light_g(pos.x, pos.y, g)
		add_to_queue(pos, r, g, b)
	if b > curr_b:
		TileManager.set_light_b(pos.x, pos.y, b)
		add_to_queue(pos, r, g, b)

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

#endregion

#region Updating
func queue_update(x: int, y: int, r: int, g: int, b: int) -> void:
	if not active:
		return
	
	updated_tiles[Vector2i(x, y)] = Color.from_rgba8(r, g, b)

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
			
			buffer.put_u8(updated_tiles[tile].r8)
			buffer.put_u8(updated_tiles[tile].g8)
			buffer.put_u8(updated_tiles[tile].b8)
		
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
	
	# point light estimation
	#for pos: Vector2i in point_lights:
		#if pos.x < start_x - 16 or pos.x > end_x + 16:
			#continue
		#if pos.y < start_y - 16 or pos.y > end_x + 16:
			#continue
		#
		#var color := point_lights[pos]
		#var r := color.r8
		#var g := color.g8
		#var b := color.b8
		#
		#for x in range(-16, 16):
			#for y in range(-16, 16):
				#var distance := absi(x) + absi(y)
				#var distance_mod := maxf(0.0, 1.0 - distance / 16.0)
				#
				#if distance_mod == 0.0:
					#continue
				#
				#var curr_r := TileManager.get_light_r(pos.x + x, pos.y + y)
				#var curr_g := TileManager.get_light_g(pos.x + x, pos.y + y)
				#var curr_b := TileManager.get_light_r(pos.x + x, pos.y + y)
				#
				#TileManager.set_light_r(
					#pos.x + x, pos.y + y,
					#mini(floori(curr_r + r * distance_mod), MAX_LIGHT_LEVEL)
				#)
				#TileManager.set_light_g(
					#pos.x + x, pos.y + y,
					#mini(floori(curr_g + g * distance_mod), MAX_LIGHT_LEVEL)
				#)
				#TileManager.set_light_b(
					#pos.x + x, pos.y + y,
					#mini(floori(curr_b + b * distance_mod), MAX_LIGHT_LEVEL)
				#)
	
	# send update
	send_region_update(start_x, start_y, start_x + width, start_y + height)

#endregion
