class_name WorldTileMap
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

var processing := false

# --- Functions --- #
func _ready() -> void:
	Globals.world_map = self

#region Tile Management
func autotile_region(start_x: int, start_y: int, width: int, height: int) -> void:
	# calculate variations
	var variations := PackedByteArray()
	variations.resize(width * height)
	var index := 0
	
	# clamp bounds
	start_x = maxi(start_x, 0)
	start_y = maxi(start_y, 0)
	width   = mini(start_x + width,  Globals.world_size.x) - start_x
	height  = mini(start_y + height, Globals.world_size.y) - start_y
	
	if width <= 0 or height <= 0:
		return
	
	var prev := TileManager.get_block_row(start_x - 1, start_y - 1, width + 2)
	var curr := TileManager.get_block_row(start_x - 1, start_y + 0, width + 2)
	var next := TileManager.get_block_row(start_x - 1, start_y + 1, width + 2)
	
	for y in range(height):
		for x in range(1, width + 1):
			var value := 0
			
			if curr.is_empty() or next.is_empty():
				variations[index] = 0
				index += 1
				continue
			
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
			
			if index % 64 == 0:
				await get_tree().process_frame
		
		# update window
		prev = curr
		curr = next
		next = TileManager.get_block_row(start_x - 1, start_y + y + 2, width + 2)

	# apply tiles
	var blocks = $'blocks'
	index = 0
	
	for y in range(height):
		for x in range(width):
			blocks.set_cell(
				Vector2i(start_x + x, start_y + y),
				TileManager.get_block_unsafe(start_x + x, start_y + y),
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
				Vector2i(2, 2)
			)
	
	if autotile:
		autotile_region(start_x - 1, start_y - 1, width + 2, height + 2)

func clear_region(start_x: int, start_y: int, width: int, height: int) -> void:
	var blocks: TileMapLayer = $'blocks'
	
	for y in range(height):
		for x in range(width):
			blocks.set_cell(Vector2i(start_x + x, start_y + y), 0, Vector2i(0, 0))

#endregion
