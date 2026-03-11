class_name WaterUpdater
extends Node

# --- Variables --- #
const PHYSICS_TICKS := 60
const CYCLES := 10.0
const QUEUE_SLICE := 1.0 / CYCLES

var update_queue: Array[Vector2i] = []
var index := 0

# --- Functions --- #
func _ready() -> void:
	Globals.water_updater = self
	
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	var width := maxi(1, ceili(len(update_queue) * QUEUE_SLICE))
	
	for i in range(index, index + width):
		if i >= len(update_queue):
			break
		
		handle_update(i, update_queue[i])
	
	# update index
	index += width
	
	if index >= CYCLES and index >= len(update_queue):
		index = 0

#region Adding to Queue
func add_to_queue(position: Vector2i) -> void:
	# don't re-add if already in queue
	if position in update_queue:
		return
	
	update_queue.append(position)

func handle_update(pos_index: int, position: Vector2i) -> void:
	var water_level := TileManager.get_water_level(position.x, position.y)
	
	# remove dry tiles
	if water_level <= 0:
		remove_from_queue(pos_index)
		return
	
	# check downward flow
	if position.y < Globals.world_size.y - 1:
		water_level = flow_down(position.x, position.y, water_level)
	
	# check side flow
	if water_level > 0:
		water_level = flow_side(position.x, position.y, water_level)
	else:
		remove_from_queue(pos_index)

func flow_down(x: int, y: int, water_level: int) -> int:
	# check if tile below is solid
	if TileManager.get_block(x, y + 1) != 0:
		return water_level
	
	# move as much as possible
	var bottom_water_level := TileManager.get_water_level(x, y + 1)
	var available_space := 255 - bottom_water_level
	
	# move as much as possible (limited by space or water level)
	var diff = mini(available_space, water_level)
	
	water_level -= diff
	
	# update water level
	add_to_queue(Vector2i(x, y + 1))
	
	TileManager.set_water_level(x, y, water_level)
	TileManager.set_water_level(x, y + 1, bottom_water_level + diff)
	
	TileManager.send_tile_update(x, y)
	TileManager.send_tile_update(x, y + 1)
	
	return water_level

func flow_side(x: int, y: int, water_level: int) -> int:
	var left_solid := TileManager.get_block(x - 1, y) != 0
	var right_solid := TileManager.get_block(x + 1, y) != 0
	
	# don't process if can't flow
	if left_solid and right_solid:
		return water_level
	
	# flow left
	if right_solid:
		var left_level := TileManager.get_water_level(x - 1, y)
		var average := ceili((water_level + left_level) / 2.0)
		
		TileManager.set_water_level(x, y, average)
		TileManager.set_water_level(x - 1, y, average)
		
		TileManager.send_tile_update(x, y)
		TileManager.send_tile_update(x - 1, y)
		
		add_to_queue(Vector2i(x - 1, y))
		
		return average
	# flow right
	elif left_solid:
		var right_level := TileManager.get_water_level(x + 1, y)
		var average := ceili((water_level + right_level) / 2.0)
		
		TileManager.set_water_level(x, y, average)
		TileManager.set_water_level(x + 1, y, average)
		
		TileManager.send_tile_update(x, y)
		TileManager.send_tile_update(x + 1, y)
		
		add_to_queue(Vector2i(x + 1, y))
		
		return average
	# flow both
	else:
		var left_level := TileManager.get_water_level(x - 1, y)
		var right_level := TileManager.get_water_level(x + 1, y)
		var average := ceili((water_level + left_level + right_level) / 3.0)
		
		TileManager.set_water_level(x, y, average)
		TileManager.set_water_level(x - 1, y, average)
		TileManager.set_water_level(x + 1, y, average)
		
		TileManager.send_tile_update(x, y)
		TileManager.send_tile_update(x - 1, y)
		TileManager.send_tile_update(x + 1, y)
		
		add_to_queue(Vector2i(x - 1, y))
		add_to_queue(Vector2i(x + 1, y))
		
		return average

#endregion

#region Removing From Queue
func remove_from_queue(pos_index: int) -> void:
	if pos_index == len(update_queue) - 1:
		update_queue.pop_back()
		return
	
	# replace with last
	update_queue[pos_index] = update_queue.pop_back()

func remove_position_from_queue(position: Vector2i) -> void:
	for i in len(update_queue):
		if update_queue[i] != position:
			continue
		
		remove_from_queue(i)
		return

#endregion
