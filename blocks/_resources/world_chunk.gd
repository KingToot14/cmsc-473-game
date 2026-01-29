@tool
class_name WorldChunk
extends Node2D

# --- Variables --- #
const CONNECTION_MAP = {
	1: Vector2i(0, 3),
	2: Vector2i(3, 0),
	4: Vector2i(1, 0),
	8: Vector2i(0, 1),
}

@export var chunk_pos := -Vector2i.ONE

@export_tool_button("Randomize Chunk", "RandomNumberGenerator")
var _dummy = _randomize_chunk

# --- Functions --- #
func _ready() -> void:
	#load_from_data()
	_randomize_chunk()

#region Tile Management
func calculate_connections(x: int, y: int) -> int:
	if x < 0 or x >= TileManager.CHUNK_SIZE or y < 0 or y >= TileManager.CHUNK_SIZE:
		return 0
	
	var chunk = TileManager.get_chunk(chunk_pos.x, chunk_pos.y)
	
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
	
	for x in range(TileManager.CHUNK_SIZE):
		for y in range(TileManager.CHUNK_SIZE):
			var tile := TileManager.get_block_in_chunk(chunk, x, y)
			var connections := calculate_connections(x, y)
			
			print(x, ", ", y, " | ", connections)
			
			if connections == 1 or connections == 2 or connections == 4 or connections == 8:
				print(connections)
			
			blocks.set_cell(Vector2i(x, y), tile, CONNECTION_MAP.get(connections, Vector2.ZERO))

#endregion
