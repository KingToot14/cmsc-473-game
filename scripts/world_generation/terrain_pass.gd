class_name TerrainPass
extends WorldGenPass

# --- Enums --- #
enum TerrainFeature {
	FLAT,
	PLATEAU,
	LOW_VALLEY,
	LOW_MOUNTAIN,
	VALLEY,
	MOUNTAIN
}

# --- Variables --- #
const SURFACE_HEIGHT_HIGH := 0.17
const SURFACE_HEIGHT_TARGET := 0.23
const SURFACE_HEIGHT_LOW := 0.26 
const UNDERGROUND_OFFSET := 0.20

const BEACH_PADDING := 300

var feature := TerrainFeature.FLAT
var feature_timer := BEACH_PADDING

var surface_depth := 0
var underground_depth := 0

var surface_history: Array[int] = []

# --- Functions --- #
func get_pass_name() -> String:
	return "Building Terrain"

func perform_pass(gen: WorldGeneration) -> void:
	surface_depth = floori(
		Globals.world_size.y * SURFACE_HEIGHT_TARGET * gen.rng.randf_range(0.90, 1.10)
	)
	underground_depth = floori(
		surface_depth + Globals.world_size.y * UNDERGROUND_OFFSET * gen.rng.randf_range(0.90, 1.10)
	)
	
	var world_size   := Globals.world_size
	var world_center := Vector2i(Globals.world_size / 2.0)
	
	var surface_high = surface_depth
	var surface_low = surface_depth
	var underground_high = surface_depth
	var underground_low = surface_depth
	
	surface_history.resize(500)
	
	for x in range(Globals.world_size.x):
		# check feature
		if feature_timer <= 0:
			var dist := absi(x - world_center.x)
			
			if dist < world_size.x * 0.02:
				# only select plateau near center
				feature = TerrainFeature.PLATEAU
			elif dist < world_size.x * 0.05:
				# only select less-extreme features near center
				feature = gen.rng.randi_range(1, 3) as TerrainFeature
			else:
				# otherwise, select any feature
				feature = gen.rng.randi_range(1, 5) as TerrainFeature
			
			feature_timer = gen.rng.randi_range(10, 40)
			
			# extend plateaus
			if feature == TerrainFeature.PLATEAU:
				feature_timer = floori(feature_timer * gen.rng.randf_range(1.0, 5.0))
		
		# adjust surface height
		adjust_surface_height(gen)
		feature_timer -= 1
		
		# store extremes
		surface_high     = maxi(surface_high, surface_depth)
		surface_low      = maxi(surface_low, surface_depth)
		underground_high = maxi(underground_high, surface_depth)
		underground_low  = maxi(underground_low, surface_depth)
		
		# check bounds
		if surface_depth <= floori(world_size.y * SURFACE_HEIGHT_HIGH):
			surface_depth = floori(world_size.y * SURFACE_HEIGHT_HIGH)
			feature_timer = 0
		if surface_depth >= floori(world_size.y * SURFACE_HEIGHT_LOW):
			surface_depth = floori(world_size.y * SURFACE_HEIGHT_LOW)
			feature_timer = 0
		
		# store history for later
		if (world_size.x - x) < 800 and (world_size.x - x) >= BEACH_PADDING:
			surface_history[world_size.x - x - BEACH_PADDING] = surface_depth
		
		# snap to flat near beach
		if (world_size.x - x) == BEACH_PADDING:
			feature = TerrainFeature.FLAT
			feature_timer = BEACH_PADDING
			surface_depth = min(surface_depth, floori(world_size.y * SURFACE_HEIGHT_TARGET))
			
			if surface_history[0] > surface_depth:
				smooth_terrain()
		
		# adjust underground height
		underground_depth += gen.rng.randi_range(-2, 2)
		
		# keep underground close to surface
		if (underground_depth - surface_depth) <= floori(world_size.y * 0.06):
			underground_depth += 1
		if (underground_depth - surface_depth) >= floori(world_size.y * 0.30):
			underground_depth -= 1
		
		# apply depth
		fill_column(x)
	
	# set world paramters
	gen.surface_high = surface_high
	gen.surface_low = surface_low
	gen.underground_high = underground_high
	gen.underground_low = underground_low
	
	exit_pass()

func fill_column(x: int) -> void:
	for y in range(Globals.world_size.y):
		if y < surface_depth:
			TileManager.set_block_unsafe(x, y, 0)
		elif y < underground_depth:
			TileManager.set_block_unsafe(x, y, 2)
		else:
			TileManager.set_block_unsafe(x, y, 3)

func refill_column(x: int, surface: int) -> void:
	for y in range(Globals.world_size.y):
		if y < surface:
			TileManager.set_block_unsafe(x, y, 0)
		elif TileManager.get_block_unsafe(x, y) != 3:
			TileManager.set_block_unsafe(x, y, 2)

func adjust_surface_height(gen: WorldGeneration) -> void:
	var offset := 0
	
	match feature:
		TerrainFeature.FLAT:
			return
		TerrainFeature.PLATEAU:
			while gen.rng.randf() < 0.10:
				offset += gen.rng.randi_range(-1, 1)
		TerrainFeature.LOW_VALLEY:
			while gen.rng.randf() < 0.25:
				offset += 1
			while gen.rng.randf() < 0.10:
				offset -= 1
		TerrainFeature.LOW_MOUNTAIN:
			while gen.rng.randf() < 0.25:
				offset -= 1
			while gen.rng.randf() < 0.10:
				offset += 1
		TerrainFeature.VALLEY:
			while gen.rng.randf() < 0.50:
				offset += 1
			while gen.rng.randf() < 0.20:
				offset -= 1
		TerrainFeature.MOUNTAIN:
			while gen.rng.randf() < 0.50:
				offset -= 1
			while gen.rng.randf() < 0.20:
				offset += 1
	
	surface_depth += offset

func smooth_terrain() -> void:
	# smooth terrain towards target height
	for i in range(floori(len(surface_history) / 2.0)):
		for x in range(len(surface_history) - i * 2):
			surface_history[x] -= 1
			
			if surface_history[x] <= surface_depth:
				break
		
		if surface_history[0] <= surface_depth:
			break
	
	# refill columns in history
	for x in range(len(surface_history)):
		refill_column(Globals.world_size.x - BEACH_PADDING - x, surface_history[x])
