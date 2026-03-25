class_name LightUpdater
extends Node

# --- Signals --- #
signal propagated()

# --- Variables --- #
const UPDATE_TIME := 0.05
const MAX_UPDATES_PER_FRAME := 300

const MAX_LIGHT_LEVEL := 255
const AIR_FALLOFF := 16
const BLOCK_FALLOFF := 32
const WALL_FALLOFF := 16
const WATER_FALLOFF := 16

var active := false

var update_timer := 0.0
var active_tiles: Dictionary[Vector2i, bool] = {}
var updated_tiles: Dictionary[Vector2i, int]

# --- Functions --- #
func _ready() -> void:
	Globals.light_updater = self

#region Queue Management
func add_to_queue(position: Vector2i, light_level := -1) -> void:
	if light_level == -1:
		light_level = TileManager.get_light_level(position.x, position.y)
	
	if not active and light_level == 0:
		return
	
	active_tiles[position] = true
	
	queue_update(position.x, position.y, light_level)

func remove_from_queue(position: Vector2i, light_level := -1) -> void:
	active_tiles.erase(position)
	
	if light_level == -1:
		light_level = TileManager.get_light_level(position.x, position.y)
	
	queue_update(position.x, position.y, light_level)

#endregion

#region Simulation
func update_region(start_x: int, start_y: int, width: int, height: int) -> void:
	var queue: Dictionary[Vector2i, bool] = {}
	
	# re-seed region
	for y in range(height):
		for x in range(width):
			var wx = start_x + x
			var wy = start_y + y
			
			# check for surface-level empty tiles
			if wy < Globals.underground and \
				TileManager.get_block(wx, wy) == 0 and TileManager.get_wall(wx, wy) == 0 and \
				TileManager.get_water_level(wx, wy) < 200:
				
				TileManager.set_light_level(wx, wy, MAX_LIGHT_LEVEL)
				queue[Vector2i(wx, wy)] = true
			else:
				TileManager.set_light_level(wx, wy, 0)
	
	propagate_region(queue, start_x, start_y, start_x + width, start_y + height)

func handle_update(pos: Vector2i) -> void:
	var light_level := TileManager.get_light_level(pos.x, pos.y)
	
	spread_to(pos + Vector2i( 1,  0), light_level)
	spread_to(pos + Vector2i( 0,  1), light_level)
	spread_to(pos + Vector2i(-1,  0), light_level)
	spread_to(pos + Vector2i( 0, -1), light_level)
	
	remove_from_queue(pos)

func spread_to(pos: Vector2i, light_level: int) -> void:
	# check bounds
	if pos.x < 0 or pos.x > Globals.world_size.x:
		return
	if pos.y < 0 or pos.y > Globals.world_size.y:
		return
	
	var curr_level := TileManager.get_light_level(pos.x, pos.y)
	
	# falloff
	if TileManager.get_block(pos.x, pos.y) == 0:
		light_level -= AIR_FALLOFF
		
		if TileManager.get_wall(pos.x, pos.y) != 0:
			light_level -= WALL_FALLOFF
		if TileManager.get_water_level(pos.x, pos.y) > 200:
			light_level -= WATER_FALLOFF
	else:
		light_level -= BLOCK_FALLOFF
	
	if light_level > curr_level:
		TileManager.set_light_level(pos.x, pos.y, light_level)
		add_to_queue(pos, light_level)

func spread_to_queue(queue: Dictionary[Vector2i, bool], pos: Vector2i, light_level: int) -> void:
	# check bounds
	if pos.x < 0 or pos.x > Globals.world_size.x:
		return
	if pos.y < 0 or pos.y > Globals.world_size.y:
		return
	
	var curr_level := TileManager.get_light_level(pos.x, pos.y)
	
	# falloff
	if TileManager.get_block(pos.x, pos.y) == 0:
		light_level -= AIR_FALLOFF
		
		if TileManager.get_wall(pos.x, pos.y) != 0:
			light_level -= WALL_FALLOFF
		if TileManager.get_water_level(pos.x, pos.y) > 200:
			light_level -= WATER_FALLOFF
	else:
		light_level -= BLOCK_FALLOFF
	
	if light_level > curr_level:
		TileManager.set_light_level(pos.x, pos.y, light_level)
		queue[pos] = true

#endregion

#region Updating
func queue_update(x: int, y: int, light_level: int) -> void:
	if not active:
		return
	
	updated_tiles[Vector2i(x, y)] = light_level

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
				
				buffer.put_u8(TileManager.get_light_level(x, y))
				
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

#region Initial Pass
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
		queue: Dictionary[Vector2i, bool], start_x: int, start_y: int, end_x: int, end_y: int
	) -> void:
	
	while not queue.is_empty():
		for tile: Vector2i in queue.keys():
			# handle update
			var light_level := TileManager.get_light_level(tile.x, tile.y)
			
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1) ,Vector2i(0, -1)]:
				var nx := tile.x + offset.x
				var ny := tile.y + offset.y
				
				# only update inside region
				if nx < start_x or nx > end_x:
					continue
				if ny < start_y or ny > end_y:
					continue
				
				spread_to_queue(queue, Vector2i(nx, ny), light_level)
			
			queue.erase(tile)
	
	# send update
	send_region_update(start_x, start_y, end_x, end_y)

#endregion
