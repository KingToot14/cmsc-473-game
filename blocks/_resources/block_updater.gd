class_name BlockUpdater
extends Node

# --- Variables --- #
const PHYSICS_TICKS := 60
const CYCLES := 10.0
const QUEUE_SLICE := 1.0 / CYCLES

var update_queue: Array[Vector2i] = []
var index := 0

# - Dirt Growing
const GRASS_GROWTH_RATE := 1.0 / (60.0 * PHYSICS_TICKS / CYCLES)

# --- Functions --- #
func _ready() -> void:
	Globals.block_updater = self
	
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	var width := maxi(1, ceili(len(update_queue) * QUEUE_SLICE))
	
	for i in range(index, index + width):
		if i >= len(update_queue):
			continue
		
		handle_update(i, update_queue[i])
	
	# update index
	index += width
	
	if index >= CYCLES and index >= len(update_queue):
		index = 0

#region Adding to Queue
func add_to_queue(position: Vector2i) -> void:
	var block_id := TileManager.get_block_unsafe(position.x, position.y)
	
	match block_id:
		# dirt block
		2:
			# check for grass
			if not TileManager.has_block_neighbor(position.x, position.y, 1):
				remove_position_from_queue(position)
				return
			
			# check for air
			if not TileManager.has_block_neighbor(position.x, position.y, 0):
				remove_position_from_queue(position)
				return
			
			# add to queue
			update_queue.append(position)
		# falling blocks (sand)
		8:
			# check for block below
			if TileManager.get_block(position.x, position.y + 1) != 0:
				return
			
			# set to air
			TileManager.set_block_unsafe(position.x, position.y, 0)
			TileManager.send_tile_update(position.x, position.y)
			
			# create falling block
			FallingBlockEntity.spawn(position, block_id)

func handle_update(pos_index: int, position: Vector2i) -> void:
	var block_id := TileManager.get_block_unsafe(position.x, position.y)
	
	match block_id:
		# dirt block
		2:
			# attempt to grow into grass
			if randf() < GRASS_GROWTH_RATE:
				remove_from_queue(pos_index)
				
				# set to grass
				TileManager.set_block_unsafe(position.x, position.y, 1)
				TileManager.send_tile_update(position.x, position.y)
		_:
			remove_from_queue(pos_index)

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

#region Odds
func get_odds_for_seconds(seconds: int) -> float:
	return 1.0 / (seconds * PHYSICS_TICKS / CYCLES)

#endregion
