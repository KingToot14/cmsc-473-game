@tool
class_name WorldChunk
extends Node2D

# --- Signals --- #
signal done_processing()

# --- Variables --- #
const CONNECTION_MAP = {
	  0: Vector2i(0, 0),   4: Vector2i(1, 0),   6: Vector2i(2, 0),    2: Vector2i(3, 0),
	 12: Vector2i(4, 0),  10: Vector2i(5, 0),  13: Vector2i(6, 0),   14: Vector2i(7, 0),
	 47: Vector2i(8, 0), 143: Vector2i(9, 0),  95: Vector2i(10, 0),  63: Vector2i(11, 0),
	
	  8: Vector2i(0, 1), 140: Vector2i(1, 1), 206: Vector2i(2, 1),   74: Vector2i(3, 1),
	  5: Vector2i(4, 1),   3: Vector2i(5, 1),   7: Vector2i(6, 1),   11: Vector2i(7, 1),
	 31: Vector2i(8, 1),  79: Vector2i(9, 1), 207: Vector2i(10, 1), 175: Vector2i(11, 1),
	
	  9: Vector2i(0, 2), 173: Vector2i(1, 2), 255: Vector2i(2, 2),   91: Vector2i(3, 2),
	141: Vector2i(4, 2),  78: Vector2i(5, 2),  45: Vector2i(6, 2),  142: Vector2i(7, 2),
	127: Vector2i(8, 2), 191: Vector2i(9, 2), 111: Vector2i(10, 2), 159: Vector2i(11, 2),
	
	  1: Vector2i(0, 3),  37: Vector2i(1, 3),  55: Vector2i(2, 3),   19: Vector2i(3, 3),
	 39: Vector2i(4, 3),  27: Vector2i(5, 3),  23: Vector2i(6, 3),   75: Vector2i(7, 3),
	223: Vector2i(8, 3), 239: Vector2i(9, 3), 15: Vector2i(10, 3)
}

@export var chunk_pos := -Vector2i.ONE

@export_tool_button("Randomize Chunk", "RandomNumberGenerator")
@warning_ignore("unused_private_class_variable")
var _dummy = _randomize_chunk

var processing := false

# --- Functions --- #
func _ready() -> void:
	Globals.world_map = self

#region Tile Management
func calculate_connections(x: int, y: int, is_wall := false) -> int:
	if x < 0 or x >= TileManager.CHUNK_SIZE or y < 0 or y >= TileManager.CHUNK_SIZE:
		return 0
	
	#var chunk = TileManager.get_chunk(chunk_pos.x, chunk_pos.y)
	var world_x = chunk_pos.x * TileManager.CHUNK_SIZE + x
	var world_y = chunk_pos.y * TileManager.CHUNK_SIZE + y
	
	# don't run on empty blocks
	if not is_wall and TileManager.get_block(world_x, world_y) <= 0:
		return 0
	
	# cardinal neighbors
	var value := 0
	var tile_tl: bool = TileManager.get_block(world_x - 1, world_y - 1) > 0
	var tile_tm: bool = TileManager.get_block(world_x - 0, world_y - 1) > 0
	var tile_tr: bool = TileManager.get_block(world_x + 1, world_y - 1) > 0
	var tile_ml: bool = TileManager.get_block(world_x - 1, world_y - 0) > 0
	var tile_mr: bool = TileManager.get_block(world_x + 1, world_y - 0) > 0
	var tile_bl: bool = TileManager.get_block(world_x - 1, world_y + 1) > 0
	var tile_bm: bool = TileManager.get_block(world_x - 0, world_y + 1) > 0
	var tile_br: bool = TileManager.get_block(world_x + 1, world_y + 1) > 0
	
	if tile_tm:
		value += 1
	if tile_ml:
		value += 2
	if tile_mr:
		value += 4
	if tile_bm:
		value += 8
	
	# diagonal neighbors
	if value & 1 and value & 2 and tile_tl:
		value += 16
	if value & 1 and value & 4 and tile_tr:
		value += 32
	if value & 8 and value & 2 and tile_bl:
		value += 64
	if value & 8 and value & 4 and tile_br:
		value += 128
	
	return value

#endregion

#region Chunk Management
func _randomize_chunk() -> void:
	var blocks: TileMapLayer = $'blocks'
	
	clear_chunk()
	
	for x in range(TileManager.CHUNK_SIZE):
		for y in range(TileManager.CHUNK_SIZE):
			if randf() > 0.6:
				continue
			
			blocks.set_cell(Vector2i(x, y), 2, Vector2i(0, 0))
			TileManager.set_block(x, y, 1)
	
	autotile_block_chunk()

func clear_chunk() -> void:
	$'walls'.clear()
	$'blocks'.clear()

func load_from_data() -> void:
	if chunk_pos == -Vector2i.ONE:
		return
	
	var chunk = TileManager.get_chunk(chunk_pos.x, chunk_pos.y)
	
	for x in range(TileManager.CHUNK_SIZE):
		for y in range(TileManager.CHUNK_SIZE):
			print(TileManager.get_block_in_chunk(chunk, x, y))

func autotile_region(start_x: int, start_y: int, width: int, height: int) -> void:
	# calculate variations
	var variations := PackedByteArray()
	variations.resize(width * height)
	var index := 0
	
	var prev := TileManager.get_row(start_x - 1, start_y - 1, width + 2)
	var curr := TileManager.get_row(start_x - 1, start_y + 0, width + 2)
	var next := TileManager.get_row(start_x - 1, start_y + 1, width + 2)
	
	for y in range(height):
		for x in range(1, width + 1):
			var value := 0
			
			# skip air
			if curr[x] <= 0:
				variations[index] = 0
				index += 1
				continue

			if prev[x] > 0:
				value += 1
			if curr[x - 1] > 0:
				value += 2
			if curr[x + 1] > 0:
				value += 4
			if next[x] > 0:
				value += 8
			
			# diagonal neighbors
			if value & 1 and value & 2 and prev[x - 1] > 0:
				value += 16
			if value & 1 and value & 4 and prev[x + 1] > 0:
				value += 32
			if value & 8 and value & 2 and next[x - 1] > 0:
				value += 64
			if value & 8 and value & 4 and next[x + 1] > 0:
				value += 128

			variations[index] = value
			index += 1
			
			if index % 128 == 0:
				await get_tree().process_frame
		
		# update window
		prev = curr
		curr = next
		next = TileManager.get_row(start_x - 1, start_y + y + 2, width + 2)

	# apply tiles
	var blocks = $'blocks'
	index = 0
	
	for y in range(height):
		for x in range(width):
			blocks.set_cell(
				Vector2i(start_x + x, start_y + y),
				TileManager.get_block(start_x + x, start_y + y),
				CONNECTION_MAP.get(variations[index])
			)
			index += 1

func load_region(start_x: int, start_y: int, width: int, height: int, autotile := true) -> void:
	var blocks: TileMapLayer = $'blocks'

	for y in range(height):
		for x in range(width):
			blocks.set_cell(
				Vector2i(start_x + x, start_y + y),
				TileManager.get_block(start_x + x, start_y + y),
				Vector2i(0, 0)
			)
	
	if autotile:
		autotile_region(start_x - 1, start_y - 1, width + 2, height + 2)

func clear_region(start_x: int, start_y: int, width: int, height: int) -> void:
	var blocks: TileMapLayer = $'blocks'
	
	for y in range(height):
		for x in range(width):
			blocks.set_cell(Vector2i(start_x + x, start_y + y), 0, Vector2i(0, 0))

func autotile_block_chunk(check_neighbors := true) -> void:
	processing = true
	
	var blocks: TileMapLayer = $'blocks'
	var chunk = TileManager.get_chunk(chunk_pos.x, chunk_pos.y)
	
	# calculate variants
	var variants = PackedByteArray()
	var checked := 0
	variants.resize(TileManager.CHUNK_SIZE * TileManager.CHUNK_SIZE)
	
	for y in range(TileManager.CHUNK_SIZE):
		for x in range(TileManager.CHUNK_SIZE):
			variants[x + y * TileManager.CHUNK_SIZE] = calculate_connections(x, y)
			checked += 1
		if checked % 8 == 0:
			await get_tree().process_frame
	
	# autotile self
	for y in range(TileManager.CHUNK_SIZE):
		for x in range(TileManager.CHUNK_SIZE):
			pass
			#var tile := TileManager.get_block_in_chunk(chunk, x, y)
			#
			#blocks.set_cell(Vector2i(x, y), tile, CONNECTION_MAP[variants[x + y * TileManager.CHUNK_SIZE]])
	
	#if check_neighbors:
		#autotile_other_region(
			#chunk_pos.x - 1, chunk_pos.y,
			#TileManager.CHUNK_SIZE - 1, 0, TileManager.CHUNK_SIZE, TileManager.CHUNK_SIZE
		#)
		#autotile_other_region(
			#chunk_pos.x + 1, chunk_pos.y,
			#0, 1, 0, TileManager.CHUNK_SIZE
		#)
		#autotile_other_region(
			#chunk_pos.x, chunk_pos.y - 1,
			#0, TileManager.CHUNK_SIZE - 1, TileManager.CHUNK_SIZE, TileManager.CHUNK_SIZE
		#)
		#autotile_other_region(
			#chunk_pos.x, chunk_pos.y + 1,
			#0, 0, TileManager.CHUNK_SIZE, 1
		#)
	
	processing = false
	done_processing.emit()

#func autotile_other_region(cx: int, cy: int, start_x: int, start_y: int, end_x: int, end_y: int) -> void:
	#var chunk := TileManager.get_visual_chunk(cx, cy)
	#if not chunk:
		#return
	#
	#chunk.autotile_region(start_x, start_y, end_x, end_y, false)

#func autotile_region(start_x: int, start_y: int, end_x: int, end_y: int, check_neighbors := true) -> void:
	#var blocks: TileMapLayer = $'blocks'
	#var chunk = TileManager.get_chunk(chunk_pos.x, chunk_pos.y)
	#
	#if check_neighbors:
		#start_x -= 1
		#start_y += 1
		#end_x -= 1
		#end_y += 1
	#
	## calculate variants
	#var variants = PackedByteArray()
	#var checked := 0
	#variants.resize(TileManager.CHUNK_SIZE * TileManager.CHUNK_SIZE)
	#
	#for x in range(max(start_x, 0), min(end_x, TileManager.CHUNK_SIZE)):
		#for y in range(max(start_y, 0), min(end_y, TileManager.CHUNK_SIZE)):
			#variants[x + y * TileManager.CHUNK_SIZE] = calculate_connections(x, y)
			#checked += 1
		#if checked % 8 == 0:
			#await get_tree().process_frame
	#
	#for x in range(max(start_x, 0), min(end_x, TileManager.CHUNK_SIZE)):
		#for y in range(max(start_y, 0), min(end_y, TileManager.CHUNK_SIZE)):
			#pass
			##var tile := TileManager.get_block_in_chunk(chunk, x, y)
			##
			##blocks.set_cell(Vector2i(x, y), tile, CONNECTION_MAP[variants[x + y * TileManager.CHUNK_SIZE]])

#endregion
