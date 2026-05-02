class_name DungeonPass
extends WorldGenPass

# --- Variables --- #
const ARENA_HEIGHT := 80
const ARENA_WIDTH := 120

const HALLWAY_HEIGHT := 18
const HALLWAY_WIDTH := 60

const ENTRANCE_HEIGHT := 22
const ENTRANCE_WIDTH := 36

const PLATFORM_HEIGHT := 11
const PLATFORM_SPACING := 6

# --- Functions --- #
func get_pass_name() -> String:
	return "Blocking out Dungeon"

func perform_pass(_gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	# create arena room
	var base_height := world_size.y - 180
	
	for ry in range(0, ARENA_HEIGHT):
		for rx in range(0, ARENA_WIDTH):
			var x := rx
			var y := base_height + ry
			
			# fill with basalt around edges
			if rx < 3 or rx >= ARENA_WIDTH - 3 or ry < 3 or ry >= ARENA_HEIGHT - 3:
				TileManager.set_block_unsafe(x, y, 17)
			else:
				TileManager.set_block_unsafe(x, y, 0)
			
			# create bottom platform
			if not (rx < 3 or rx >= ARENA_WIDTH - 3) and ry == ARENA_HEIGHT - PLATFORM_HEIGHT:
				if rx < 8 or rx >= ARENA_WIDTH - 8:
					# basalt platforms
					TileManager.set_block_unsafe(x, y, 27)
				else:
					# basalt bricks
					TileManager.set_block_unsafe(x, y, 17)
			
			# create other platforms
			if not (rx < 8 or rx >= ARENA_WIDTH - 8) and \
				ry > 12 and ry < ARENA_HEIGHT - PLATFORM_HEIGHT and ry % PLATFORM_SPACING == 3:
				# basalt platforms
				TileManager.set_block_unsafe(x, y, 27)
			
			if not (rx < 3 or rx >= ARENA_WIDTH - 3) and \
				ry > ARENA_HEIGHT - PLATFORM_HEIGHT + 1 and ry < ARENA_HEIGHT - 3:
				TileManager.set_liquid_level(x, y, WaterUpdater.MAX_WATER_LEVEL)
				TileManager.set_liquid_type(x, y, WaterUpdater.LAVA_TYPE)
			else:
				TileManager.set_liquid_level(x, y, 0)
				TileManager.set_liquid_type(x, y, 0)
			
			# set basalt brick walls
			TileManager.set_wall_unsafe(x, y, 11)
	
	# create entrance
	for ry in range(0, ENTRANCE_HEIGHT):
		for rx in range(0, ENTRANCE_WIDTH):
			var x := ARENA_WIDTH + HALLWAY_WIDTH + rx
			var y := base_height + (ARENA_HEIGHT - ENTRANCE_HEIGHT - 8) + ry
			
			# fill with basalt around edges
			if rx < 3 or rx >= ENTRANCE_WIDTH - 3 or ry < 3 or ry >= ENTRANCE_HEIGHT - 3:
				TileManager.set_block_unsafe(x, y, 17)
			else:
				TileManager.set_block_unsafe(x, y, 0)
			
			TileManager.set_liquid_level(x, y, 0)
			TileManager.set_liquid_type(x, y, 0)
			
			# set basalt brick walls
			TileManager.set_wall_unsafe(x, y, 11)
	
	# create entrance windows
	for y in range(6):
		for x in range(5):
			# skip top corners
			if y == 0 and (x == 0 or x == 4):
				continue
			
			# left window
			TileManager.set_wall_unsafe(
				ARENA_WIDTH + HALLWAY_WIDTH + 3 + 5 + x,
				base_height + (ARENA_HEIGHT - ENTRANCE_HEIGHT - 8) + 3 + 4 + y,
				20 # gold walls
			)
			
			# right window
			TileManager.set_wall_unsafe(
				ARENA_WIDTH + HALLWAY_WIDTH + ENTRANCE_WIDTH - 3 - 6 - x,
				base_height + (ARENA_HEIGHT - ENTRANCE_HEIGHT - 8) + 3 + 4 + y,
				20 # gold walls
			)
	
	# create hallway
	for ry in range(0, HALLWAY_HEIGHT):
		for rx in range(-3, HALLWAY_WIDTH + 3):
			var x := ARENA_WIDTH + rx
			var y := base_height + (ARENA_HEIGHT - HALLWAY_HEIGHT - 8) + ry
			
			# fill with basalt around edges
			if ry < 3 or ry >= HALLWAY_HEIGHT - 3:
				TileManager.set_block_unsafe(x, y, 17)
			elif ry < HALLWAY_HEIGHT - 8 and (rx < 0 or rx >= HALLWAY_WIDTH):
				TileManager.set_block_unsafe(x, y, 17)
			else:
				TileManager.set_block_unsafe(x, y, 0)
			
			TileManager.set_liquid_level(x, y, 0)
			TileManager.set_liquid_type(x, y, 0)
			
			# set basalt brick walls
			TileManager.set_wall_unsafe(x, y, 11)
			
			# windows
			if ry == 3 + 3 and (rx % 15) in [6, 7, 8]:
				TileManager.set_wall_unsafe(x, y, 20)
			if ry in [3 + 4, 3 + 5, 3 + 6, 3 + 7] and (rx % 15) in [5, 6, 7, 8, 9]:
				TileManager.set_wall_unsafe(x, y, 20)
