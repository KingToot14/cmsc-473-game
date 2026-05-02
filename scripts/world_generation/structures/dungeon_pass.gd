class_name DungeonPass
extends WorldGenPass

# --- Variables --- #
const ARENA_HEIGHT := 80
const ARENA_WIDTH := 120

const HALLWAY_HEIGHT := 20
const HALLWAY_WIDTH := 80

const ENTRANCE_HEIGHT := 24
const ENTRANCE_WIDTH := 50

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
	
	# create hallway
	for ry in range(0, HALLWAY_HEIGHT):
		for rx in range(-3, HALLWAY_WIDTH + 3):
			var x := ARENA_WIDTH + rx
			var y := base_height + (ARENA_HEIGHT - HALLWAY_HEIGHT - 8) + ry
			
			# fill with basalt around edges
			if ry < 3 or ry >= HALLWAY_HEIGHT - 3:
				TileManager.set_block_unsafe(x, y, 17)
			else:
				TileManager.set_block_unsafe(x, y, 0)
			
			TileManager.set_liquid_level(x, y, 0)
			TileManager.set_liquid_type(x, y, 0)
			
			# set basalt brick walls
			TileManager.set_wall_unsafe(x, y, 11)
