class_name WaterUpdater
extends Node

# --- Signals --- #
signal settled()

# --- Variables --- #
const UPDATE_TIME := 0.05
const STABLE_UPDATE_FRAMES := 10

const MAX_UPDATES_PER_FRAME := 200
const MAX_WATER_LEVEL := 255

const SETTLE_SIGNIFICANCE := 2

var active := false

var update_timer := 0.0
var active_tiles: Dictionary[Vector2i, int] = {}
var updated_tiles: Dictionary[Vector2i, int]

# --- Functions --- #
func _ready() -> void:
	Globals.water_updater = self
	
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
func add_to_queue(position: Vector2i, water_level := -1) -> void:
	if water_level == -1:
		water_level = TileManager.get_water_level(position.x, position.y)
	
	if not active and water_level == 0:
		return
	
	active_tiles[position] = STABLE_UPDATE_FRAMES
	
	queue_update(position.x, position.y, water_level)

func remove_from_queue(position: Vector2i, water_level := -1) -> void:
	active_tiles.erase(position)
	
	if water_level == -1:
		water_level = TileManager.get_water_level(position.x, position.y)
	
	queue_update(position.x, position.y, water_level)

#endregion

#region Simulation
func handle_update(position: Vector2i) -> void:
	var water_level := TileManager.get_water_level(position.x, position.y)
	var start_level := water_level
	
	# remove dry tiles
	if water_level <= 0:
		TileManager.set_water_level(position.x, position.y, 0)
		remove_from_queue(position, water_level)
		return
	
	# check downward flow
	if position.y < Globals.world_size.y - 1:
		water_level = flow_down(position.x, position.y, water_level)
	
	# check side flow
	if water_level > 0:
		water_level = flow_side(position.x, position.y, water_level)
	else:
		TileManager.set_water_level(position.x, position.y, 0)
		remove_from_queue(position, water_level)
		return
	
	# remove tiles when not updated
	if water_level == start_level:
		active_tiles[position] -= 1
		
		if active_tiles[position] <= 0:
			if water_level <= SETTLE_SIGNIFICANCE:
				TileManager.set_water_level(position.x, position.y, 0)
			
			remove_from_queue(position, water_level)

func flow_down(x: int, y: int, water_level: int) -> int:
	# check if tile below is solid
	if TileManager.get_block(x, y + 1) != 0:
		return water_level
	
	# move as much as possible
	var bottom_water_level := TileManager.get_water_level(x, y + 1)
	var available_space := MAX_WATER_LEVEL - bottom_water_level
	
	# move as much as possible (limited by space or water level)
	var diff = mini(available_space, water_level)
	
	if diff == 0:
		return water_level
	
	water_level -= diff
	bottom_water_level += diff
	
	# update water level
	TileManager.set_water_level(x, y, water_level)
	TileManager.set_water_level(x, y + 1, bottom_water_level)
	
	# queue updates
	add_to_queue(Vector2i(x, y), water_level)
	add_to_queue(Vector2i(x, y + 1), bottom_water_level)
	add_to_queue(Vector2i(x, y - 1))
	
	return water_level

func flow_side(x: int, y: int, water_level: int) -> int:
	var can_flow_left_1 := TileManager.get_block(x - 1, y) == 0
	var can_flow_right_1 := TileManager.get_block(x + 1, y) == 0
	
	# add an average modifier that helps settle shallow puddles
	var puddle_mod := 0.0
	
	if water_level <= 4:
		puddle_mod = -1.0
	
	# try to flow to nearest neighbors
	if can_flow_left_1 and can_flow_right_1:
		# only flow more than one tile if tiles already contain water
		var can_flow_left_2 := TileManager.get_block(x - 2, y) == 0 \
			and TileManager.get_water_level(x - 2, y) > 0
		var can_flow_right_2 := TileManager.get_block(x + 2, y) == 0 \
			and TileManager.get_water_level(x + 2, y) > 0
		
		# try to flow to next neighbors
		if can_flow_left_2 and can_flow_right_2:
			# only flow more than one tile if tiles already contain water
			var can_flow_left_3 := TileManager.get_block(x - 3, y) == 0 \
				and TileManager.get_water_level(x - 3, y) > 0
			var can_flow_right_3 := TileManager.get_block(x + 3, y) == 0 \
				and TileManager.get_water_level(x + 3, y) > 0
			
			# try to flow to next neighbors
			if can_flow_left_3 and can_flow_right_3:
				# fetch water levels
				var water_level_left_1  := TileManager.get_water_level(x - 1, y)
				var water_level_left_2  := TileManager.get_water_level(x - 2, y)
				var water_level_left_3  := TileManager.get_water_level(x - 3, y)
				var water_level_right_1 := TileManager.get_water_level(x + 1, y)
				var water_level_right_2 := TileManager.get_water_level(x + 2, y)
				var water_level_right_3 := TileManager.get_water_level(x + 3, y)
				
				var average := roundi((
					water_level +
					water_level_left_1 +
					water_level_left_2 +
					water_level_left_3 +
					water_level_right_1 +
					water_level_right_2 +
					water_level_right_3 +
					puddle_mod
				) / 7.0)
				
				# update water levels
				if water_level != average:
					var diff := absi(water_level - average)
					TileManager.set_water_level(x, y, average)
					
					if diff > SETTLE_SIGNIFICANCE:
						add_to_queue(Vector2i(x, y), water_level)
				
				if water_level_left_1 != average:
					var diff := absi(water_level_left_1 - average)
					TileManager.set_water_level(x - 1, y, average)
					
					if diff > SETTLE_SIGNIFICANCE:
						add_to_queue(Vector2i(x - 1, y), water_level_left_1)
				
				if water_level_left_2 != average:
					var diff := absi(water_level_left_2 - average)
					TileManager.set_water_level(x - 2, y, average)
					
					if diff > SETTLE_SIGNIFICANCE:
						add_to_queue(Vector2i(x - 2, y), water_level_left_2)
				
				if water_level_left_3 != average:
					var diff := absi(water_level_left_3 - average)
					TileManager.set_water_level(x - 3, y, average)
					
					if diff > SETTLE_SIGNIFICANCE:
						add_to_queue(Vector2i(x - 3, y), water_level_left_3)
				
				if water_level_right_1 != average:
					var diff := absi(water_level_right_1 - average)
					TileManager.set_water_level(x + 1, y, average)
					
					if diff > SETTLE_SIGNIFICANCE:
						add_to_queue(Vector2i(x + 1, y), water_level_right_1)
				
				if water_level_right_2 != average:
					var diff := absi(water_level_right_2 - average)
					TileManager.set_water_level(x + 2, y, average)
					
					if diff > SETTLE_SIGNIFICANCE:
						add_to_queue(Vector2i(x + 2, y), water_level_right_2)
				
				if water_level_right_3 != average:
					var diff := absi(water_level_right_3 - average)
					TileManager.set_water_level(x + 3, y, average)
					
					if diff > SETTLE_SIGNIFICANCE:
						add_to_queue(Vector2i(x + 3, y), water_level_right_3)
			else:
				# fetch water levels
				var water_level_left_1  := TileManager.get_water_level(x - 1, y)
				var water_level_left_2  := TileManager.get_water_level(x - 2, y)
				var water_level_right_1 := TileManager.get_water_level(x + 1, y)
				var water_level_right_2 := TileManager.get_water_level(x + 2, y)
				
				var average := roundi((
					water_level +
					water_level_left_1 +
					water_level_left_2 +
					water_level_right_1 +
					water_level_right_2 +
					puddle_mod
				) / 5.0)
				
				# update water levels
				if water_level != average:
					var diff := absi(water_level - average)
					TileManager.set_water_level(x, y, average)
					
					if diff > SETTLE_SIGNIFICANCE:
						add_to_queue(Vector2i(x, y), water_level)
				
				if water_level_left_1 != average:
					var diff := absi(water_level_left_1 - average)
					TileManager.set_water_level(x - 1, y, average)
					
					if diff > SETTLE_SIGNIFICANCE:
						add_to_queue(Vector2i(x - 1, y), water_level_left_1)
				
				if water_level_left_2 != average:
					var diff := absi(water_level_left_2 - average)
					TileManager.set_water_level(x - 2, y, average)
					
					if diff > SETTLE_SIGNIFICANCE:
						add_to_queue(Vector2i(x - 2, y), water_level_left_2)
				
				if water_level_right_1 != average:
					var diff := absi(water_level_right_1 - average)
					TileManager.set_water_level(x + 1, y, average)
					
					if diff > SETTLE_SIGNIFICANCE:
						add_to_queue(Vector2i(x + 1, y), water_level_right_1)
				
				if water_level_right_2 != average:
					var diff := absi(water_level_right_2 - average)
					TileManager.set_water_level(x + 2, y, average)
					
					if diff > SETTLE_SIGNIFICANCE:
						add_to_queue(Vector2i(x + 2, y), water_level_right_2)
		elif can_flow_left_2:
			# fetch water levels
			var water_level_left_1  := TileManager.get_water_level(x - 1, y)
			var water_level_left_2  := TileManager.get_water_level(x - 2, y)
			var water_level_right_1 := TileManager.get_water_level(x + 1, y)
			
			var average := roundi((
				water_level +
				water_level_left_1 +
				water_level_left_2 +
				water_level_right_1 +
				puddle_mod
			) / 4.0)
			
			# update water levels
			if water_level != average:
				var diff := absi(water_level - average)
				TileManager.set_water_level(x, y, average)
				
				if diff > SETTLE_SIGNIFICANCE:
					add_to_queue(Vector2i(x, y), water_level)
			
			if water_level_left_1 != average:
				var diff := absi(water_level_left_1 - average)
				TileManager.set_water_level(x - 1, y, average)
				
				if diff > SETTLE_SIGNIFICANCE:
					add_to_queue(Vector2i(x - 1, y), water_level_left_1)
			
			if water_level_left_2 != average:
				var diff := absi(water_level_left_2 - average)
				TileManager.set_water_level(x - 2, y, average)
				
				if diff > SETTLE_SIGNIFICANCE:
					add_to_queue(Vector2i(x - 2, y), water_level_left_2)
			
			if water_level_right_1 != average:
				var diff := absi(water_level_right_1 - average)
				TileManager.set_water_level(x + 1, y, average)
				
				if diff > SETTLE_SIGNIFICANCE:
					add_to_queue(Vector2i(x + 1, y), water_level_right_1)
		elif can_flow_right_2:
			# fetch water levels
			var water_level_left_1  := TileManager.get_water_level(x - 1, y)
			var water_level_right_1 := TileManager.get_water_level(x + 1, y)
			var water_level_right_2 := TileManager.get_water_level(x + 2, y)
			
			var average := roundi((
				water_level +
				water_level_left_1 +
				water_level_right_1 +
				water_level_right_2 +
				puddle_mod
			) / 4.0)
			
			# update water levels
			if water_level != average:
				var diff := absi(water_level - average)
				TileManager.set_water_level(x, y, average)
				
				if diff > SETTLE_SIGNIFICANCE:
					add_to_queue(Vector2i(x, y), water_level)
			
			if water_level_left_1 != average:
				var diff := absi(water_level_left_1 - average)
				TileManager.set_water_level(x - 1, y, average)
				
				if diff > SETTLE_SIGNIFICANCE:
					add_to_queue(Vector2i(x - 1, y), water_level_left_1)
			
			if water_level_right_1 != average:
				var diff := absi(water_level_right_1 - average)
				TileManager.set_water_level(x + 1, y, average)
				
				if diff > SETTLE_SIGNIFICANCE:
					add_to_queue(Vector2i(x + 1, y), water_level_right_1)
			
			if water_level_right_2 != average:
				var diff := absi(water_level_right_2 - average)
				TileManager.set_water_level(x + 2, y, average)
				
				if diff > SETTLE_SIGNIFICANCE:
					add_to_queue(Vector2i(x + 2, y), water_level_right_2)
		else:
			# fetch water levels
			var water_level_left_1  := TileManager.get_water_level(x - 1, y)
			var water_level_right_1 := TileManager.get_water_level(x + 1, y)
			
			var average := roundi((
				water_level +
				water_level_left_1 +
				water_level_right_1 +
				puddle_mod
			) / 3.0)
			
			# update water levels
			if water_level != average:
				var diff := absi(water_level - average)
				TileManager.set_water_level(x, y, average)
				
				if diff > SETTLE_SIGNIFICANCE:
					add_to_queue(Vector2i(x, y), water_level)
			
			if water_level_left_1 != average:
				var diff := absi(water_level_left_1 - average)
				TileManager.set_water_level(x - 1, y, average)
				
				if diff > SETTLE_SIGNIFICANCE:
					add_to_queue(Vector2i(x - 1, y), water_level_left_1)
			
			if water_level_right_1 != average:
				var diff := absi(water_level_right_1 - average)
				TileManager.set_water_level(x + 1, y, average)
				
				if diff > SETTLE_SIGNIFICANCE:
					add_to_queue(Vector2i(x + 1, y), water_level_right_1)
	elif can_flow_left_1:
		# fetch water levels
		var water_level_left_1  := TileManager.get_water_level(x - 1, y)
		
		var average := roundi((
			water_level +
			water_level_left_1 +
			puddle_mod
		) / 2.0)
		
		# update water levels
		if water_level != average:
			var diff := absi(water_level - average)
			TileManager.set_water_level(x, y, average)
			
			if diff > SETTLE_SIGNIFICANCE:
				add_to_queue(Vector2i(x, y), water_level)
		
		if water_level_left_1 != average:
			var diff := absi(water_level_left_1 - average)
			TileManager.set_water_level(x - 1, y, average)
			
			if diff > SETTLE_SIGNIFICANCE:
				add_to_queue(Vector2i(x - 1, y), water_level_left_1)
	elif can_flow_right_1:
		# fetch water levels
		var water_level_right_1 := TileManager.get_water_level(x + 1, y)
		
		var average := roundi((
			water_level +
			water_level_right_1 +
			puddle_mod
		) / 2.0)
		
		# update water levels
		if water_level != average:
			var diff := absi(water_level - average)
			TileManager.set_water_level(x, y, average)
			
			if diff > SETTLE_SIGNIFICANCE:
				add_to_queue(Vector2i(x, y), water_level)
		
		if water_level_right_1 != average:
			var diff := absi(water_level_right_1 - average)
			TileManager.set_water_level(x + 1, y, average)
			
			if diff > SETTLE_SIGNIFICANCE:
				add_to_queue(Vector2i(x + 1, y), water_level_right_1)
	
	return water_level

#endregion

#region Updating
func queue_update(x: int, y: int, water_level: int) -> void:
	if not active:
		return
	
	updated_tiles[Vector2i(x, y)] = water_level

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
		
		buffer.put_u8(updated_tiles[tile])
	
	TileManager.send_water_update(buffer.data_array)

#endregion

#region Activity
func set_active() -> void:
	active = true
	set_process(true)

#endregion

#region Settling
func settle_all() -> void:
	var tiles := active_tiles.keys()
	
	while len(tiles) > 0:
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
		
		tiles = active_tiles.keys()
	
	settled.emit()

#endregion
