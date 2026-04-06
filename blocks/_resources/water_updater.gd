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

const WATER_TYPE := 1
const LAVA_TYPE := 2

var active := false

var update_timer := 0.0
var active_tiles: Dictionary[Vector2i, int] = {}
var updated_tiles: Dictionary[Vector2i, int]

# --- Functions --- #
func _ready() -> void:
	Globals.liquid_updater = self
	
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
		index += 1
		
		# make sure tile still exists
		if tile not in active_tiles:
			continue
		
		handle_update(tile)
		
		# update processed
		processed += 1
		
		if processed >= MAX_UPDATES_PER_FRAME:
			await get_tree().process_frame
			processed = 0
	
	# update timer
	update_timer = UPDATE_TIME
	
	# send batched update
	send_update()

#region Queue Management
func add_to_queue(position: Vector2i, liquid_level := -1) -> void:
	if liquid_level == -1:
		liquid_level = TileManager.get_liquid_level(position.x, position.y)
	
	if not active and liquid_level == 0:
		return
	
	active_tiles[position] = STABLE_UPDATE_FRAMES
	
	queue_update(position.x, position.y, liquid_level)

func remove_from_queue(position: Vector2i, liquid_level := -1) -> void:
	active_tiles.erase(position)
	
	if liquid_level == -1:
		liquid_level = TileManager.get_liquid_level(position.x, position.y)
	
	queue_update(position.x, position.y, liquid_level)

#endregion

#region Simulation
func handle_update(position: Vector2i) -> void:
	var liquid_level := TileManager.get_liquid_level(position.x, position.y)
	var liquid_type := TileManager.get_liquid_type(position.x, position.y)
	var start_level := liquid_level
	
	# remove dry tiles
	if liquid_level <= 0:
		TileManager.set_liquid_level(position.x, position.y, 0)
		TileManager.set_liquid_type(position.x, position.y, 0)
		remove_from_queue(position, liquid_level)
		return
	
	# check downward flow
	if position.y < Globals.world_size.y - 1:
		liquid_level = flow_down(position.x, position.y, liquid_level, liquid_type)
	
	# check side flow
	if liquid_level > 0:
		liquid_level = flow_side(position.x, position.y, liquid_level, liquid_type)
	else:
		TileManager.set_liquid_level(position.x, position.y, 0)
		TileManager.set_liquid_type(position.x, position.y, 0)
		remove_from_queue(position, liquid_level)
		return
	
	# remove tiles when not updated
	if liquid_level == start_level:
		active_tiles[position] -= 1
		
		if active_tiles[position] <= 0:
			if liquid_level <= SETTLE_SIGNIFICANCE:
				TileManager.set_liquid_level(position.x, position.y, 0)
				TileManager.set_liquid_type(position.x, position.y, 0)
			
			remove_from_queue(position, liquid_level)

func handle_liquid_interaction(x: int, y: int, liquid_state: int) -> void:
	match liquid_state:
		WATER_TYPE + LAVA_TYPE:
			# set block to obsidian
			TileManager.set_block(x, y, 94)
			TileManager.set_liquid_level(x, y, 0)
			TileManager.set_liquid_type(x, y, 0)

func flow_down(x: int, y: int, liquid_level: int, liquid_type: int) -> int:
	# check if tile below is solid
	if TileManager.get_block(x, y + 1) != 0:
		return liquid_level
	
	# check target type
	var bottom_type := TileManager.get_liquid_type(x, y + 1)
	
	if bottom_type > 0 and bottom_type != liquid_type:
		handle_liquid_interaction(x, y + 1, bottom_type + liquid_type)
		
		var new_level := liquid_level - 16
		
		if new_level <= 0:
			TileManager.set_water_level(x, y, 0)
			TileManager.set_water_type(x, y, 0)
			
			remove_from_queue(Vector2i(x, y), 0)
		else:
			TileManager.set_water_level(x, y, new_level)
			
			add_to_queue(Vector2i(x, y), liquid_level)
		
		remove_from_queue(Vector2i(x, y + 1), 0)
		
		return maxi(0, new_level)
	
	# move as much as possible
	var bottom_liquid_level := TileManager.get_liquid_level(x, y + 1)
	var available_space := MAX_WATER_LEVEL - bottom_liquid_level
	
	# move as much as possible (limited by space or water level)
	var diff = mini(available_space, liquid_level)
	
	if diff == 0:
		return liquid_level
	
	liquid_level -= diff
	bottom_liquid_level += diff
	
	# update water level
	TileManager.set_liquid_level(x, y, liquid_level)
	TileManager.set_liquid_level(x, y + 1, bottom_liquid_level)
	TileManager.set_liquid_type(x, y + 1, liquid_type)
	
	# queue updates
	add_to_queue(Vector2i(x, y), liquid_level)
	add_to_queue(Vector2i(x, y + 1), bottom_liquid_level)
	add_to_queue(Vector2i(x, y - 1))
	
	return liquid_level

func flow_side(x: int, y: int, liquid_level: int, liquid_type: int) -> int:
	var can_flow_left_1 := TileManager.get_block(x - 1, y) == 0 and (x - 1) >= 0
	var can_flow_right_1 := TileManager.get_block(x + 1, y) == 0 and (x + 1) < Globals.world_size.x
	
	# check for liquid interactions
	var left_type := TileManager.get_liquid_type(x - 1, y)
	if left_type > 0 and left_type != liquid_type:
		handle_liquid_interaction(x - 1, y, left_type + liquid_type)
		liquid_level = maxi(0, liquid_level - 16)
		
		can_flow_left_1 = false
		
		if liquid_level == 0:
			remove_from_queue(Vector2i(x, y))
			return liquid_level
	
	var right_type := TileManager.get_liquid_type(x + 1, y)
	if right_type > 0 and right_type != liquid_type:
		handle_liquid_interaction(x + 1, y, right_type + liquid_type)
		liquid_level = maxi(0, liquid_level - 16)
		
		can_flow_right_1 = false
		
		if liquid_level == 0:
			remove_from_queue(Vector2i(x, y))
			return liquid_level
	
	# add an average modifier that helps settle shallow puddles
	var puddle_mod := 0.0
	var settle_mod := SETTLE_SIGNIFICANCE
	
	if not active:
		settle_mod *= 4
	
	if liquid_level <= 4:
		puddle_mod = -1.0
	
	# try to flow to nearest neighbors
	if can_flow_left_1 and can_flow_right_1:
		# only flow more than one tile if tiles already contain water
		var can_flow_left_2 := TileManager.get_block(x - 2, y) == 0 \
			and TileManager.get_liquid_level(x - 2, y) > 0 and (x - 2) >= 0
		var can_flow_right_2 := TileManager.get_block(x + 2, y) == 0 \
			and TileManager.get_liquid_level(x + 2, y) > 0 and (x + 2) < Globals.world_size.x
		
		# check for liquid interactions
		left_type = TileManager.get_liquid_type(x - 2, y)
		if left_type > 0 and left_type != liquid_type:
			handle_liquid_interaction(x - 2, y, left_type + liquid_type)
			liquid_level = maxi(0, liquid_level - 16)
			
			can_flow_left_2 = false
			
			if liquid_level == 0:
				remove_from_queue(Vector2i(x, y))
				return liquid_level
		
		right_type = TileManager.get_liquid_type(x + 2, y)
		if right_type > 0 and right_type != liquid_type:
			handle_liquid_interaction(x + 2, y, right_type + liquid_type)
			liquid_level = maxi(0, liquid_level - 16)
			
			can_flow_right_2 = false
			
			if liquid_level == 0:
				remove_from_queue(Vector2i(x, y))
				return liquid_level
		
		# try to flow to next neighbors
		if can_flow_left_2 and can_flow_right_2:
			# only flow more than one tile if tiles already contain water
			var can_flow_left_3 := TileManager.get_block(x - 3, y) == 0 \
				and TileManager.get_liquid_level(x - 3, y) > 0 and (x - 3) >= 0
			var can_flow_right_3 := TileManager.get_block(x + 3, y) == 0 \
				and TileManager.get_liquid_level(x + 3, y) > 0 and (x + 3) < Globals.world_size.x
			
			# check for liquid interactions
			left_type = TileManager.get_liquid_type(x - 3, y)
			if left_type > 0 and left_type != liquid_type:
				handle_liquid_interaction(x - 3, y, left_type + liquid_type)
				liquid_level = maxi(0, liquid_level - 16)
				
				can_flow_left_3 = false
				
				if liquid_level == 0:
					remove_from_queue(Vector2i(x, y))
					return liquid_level
			
			right_type = TileManager.get_liquid_type(x + 3, y)
			if right_type > 0 and right_type != liquid_type:
				handle_liquid_interaction(x + 3, y, right_type + liquid_type)
				liquid_level = maxi(0, liquid_level - 16)
				
				can_flow_right_3 = false
				
				if liquid_level == 0:
					remove_from_queue(Vector2i(x, y))
					return liquid_level
			
			# try to flow to next neighbors
			if can_flow_left_3 and can_flow_right_3:
				# fetch water levels
				var liquid_level_left_1  := TileManager.get_liquid_level(x - 1, y)
				var liquid_level_left_2  := TileManager.get_liquid_level(x - 2, y)
				var liquid_level_left_3  := TileManager.get_liquid_level(x - 3, y)
				var liquid_level_right_1 := TileManager.get_liquid_level(x + 1, y)
				var liquid_level_right_2 := TileManager.get_liquid_level(x + 2, y)
				var liquid_level_right_3 := TileManager.get_liquid_level(x + 3, y)
				
				var average := roundi((
					liquid_level +
					liquid_level_left_1 +
					liquid_level_left_2 +
					liquid_level_left_3 +
					liquid_level_right_1 +
					liquid_level_right_2 +
					liquid_level_right_3 +
					puddle_mod
				) / 7.0)
				
				# update water levels
				if liquid_level != average:
					var diff := absi(liquid_level - average)
					TileManager.set_liquid_level(x, y, average)
					TileManager.set_liquid_type(x, y, liquid_type)
					
					if diff > settle_mod:
						add_to_queue(Vector2i(x, y), liquid_level)
				
				if liquid_level_left_1 != average:
					var diff := absi(liquid_level_left_1 - average)
					TileManager.set_liquid_level(x - 1, y, average)
					TileManager.set_liquid_type(x - 1, y, liquid_type)
					
					if diff > settle_mod:
						add_to_queue(Vector2i(x - 1, y), liquid_level_left_1)
				
				if liquid_level_left_2 != average:
					var diff := absi(liquid_level_left_2 - average)
					TileManager.set_liquid_level(x - 2, y, average)
					TileManager.set_liquid_type(x - 2, y, liquid_type)
					
					if diff > settle_mod:
						add_to_queue(Vector2i(x - 2, y), liquid_level_left_2)
				
				if liquid_level_left_3 != average:
					var diff := absi(liquid_level_left_3 - average)
					TileManager.set_liquid_level(x - 3, y, average)
					TileManager.set_liquid_type(x - 3, y, liquid_type)
					
					if diff > settle_mod:
						add_to_queue(Vector2i(x - 3, y), liquid_level_left_3)
				
				if liquid_level_right_1 != average:
					var diff := absi(liquid_level_right_1 - average)
					TileManager.set_liquid_level(x + 1, y, average)
					TileManager.set_liquid_type(x + 1, y, liquid_type)
					
					if diff > settle_mod:
						add_to_queue(Vector2i(x + 1, y), liquid_level_right_1)
				
				if liquid_level_right_2 != average:
					var diff := absi(liquid_level_right_2 - average)
					TileManager.set_liquid_level(x + 2, y, average)
					TileManager.set_liquid_type(x + 2, y, liquid_type)
					
					if diff > settle_mod:
						add_to_queue(Vector2i(x + 2, y), liquid_level_right_2)
				
				if liquid_level_right_3 != average:
					var diff := absi(liquid_level_right_3 - average)
					TileManager.set_liquid_level(x + 3, y, average)
					TileManager.set_liquid_type(x + 3, y, liquid_type)
					
					if diff > settle_mod:
						add_to_queue(Vector2i(x + 3, y), liquid_level_right_3)
			else:
				# fetch water levels
				var liquid_level_left_1  := TileManager.get_liquid_level(x - 1, y)
				var liquid_level_left_2  := TileManager.get_liquid_level(x - 2, y)
				var liquid_level_right_1 := TileManager.get_liquid_level(x + 1, y)
				var liquid_level_right_2 := TileManager.get_liquid_level(x + 2, y)
				
				var average := roundi((
					liquid_level +
					liquid_level_left_1 +
					liquid_level_left_2 +
					liquid_level_right_1 +
					liquid_level_right_2 +
					puddle_mod
				) / 5.0)
				
				# update water levels
				if liquid_level != average:
					var diff := absi(liquid_level - average)
					TileManager.set_liquid_level(x, y, average)
					TileManager.set_liquid_type(x, y, liquid_type)
					
					if diff > settle_mod:
						add_to_queue(Vector2i(x, y), liquid_level)
				
				if liquid_level_left_1 != average:
					var diff := absi(liquid_level_left_1 - average)
					TileManager.set_liquid_level(x - 1, y, average)
					TileManager.set_liquid_type(x - 1, y, liquid_type)
					
					if diff > settle_mod:
						add_to_queue(Vector2i(x - 1, y), liquid_level_left_1)
				
				if liquid_level_left_2 != average:
					var diff := absi(liquid_level_left_2 - average)
					TileManager.set_liquid_level(x - 2, y, average)
					TileManager.set_liquid_type(x - 2, y, liquid_type)
					
					if diff > settle_mod:
						add_to_queue(Vector2i(x - 2, y), liquid_level_left_2)
				
				if liquid_level_right_1 != average:
					var diff := absi(liquid_level_right_1 - average)
					TileManager.set_liquid_level(x + 1, y, average)
					TileManager.set_liquid_type(x + 1, y, liquid_type)
					
					if diff > settle_mod:
						add_to_queue(Vector2i(x + 1, y), liquid_level_right_1)
				
				if liquid_level_right_2 != average:
					var diff := absi(liquid_level_right_2 - average)
					TileManager.set_liquid_level(x + 2, y, average)
					TileManager.set_liquid_type(x + 2, y, liquid_type)
					
					if diff > settle_mod:
						add_to_queue(Vector2i(x + 2, y), liquid_level_right_2)
		elif can_flow_left_2:
			# fetch water levels
			var liquid_level_left_1  := TileManager.get_liquid_level(x - 1, y)
			var liquid_level_left_2  := TileManager.get_liquid_level(x - 2, y)
			var liquid_level_right_1 := TileManager.get_liquid_level(x + 1, y)
			
			var average := roundi((
				liquid_level +
				liquid_level_left_1 +
				liquid_level_left_2 +
				liquid_level_right_1 +
				puddle_mod
			) / 4.0)
			
			# update water levels
			if liquid_level != average:
				var diff := absi(liquid_level - average)
				TileManager.set_liquid_level(x, y, average)
				TileManager.set_liquid_type(x, y, liquid_type)
				
				if diff > settle_mod:
					add_to_queue(Vector2i(x, y), liquid_level)
			
			if liquid_level_left_1 != average:
				var diff := absi(liquid_level_left_1 - average)
				TileManager.set_liquid_level(x - 1, y, average)
				TileManager.set_liquid_type(x - 1, y, liquid_type)
				
				if diff > settle_mod:
					add_to_queue(Vector2i(x - 1, y), liquid_level_left_1)
			
			if liquid_level_left_2 != average:
				var diff := absi(liquid_level_left_2 - average)
				TileManager.set_liquid_level(x - 2, y, average)
				TileManager.set_liquid_type(x - 2, y, liquid_type)
				
				if diff > settle_mod:
					add_to_queue(Vector2i(x - 2, y), liquid_level_left_2)
			
			if liquid_level_right_1 != average:
				var diff := absi(liquid_level_right_1 - average)
				TileManager.set_liquid_level(x + 1, y, average)
				TileManager.set_liquid_type(x + 1, y, liquid_type)
				
				if diff > settle_mod:
					add_to_queue(Vector2i(x + 1, y), liquid_level_right_1)
		elif can_flow_right_2:
			# fetch water levels
			var liquid_level_left_1  := TileManager.get_liquid_level(x - 1, y)
			var liquid_level_right_1 := TileManager.get_liquid_level(x + 1, y)
			var liquid_level_right_2 := TileManager.get_liquid_level(x + 2, y)
			
			var average := roundi((
				liquid_level +
				liquid_level_left_1 +
				liquid_level_right_1 +
				liquid_level_right_2 +
				puddle_mod
			) / 4.0)
			
			# update water levels
			if liquid_level != average:
				var diff := absi(liquid_level - average)
				TileManager.set_liquid_level(x, y, average)
				TileManager.set_liquid_type(x, y, liquid_type)
				
				if diff > settle_mod:
					add_to_queue(Vector2i(x, y), liquid_level)
			
			if liquid_level_left_1 != average:
				var diff := absi(liquid_level_left_1 - average)
				TileManager.set_liquid_level(x - 1, y, average)
				TileManager.set_liquid_type(x - 1, y, liquid_type)
				
				if diff > settle_mod:
					add_to_queue(Vector2i(x - 1, y), liquid_level_left_1)
			
			if liquid_level_right_1 != average:
				var diff := absi(liquid_level_right_1 - average)
				TileManager.set_liquid_level(x + 1, y, average)
				TileManager.set_liquid_type(x + 1, y, liquid_type)
				
				if diff > settle_mod:
					add_to_queue(Vector2i(x + 1, y), liquid_level_right_1)
			
			if liquid_level_right_2 != average:
				var diff := absi(liquid_level_right_2 - average)
				TileManager.set_liquid_level(x + 2, y, average)
				TileManager.set_liquid_type(x + 2, y, liquid_type)
				
				if diff > settle_mod:
					add_to_queue(Vector2i(x + 2, y), liquid_level_right_2)
		else:
			# fetch water levels
			var liquid_level_left_1  := TileManager.get_liquid_level(x - 1, y)
			var liquid_level_right_1 := TileManager.get_liquid_level(x + 1, y)
			
			var average := roundi((
				liquid_level +
				liquid_level_left_1 +
				liquid_level_right_1 +
				puddle_mod
			) / 3.0)
			
			# update water levels
			if liquid_level != average:
				var diff := absi(liquid_level - average)
				TileManager.set_liquid_level(x, y, average)
				TileManager.set_liquid_type(x, y, liquid_type)
				
				if diff > settle_mod:
					add_to_queue(Vector2i(x, y), liquid_level)
			
			if liquid_level_left_1 != average:
				var diff := absi(liquid_level_left_1 - average)
				TileManager.set_liquid_level(x - 1, y, average)
				TileManager.set_liquid_type(x - 1, y, liquid_type)
				
				if diff > settle_mod:
					add_to_queue(Vector2i(x - 1, y), liquid_level_left_1)
			
			if liquid_level_right_1 != average:
				var diff := absi(liquid_level_right_1 - average)
				TileManager.set_liquid_level(x + 1, y, average)
				TileManager.set_liquid_type(x + 1, y, liquid_type)
				
				if diff > settle_mod:
					add_to_queue(Vector2i(x + 1, y), liquid_level_right_1)
	elif can_flow_left_1:
		# fetch water levels
		var liquid_level_left_1  := TileManager.get_liquid_level(x - 1, y)
		
		var average := roundi((
			liquid_level +
			liquid_level_left_1 +
			puddle_mod
		) / 2.0)
		
		# update water levels
		if liquid_level != average:
			var diff := absi(liquid_level - average)
			TileManager.set_liquid_level(x, y, average)
			TileManager.set_liquid_type(x, y, liquid_type)
			
			if diff > settle_mod:
				add_to_queue(Vector2i(x, y), liquid_level)
		
		if liquid_level_left_1 != average:
			var diff := absi(liquid_level_left_1 - average)
			TileManager.set_liquid_level(x - 1, y, average)
			TileManager.set_liquid_type(x - 1, y, liquid_type)
			
			if diff > settle_mod:
				add_to_queue(Vector2i(x - 1, y), liquid_level_left_1)
	elif can_flow_right_1:
		# fetch water levels
		var liquid_level_right_1 := TileManager.get_liquid_level(x + 1, y)
		
		var average := roundi((
			liquid_level +
			liquid_level_right_1 +
			puddle_mod
		) / 2.0)
		
		# update water levels
		if liquid_level != average:
			var diff := absi(liquid_level - average)
			TileManager.set_liquid_level(x, y, average)
			TileManager.set_liquid_type(x, y, liquid_type)
			
			if diff > settle_mod:
				add_to_queue(Vector2i(x, y), liquid_level)
		
		if liquid_level_right_1 != average:
			var diff := absi(liquid_level_right_1 - average)
			TileManager.set_liquid_level(x + 1, y, average)
			TileManager.set_liquid_type(x + 1, y, liquid_type)
			
			if diff > settle_mod:
				add_to_queue(Vector2i(x + 1, y), liquid_level_right_1)
	
	return liquid_level

#endregion

#region Updating
func queue_update(x: int, y: int, liquid_level: int) -> void:
	if not active:
		return
	
	updated_tiles[Vector2i(x, y)] = liquid_level

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
			buffer.put_u8(TileManager.get_liquid_type(tile.x, tile.y))
		
		# only send data if necessary
		if updated == 0:
			continue
		
		# set update size
		var data := buffer.data_array
		data.encode_u16(0, updated)
		
		TileManager.send_liquid_update(player_id, data)

#endregion

#region Activity
func set_active() -> void:
	active = true
	set_process(true)

#endregion

#region Settling
func settle_all() -> void:
	var world_size := Globals.world_size
	
	# loop from bottom of the world to the top
	for y in range(world_size.y - 3, 3, -1):
		for x in range(3, world_size.x - 3):
			var liquid_level := TileManager.get_liquid_level(x, y)
			
			if liquid_level > SETTLE_SIGNIFICANCE:
				settle_tile(x, y, liquid_level)
	
	# add all non-surface water tiles to the update queue
	active_tiles = {}
	
	for y in range(3, world_size.y - 3):
		for x in range(3, world_size.x - 3):
			var liquid_level := TileManager.get_liquid_level(x, y)
			var top_level := TileManager.get_liquid_level(x, y - 1)
			var bottom_level := TileManager.get_liquid_level(x, y + 1)
			
			if liquid_level == 0:
				continue
			
			if top_level > 0 and bottom_level > 0:
				continue
			
			add_to_queue(Vector2i(x, y))
	
	# run a few simulations in order to smooth out some water
	var tiles := active_tiles.keys()
	var prev_tiles: Array[Vector2i]
	var settle_counter := 0
	
	while not tiles.is_empty():
		if prev_tiles == tiles:
			settle_counter += 1
		else:
			settle_counter = 0
		
		if settle_counter >= 8:
			break
		
		for i in range(len(tiles)):
			var tile: Vector2i = tiles[i]
			
			# make sure tile still exists
			if tile not in active_tiles:
				continue
			
			handle_update(tile)
		
		prev_tiles = tiles
		tiles = active_tiles.keys()
	
	settled.emit()

func settle_tile(x: int, y: int, liquid_level: int) -> void:
	var world_size := Globals.world_size
	
	# clear water level
	TileManager.set_liquid_level(x, y, 0)
	
	var ever_moved := false
	
	while true:
		var down_tile := TileManager.get_block_unsafe(x, y + 1)
		var down_level := TileManager.get_liquid_level(x, y + 1)
		
		#var curr_moved := false
		
		# find non-empty tile
		while y < world_size.y - 3 and down_level == 0 and down_tile == 0:
			ever_moved = true
			#curr_moved = true
			
			y += 1
			down_tile = TileManager.get_block_unsafe(x, y + 1)
			down_level = TileManager.get_liquid_level(x, y + 1)
		
		# initialize spread
		var dir := -1
		var dist := 0
		var applied_dir := -1
		var applied_dist := 0
		
		var touching_left := false
		var touching_right := false
		var should_loop := true
		
		while true:
			# keep spreading while empty
			if TileManager.get_liquid_level(x + dist * dir, y) == 0:
				applied_dir = dir
				applied_dist = dist
			
			# check bounds
			if dir == -1 and x + dist * dir < 3:
				touching_left = true
			elif dir == 1 and x + dist * dir > world_size.x - 3:
				touching_right = true
			
			down_tile = TileManager.get_block_unsafe(x + dist * dir, y + 1)
			down_level = TileManager.get_liquid_level(x + dist * dir, y + 1)
			
			# try to spread down
			if down_tile == 0 and down_level > 0 and down_level < MAX_WATER_LEVEL:
				var diff := MAX_WATER_LEVEL - down_level
				diff = mini(diff, liquid_level)
				
				# spread water
				down_level += diff
				liquid_level -= diff
				
				TileManager.set_liquid_level(x + dist * dir, y + 1, down_level)
				
				# stop if no liquid remains
				if liquid_level == 0:
					should_loop = false
					break
			
			# try to spread around
			if y > world_size.y - 3 or down_level != 0 or down_tile != 0:
				var next_tile := TileManager.get_block_unsafe(x + (dist + 1) * dir, y)
				var next_level := TileManager.get_liquid_level(x + (dist + 1) * dir, y)
				
				# check if next tile has liquid
				if next_level != 0 and (ever_moved or dir != 1) or next_tile != 0:
					if dir == 1:
						touching_right = true
					else:
						touching_left = true
				
				# check if we have touched both edges
				if not (touching_left and touching_right):
					if touching_right:
						dir = -1
						dist += 1
					elif touching_left:
						if dir == 1:
							dist += 1
						
						dir = 1
					else:
						if dir == 1:
							dist += 1
						
						dir = -dir
				else:
					should_loop = false
					break
			else:
				break
		
		x += applied_dist * applied_dir
		
		if liquid_level != 0 and should_loop:
			y += 1
		else:
			break
	
	# set final position
	TileManager.set_liquid_level(x, y, liquid_level)

#endregion
