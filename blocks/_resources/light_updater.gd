class_name LightUpdater
extends Node

# --- Signals --- #
signal propagated()

# --- Variables --- #
const UPDATE_TIME := 0.05
const MAX_UPDATES_PER_FRAME := 300

const MAX_LIGHT_LEVEL := 255
const AIR_FALLOFF := 10
const BLOCK_FALLOFF := 40
const WALL_FALLOFF := 20

var active := false

var update_timer := 0.0
var active_tiles: Dictionary[Vector2i, bool] = {}
var updated_tiles: Dictionary[Vector2i, int]

# --- Functions --- #
func _ready() -> void:
	Globals.light_updater = self
	
	set_process(false)

func _process(delta: float) -> void:
	update_timer -= delta
	
	# wait for timer to be empty
	if update_timer > 0.0:
		return
	
	# do update
	var tiles := active_tiles.keys()
	updated_tiles = {}
	
	var index := 0
	var processed := 0
	
	# process as many tiles as possible
	while index < len(tiles):
		var tile: Vector2i = tiles[index] 
		
		# update counter
		processed += 1
		index += 1
		
		# make sure tile still exists
		if tile not in active_tiles:
			continue
		
		handle_update(tile)
		
		if processed >= MAX_UPDATES_PER_FRAME:
			await get_tree().process_frame
			processed = 0
	
	# update timer
	update_timer = UPDATE_TIME
	
	# send batched update
	send_update()

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
	else:
		light_level -= BLOCK_FALLOFF
	
	if light_level > curr_level:
		TileManager.set_light_level(pos.x, pos.y, light_level)
		add_to_queue(pos, light_level)

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

#endregion

#region Initial Pass
func propagate_all() -> void:
	var tiles := active_tiles.keys()
	var total_runs := 0
	
	while len(tiles) > 0 and total_runs < 100:
		var index := 0
		var processed := 0
		total_runs += 1
		
		print(len(tiles))
		
		# process as many tiles as possible
		while index < len(tiles):
			var tile: Vector2i = tiles[index]
			
			# update counter
			processed += 1
			index += 1
			
			# make sure tile still exists
			if tile not in active_tiles:
				continue
			
			handle_update(tile)
		
		tiles = active_tiles.keys()
	
	propagated.emit()

#endregion
