class_name WaterUpdater
extends Node

# --- Variables --- #
const UPDATE_TIME := 0.05
const MAX_UPDATES_PER_FRAME := 200
const MAX_WATER_LEVEL := 255

var update_timer := 0.0
var active_tiles: Dictionary[Vector2i, bool] = {}
var updated_tiles: Dictionary[Vector2i, bool]

# --- Functions --- #
func _ready() -> void:
	Globals.water_updater = self
	
	set_physics_process(false)

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
		
		# make sure tile still exists
		if tile not in active_tiles:
			continue
		
		handle_update(tile)
		
		# update counter
		processed += 1
		index += 1
		
		if processed >= MAX_UPDATES_PER_FRAME:
			await get_tree().process_frame
			processed = 0
	
	# update timer
	update_timer = UPDATE_TIME
	
	# send batched update
	send_update()

#region Adding to Queue
func add_to_queue(position: Vector2i) -> void:
	active_tiles[position] = true
	
	queue_update(position.x, position.y)

func remove_from_queue(position: Vector2i) -> void:
	active_tiles.erase(position)
	
	queue_update(position.x, position.y)

func handle_update(position: Vector2i) -> void:
	var water_level := TileManager.get_water_level(position.x, position.y)
	var start_level := water_level
	
	# remove dry tiles
	if water_level <= 0:
		remove_from_queue(position)
		return
	
	# check downward flow
	if position.y < Globals.world_size.y - 1:
		water_level = flow_down(position.x, position.y, water_level)
	
	# check side flow
	if water_level > 0:
		water_level = flow_side(position.x, position.y, water_level)
	else:
		remove_from_queue(position)
		return
	
	# remove tiles when not updated
	if water_level == start_level:
		remove_from_queue(position)

func flow_down(x: int, y: int, water_level: int) -> int:
	# check if tile below is solid
	if TileManager.get_block(x, y + 1) != 0:
		return water_level
	
	# move as much as possible
	var bottom_water_level := TileManager.get_water_level(x, y + 1)
	var available_space := MAX_WATER_LEVEL - bottom_water_level
	
	# move as much as possible (limited by space or water level)
	var diff = mini(available_space, water_level)
	
	water_level -= diff
	
	# update water level
	TileManager.set_water_level(x, y, water_level)
	TileManager.set_water_level(x, y + 1, bottom_water_level + diff)
	
	# queue updates
	queue_update(x, y)
	
	add_to_queue(Vector2i(x, y + 1))
	
	return water_level

func flow_side(x: int, y: int, water_level: int) -> int:
	var can_flow_left_1 := TileManager.get_block(x - 1, y) == 0
	var can_flow_right_1 := TileManager.get_block(x + 1, y) == 0
	
	# try to flow to nearest neighbors
	if can_flow_left_1 and can_flow_right_1:
		var can_flow_left_2 := TileManager.get_block(x - 2, y) == 0
		var can_flow_right_2 := TileManager.get_block(x + 2, y) == 0
		
		# try to flow to next neighbors
		if can_flow_left_2 and can_flow_right_2:
			var can_flow_left_3 := TileManager.get_block(x - 3, y) == 0
			var can_flow_right_3 := TileManager.get_block(x + 3, y) == 0
			
			# try to flow to next neighbors
			if can_flow_left_3 and can_flow_right_3:
				var average := floori((
					water_level +
					TileManager.get_water_level(x - 1, y) +
					TileManager.get_water_level(x + 1, y) +
					TileManager.get_water_level(x - 2, y) +
					TileManager.get_water_level(x + 2, y) +
					TileManager.get_water_level(x - 3, y) +
					TileManager.get_water_level(x + 3, y)
				) / 7.0)
				
				# update water level
				TileManager.set_water_level(x, y, average)
				TileManager.set_water_level(x - 1, y, average)
				TileManager.set_water_level(x + 1, y, average)
				TileManager.set_water_level(x - 2, y, average)
				TileManager.set_water_level(x + 2, y, average)
				TileManager.set_water_level(x - 3, y, average)
				TileManager.set_water_level(x + 3, y, average)
				
				# queue updates
				queue_update(x, y)
				
				# re-add tiles to queue
				add_to_queue(Vector2i(x - 1, y))
				add_to_queue(Vector2i(x + 1, y))
				add_to_queue(Vector2i(x - 2, y))
				add_to_queue(Vector2i(x + 2, y))
				add_to_queue(Vector2i(x - 3, y))
				add_to_queue(Vector2i(x + 3, y))
			else:
				var average := floori((
					water_level +
					TileManager.get_water_level(x - 1, y) +
					TileManager.get_water_level(x + 1, y) +
					TileManager.get_water_level(x - 2, y) +
					TileManager.get_water_level(x + 2, y)
				) / 5.0)
				
				# update water level
				TileManager.set_water_level(x, y, average)
				TileManager.set_water_level(x - 1, y, average)
				TileManager.set_water_level(x + 1, y, average)
				TileManager.set_water_level(x - 2, y, average)
				TileManager.set_water_level(x + 2, y, average)
				
				# queue updates
				queue_update(x, y)
				
				# re-add tiles to queue
				add_to_queue(Vector2i(x - 1, y))
				add_to_queue(Vector2i(x + 1, y))
				add_to_queue(Vector2i(x - 2, y))
				add_to_queue(Vector2i(x + 2, y))
		else:
			var average := floori((
				water_level +
				TileManager.get_water_level(x - 1, y) +
				TileManager.get_water_level(x + 1, y)
			) / 3.0)
			
			# update water level
			TileManager.set_water_level(x, y, average)
			TileManager.set_water_level(x - 1, y, average)
			TileManager.set_water_level(x + 1, y, average)
			
			# queue updates
			queue_update(x, y)
			
			# re-add tiles to queue
			add_to_queue(Vector2i(x - 1, y))
			add_to_queue(Vector2i(x + 1, y))
	
	return water_level

#endregion

#region Updating
func queue_update(x: int, y: int) -> void:
	updated_tiles[Vector2i(x, y)] = true

func send_update() -> void:
	var update_size := len(updated_tiles)
	
	if update_size == 0:
		return
	
	# build buffer
	var buffer := StreamPeerBuffer.new()
	buffer.resize(1 + update_size * 5)
	
	buffer.put_u16(update_size)
	
	for tile: Vector2i in updated_tiles:
		buffer.put_u16(tile.x)
		buffer.put_u16(tile.y)
		
		buffer.put_u8(TileManager.get_water_level(tile.x, tile.y))
	
	TileManager.send_water_update(buffer.data_array)

#endregion
