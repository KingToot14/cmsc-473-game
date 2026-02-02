class_name TileRunner
extends RefCounted

# --- Enums --- #
enum ReplaceMode {
	ADD_NEW = 1,
	REPLACE = 2,
	BOTH = ADD_NEW | REPLACE
}

# --- Variables --- #
var size := 0
var steps := 0
var replace_tile := 0
var replace_mode := ReplaceMode.REPLACE

var position := Vector2.ZERO
var direction := Vector2.ZERO
var direction_change := Vector2(0.5, 0.5)

var allowed_tiles: Array[int] = []
var restricted_tiles: Array[int] = []

# --- Functions --- #
func _init(new_size: int, new_steps: int, x: int, y: int, tile_id: int) -> void:
	size = new_size
	steps = new_steps
	position = Vector2(x, y)
	
	replace_tile = tile_id

func set_direction(new_direction: Vector2) -> TileRunner:
	direction = new_direction
	
	return self

func set_direction_change(new_change: Vector2) -> TileRunner:
	direction_change = new_change
	
	return self

func set_allowed_tiles(tiles: Array[int]) -> TileRunner:
	allowed_tiles = tiles
	
	return self

func set_restricted_tiles(tiles: Array[int]) -> TileRunner:
	restricted_tiles = tiles
	
	return self

func set_replace_mode(mode: ReplaceMode) -> TileRunner:
	replace_mode = mode
	
	return self

func start(gen: WorldGeneration) -> void:
	# randomize direction
	if direction == Vector2.ZERO:
		direction = Vector2(gen.rng.randf_range(-1.0, 1.0), gen.rng.randf_range(-1.0, 1.0))
	
	var world_size := Globals.world_size
	
	# main loop
	var curr_steps := steps
	var curr_size := size
	
	while curr_size > 0 and curr_steps > 0:
		@warning_ignore("integer_division")
		curr_size = size * floori(curr_steps / steps)
		curr_steps -= 1
		
		# calculate bounding box
		var start_x := clampi(floori(position.x - curr_size / 2.0), 0, world_size.x)
		var end_x := clampi(floori(position.x + curr_size / 2.0), 0, world_size.x)
		var start_y := clampi(floori(position.y - curr_size / 2.0), 0, world_size.y)
		var end_y := clampi(floori(position.y + curr_size / 2.0), 0, world_size.y)
		
		# replace tiles
		for y in range(start_y, end_y + 1):
			for x in range(start_x, end_x + 1):
				# check distance
				var threshold := (curr_size / 2.0) * gen.rng.randf_range(0.90, 1.10)
				
				if abs(position.x - x) + abs(position.y - y) < threshold:
					continue
				
				var block := TileManager.get_block_unsafe(x, y)
				
				# check white/blacklist
				if not allowed_tiles.is_empty() and block not in allowed_tiles:
					continue
				if not restricted_tiles.is_empty() and block in restricted_tiles:
					continue
				
				# check replace mode
				if not (replace_mode & ReplaceMode.ADD_NEW) and block == 0:
					continue
				if not (replace_mode & ReplaceMode.REPLACE) and block != 0:
					continue
				
				TileManager.set_block_unsafe(x, y, replace_tile)
		
		# move towards direction
		position += direction
		
		# randomize direction
		direction += direction_change * Vector2(gen.rng.randf_range(-1.0, 1.0), gen.rng.randf_range(-1.0, 1.0))
		direction = direction.normalized()
