class_name WorldTileMap
extends Node2D

# --- Enums --- #
enum UpdateState {
	UNLOADED,
	DIRTY,
	TILED
}

# --- Variables --- #
const CONNECTION_MAP: Dictionary[int, Vector2i] = {
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

const PLATFORM_MAP: Dictionary[int, Vector2i] = {
	0: Vector2i(0, 0), #   X
	1: Vector2i(1, 0), # - X
	2: Vector2i(2, 0), # x X
	3: Vector2i(0, 1), #   X -
	4: Vector2i(1, 1), # - X -
	5: Vector2i(2, 1), # x X -
	6: Vector2i(0, 2), #   X x
	7: Vector2i(1, 2), # - X x
	8: Vector2i(2, 2)  # x X x
}

var chunk_states: Dictionary[Vector2i, UpdateState] = {}

var queued_chunks: Dictionary[Vector2i, bool] = {}

# --- Functions --- #
func _ready() -> void:
	Globals.world_map = self
	
	ServerManager.server_started.connect(func(): set_process(not multiplayer.is_server()))

func _process(_delta: float) -> void:
	if len(queued_chunks) > 0:
		var chunks := queued_chunks.keys()
		var start := Time.get_ticks_usec()
		
		for chunk in chunks:
			if chunk_states.get(chunk, UpdateState.UNLOADED) == UpdateState.DIRTY:
				autotile_region(
					chunk.x * TileManager.CHUNK_SIZE - 1,
					chunk.y * TileManager.CHUNK_SIZE - 1,
					TileManager.CHUNK_SIZE + 2,
					TileManager.CHUNK_SIZE + 2
				)
				
				queued_chunks.erase(chunk)
				
				# only process for up to 4ms
				if Time.get_ticks_usec() - start >= 4000:
					break

#region Tile Management
func autotile_region(start_x: int, start_y: int, width: int, height: int) -> void:
	# calculate variations
	var variations := PackedByteArray()
	var tile_type := PackedByteArray()
	variations.resize(width * height)
	tile_type.resize(width * height)
	var index := 0
	
	# block info
	var is_solid := BlockDatabase.is_solid
	var tiling_mode := BlockDatabase.tiling_mode
	
	# clamp bounds
	start_x = maxi(start_x, 0)
	start_y = maxi(start_y, 0)
	width   = mini(start_x + width,  Globals.world_size.x) - start_x
	height  = mini(start_y + height, Globals.world_size.y) - start_y
	
	if width <= 0 or height <= 0:
		return
	
	var prev_blocks: PackedInt32Array = TileManager.get_block_row(start_x - 1, start_y - 1, width + 2)
	var curr_blocks: PackedInt32Array = TileManager.get_block_row(start_x - 1, start_y + 0, width + 2)
	var next_blocks: PackedInt32Array = TileManager.get_block_row(start_x - 1, start_y + 1, width + 2)
	
	var prev_walls: PackedInt32Array = TileManager.get_wall_row(start_x - 1, start_y - 1, width + 2)
	var curr_walls: PackedInt32Array = TileManager.get_wall_row(start_x - 1, start_y + 0, width + 2)
	var next_walls: PackedInt32Array = TileManager.get_wall_row(start_x - 1, start_y + 1, width + 2)
	
	for y in range(height):
		for x in range(1, width + 1):
			var value := 0
			var block := curr_blocks[x]
			var wall := curr_walls[x]
			
			if curr_blocks.is_empty() or curr_walls.is_empty() or \
				next_blocks.is_empty() or next_walls.is_empty():
				
				variations[index] = 0
				index += 1
				continue
			
			if block != 0:
				match tiling_mode[block]:
					BlockInfo.TilingMode.BLOCK:
						# tile block
						if is_solid[prev_blocks[x]]:
							value += 1
						if is_solid[curr_blocks[x - 1]]:
							value += 2
						if is_solid[curr_blocks[x + 1]]:
							value += 4
						if is_solid[next_blocks[x]]:
							value += 8
						
						# diagonal neighbors
						if value & 1 and value & 2 and is_solid[prev_blocks[x - 1]]:
							value += 16
						if value & 1 and value & 4 and is_solid[prev_blocks[x + 1]]:
							value += 32
						if value & 8 and value & 2 and is_solid[next_blocks[x - 1]]:
							value += 64
						if value & 8 and value & 4 and is_solid[next_blocks[x + 1]]:
							value += 128
						
						tile_type[index] = 0
					BlockInfo.TilingMode.PLATFORM:
						# only check horizontal neighbors
						#if curr_blocks[x - 1] > 0:
							#value += 2
						#if curr_blocks[x + 1] > 0:
							#value += 4
						
						var left_state := 0
						var right_state := 0
						
						var left_block := curr_blocks[x - 1]
						var right_block := curr_blocks[x + 1]
						
						if left_block > 0:
							left_state = 2 if is_solid[left_block] else 1
						if right_block > 0:
							right_state = 2 if is_solid[right_block] else 1
						
						value = left_state + right_state * 3
						
						tile_type[index] = 2
			elif wall != 0:
				# tile wall
				if prev_walls[x] > 0:
					value += 1
				if curr_walls[x - 1] > 0:
					value += 2
				if curr_walls[x + 1] > 0:
					value += 4
				if next_walls[x] > 0:
					value += 8
				
				# diagonal neighbors
				if value & 1 and value & 2 and prev_walls[x - 1] > 0:
					value += 16
				if value & 1 and value & 4 and prev_walls[x + 1] > 0:
					value += 32
				if value & 8 and value & 2 and next_walls[x - 1] > 0:
					value += 64
				if value & 8 and value & 4 and next_walls[x + 1] > 0:
					value += 128
				
				tile_type[index] = 1
			
			variations[index] = value
			index += 1
		
		# update window
		prev_blocks = curr_blocks
		curr_blocks = next_blocks
		next_blocks = TileManager.get_block_row(start_x - 1, start_y + y + 2, width + 2)
		
		prev_walls = curr_walls
		curr_walls = next_walls
		next_walls = TileManager.get_wall_row(start_x - 1, start_y + y + 2, width + 2)
	
	# apply tiles
	var blocks: TileMapLayer = $'blocks'
	var walls: TileMapLayer = $'walls'
	
	index = 0
	
	for y in range(height):
		for x in range(width):
			# set blocks
			match tile_type[index]:
				0:
					var variation := variations[index]
					
					blocks.set_cell(
						Vector2i(start_x + x, start_y + y),
						TileManager.get_block_unsafe(start_x + x, start_y + y),
						CONNECTION_MAP.get(variation) + Vector2i(0, randi_range(0, 1) * 4)
					)
					
					# set default wall if not center tile
					if variation != 255:
						walls.set_cell(
							Vector2i(start_x + x, start_y + y),
							TileManager.get_wall_unsafe(start_x + x, start_y + y),
							Vector2i(2, 2 + randi_range(0, 1) * 4)
						)
				# set walls
				1:
					walls.set_cell(
						Vector2i(start_x + x, start_y + y),
						TileManager.get_wall_unsafe(start_x + x, start_y + y),
						CONNECTION_MAP.get(variations[index]) + Vector2i(0, randi_range(0, 1) * 4)
					)
				# set platforms
				2:
					var variation := variations[index]
					
					blocks.set_cell(
						Vector2i(start_x + x, start_y + y),
						TileManager.get_block_unsafe(start_x + x, start_y + y),
						PLATFORM_MAP.get(variation) + Vector2i(randi_range(0, 1) * 3, 0)
					)
					
					walls.set_cell(
						Vector2i(start_x + x, start_y + y),
						TileManager.get_wall_unsafe(start_x + x, start_y + y),
						Vector2i(2, 2 + randi_range(0, 1) * 4)
					)
			
			index += 1

func load_region(start_x: int, start_y: int, width: int, height: int) -> void:
	var blocks: TileMapLayer = $'blocks'
	var walls: TileMapLayer = $'walls'
	
	#var processed := 0
	for y in range(height):
		for x in range(width):
			var block := TileManager.get_block_unsafe(start_x + x, start_y + y)
			var wall  := TileManager.get_wall_unsafe(start_x + x, start_y + y)
			
			# set blocks
			if block == 0:
				blocks.erase_cell(Vector2i(start_x + x, start_y + y))
			else:
				blocks.set_cell(Vector2i(start_x + x, start_y + y), block, Vector2i(2, 2))
			
			# set walls
			if wall == 0:
				walls.erase_cell(Vector2i(start_x + x, start_y + y))
			else:
				walls.set_cell(Vector2i(start_x + x, start_y + y), wall, Vector2i(2, 2))

func clear_region(start_x: int, start_y: int, width: int, height: int) -> void:
	var blocks: TileMapLayer = $'blocks'
	var walls: TileMapLayer = $'walls'
	
	var processed := 0
	
	for y in range(height):
		for x in range(width):
			blocks.erase_cell(Vector2i(start_x + x, start_y + y))
			walls.erase_cell(Vector2i(start_x + x, start_y + y))
			
			processed += 1
			
			if processed == 256:
				await get_tree().process_frame
				processed = 0

func update_tile(x: int, y: int) -> void:
	var blocks: TileMapLayer = $'blocks'
	var walls: TileMapLayer = $'walls'
	
	var block := TileManager.get_block_unsafe(x, y)
	var wall := TileManager.get_wall_unsafe(x, y)
	
	# set blocks
	if block == 0:
		blocks.erase_cell(Vector2i(x, y))
	else:
		blocks.set_cell(Vector2i(x, y), block, Vector2i(2, 2))
	
	# set walls
	if wall == 0:
		walls.erase_cell(Vector2i(x, y))
	else:
		walls.set_cell(Vector2i(x, y), wall, Vector2i(2, 2))
	
	# autotile neighbors
	autotile_region(x - 1, y - 1, 3, 3)

#endregion
