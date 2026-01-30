@tool
class_name WorldChunk
extends Node2D

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

# --- Functions --- #
#func _ready() -> void:
	#load_from_data()
	#_randomize_chunk()

#region Tile Management
func calculate_connections(x: int, y: int, is_wall := false) -> int:
	if x < 0 or x >= TileManager.CHUNK_SIZE or y < 0 or y >= TileManager.CHUNK_SIZE:
		return 0
	
	var chunk = TileManager.get_chunk(chunk_pos.x, chunk_pos.y)
	
	# don't run on empty blocks
	if not is_wall and TileManager.get_block_in_chunk(chunk, x, y) <= 0:
		return 0
	
	# cardinal neighbors
	var value := 0
	
	if TileManager.get_block_in_chunk(chunk, x, y - 1) > 0:
		value += 1
	if TileManager.get_block_in_chunk(chunk, x - 1, y) > 0:
		value += 2
	if TileManager.get_block_in_chunk(chunk, x + 1, y) > 0:
		value += 4
	if TileManager.get_block_in_chunk(chunk, x, y + 1) > 0:
		value += 8
	
	# diagonal neighbors
	if value & 1 and value & 2 and TileManager.get_block_in_chunk(chunk, x - 1, y - 1) > -1:
		value += 16
	if value & 1 and value & 4 and TileManager.get_block_in_chunk(chunk, x + 1, y - 1) > -1:
		value += 32
	if value & 8 and value & 2 and TileManager.get_block_in_chunk(chunk, x - 1, y + 1) > -1:
		value += 64
	if value & 8 and value & 4 and TileManager.get_block_in_chunk(chunk, x + 1, y + 1) > -1:
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

func autotile_block_chunk() -> void:
	var blocks: TileMapLayer = $'blocks'
	
	var chunk = TileManager.get_chunk(chunk_pos.x, chunk_pos.y)
	
	print(len(chunk))
	
	for x in range(TileManager.CHUNK_SIZE):
		for y in range(TileManager.CHUNK_SIZE):
			var tile := TileManager.get_block_in_chunk(chunk, x, y)
			var connections := calculate_connections(x, y)
			
			blocks.set_cell(Vector2i(x, y), tile, CONNECTION_MAP[connections])

#endregion
