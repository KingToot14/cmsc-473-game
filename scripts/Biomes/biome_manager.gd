extends Node

# --- Enums --- #
enum Biome { 
	FOREST = 1, 
	DESERT = 2, 
	SNOW = 4, 
	OCEAN = 8 
	}
	
enum Layer { 
	SPACE = 1, 
	SURFACE = 2,
	UNDERGROUND = 4,
	CAVERN = 8,
	UNDERWORLD = 16
	}

# --- Signals --- #
signal biome_changed(new_biome: Biome)
signal layer_changed(new_layer: Layer)

# --- Constants --- #
const ENTRY_THRESHOLD := 250 
const EXIT_THRESHOLD  := 50
const SCAN_RADIUS     := 3
const STABILITY_DELAY := 0.001

# --- Variables --- #
var current_biome: Biome = Biome.FOREST
var current_layer: Layer = Layer.SURFACE

var _first_check_done := false
var _pending_biome: Biome = Biome.FOREST
var _pending_layer: Layer = Layer.SURFACE
var _biome_timer := 0.0
var _layer_timer := 0.0

var player_biomes: Dictionary[int, Biome] = {}
var player_layers: Dictionary[int, Layer] = {}

# --- Functions --- #
func _ready() -> void:
	ServerManager.players_changed.connect(_on_players_changed)

func _process(delta: float) -> void:
	_update_timers(delta)

func _update_timers(delta: float) -> void:
	if _pending_biome != current_biome:
		_biome_timer -= delta
		if _biome_timer <= 0:
			_apply_biome(_pending_biome)
	else:
		_biome_timer = STABILITY_DELAY

	if _pending_layer != current_layer:
		_layer_timer -= delta
		if _layer_timer <= 0:
			_apply_layer(_pending_layer)
	else:
		_layer_timer = STABILITY_DELAY

func check_biome(player_pos: Vector2) -> void:
	var center_tile = TileManager.world_to_tile(floori(player_pos.x), floori(player_pos.y)) 
	
	# --- 1. Layer Detection --- #
	var detected_layer: Layer = Layer.SURFACE
	if center_tile.y <= Globals.space:
		detected_layer = Layer.SPACE
	elif center_tile.y > Globals.underworld:
		detected_layer = Layer.UNDERWORLD
	elif center_tile.y > Globals.cavern:
		detected_layer = Layer.CAVERN
	elif center_tile.y > Globals.underground:
		detected_layer = Layer.UNDERGROUND
	else:
		detected_layer = Layer.SURFACE
	
	if not _first_check_done:
		_apply_layer(detected_layer)
	else:
		set_layer(detected_layer)
	
	# --- 2. Layer-Based Early Exit --- #
	if detected_layer == Layer.SPACE or detected_layer == Layer.UNDERWORLD:
		return
		
	# --- 3. Scan Preparation --- #
	var is_ocean_x = center_tile.x <= 332 or center_tile.x >= Globals.world_size.x - 332
	var snow_count := 0
	var sand_count := 0
	var forest_count := 0 
	
	var scan_range = SCAN_RADIUS * TileManager.CHUNK_SIZE
	var start_x = clampi(center_tile.x - scan_range, 0, Globals.world_size.x)
	var start_y = clampi(center_tile.y - scan_range, 0, Globals.world_size.y)
	var end_x = clampi(center_tile.x + scan_range, 0, Globals.world_size.x)
	var end_y = clampi(center_tile.y + scan_range, 0, Globals.world_size.y)
	
	var processed := 0
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			var block_id = TileManager.get_block_unsafe(x, y) 
			if block_id == 6 or block_id == 7: snow_count += 1
			elif block_id == 8: sand_count += 1
			elif block_id == 1 or block_id == 2: forest_count += 1
			
			processed += 1
			if processed == 256:
				await get_tree().process_frame
				processed = 0

	# --- 4. Hysteresis / Anti-Flicker Logic --- #
	var target_biome: Biome = current_biome

	# Rule A: In Snow
	if current_biome == Biome.SNOW:
		if snow_count < EXIT_THRESHOLD:
			if is_ocean_x: target_biome = Biome.OCEAN
			elif sand_count >= ENTRY_THRESHOLD: target_biome = Biome.DESERT
			elif forest_count >= ENTRY_THRESHOLD: target_biome = Biome.FOREST

	# Rule B: In Desert
	elif current_biome == Biome.DESERT:
		if sand_count < EXIT_THRESHOLD:
			if is_ocean_x: target_biome = Biome.OCEAN
			elif snow_count >= ENTRY_THRESHOLD: target_biome = Biome.SNOW
			elif forest_count >= ENTRY_THRESHOLD: target_biome = Biome.FOREST

	# Rule C: In Ocean (Handles returning to Forest)
	elif current_biome == Biome.OCEAN:
		if not is_ocean_x:
			if snow_count >= ENTRY_THRESHOLD: target_biome = Biome.SNOW
			elif sand_count >= ENTRY_THRESHOLD: target_biome = Biome.DESERT
			else: target_biome = Biome.FOREST

	# Rule D: In Forest (or Initial Spawn)
	else:
		if is_ocean_x: target_biome = Biome.OCEAN
		elif snow_count >= ENTRY_THRESHOLD: target_biome = Biome.SNOW
		elif sand_count >= ENTRY_THRESHOLD: target_biome = Biome.DESERT

	_request_biome(target_biome)

	if not _first_check_done:
		_first_check_done = true

# --- State Management --- #

func _request_biome(new_biome: Biome) -> void:
	if not _first_check_done:
		_apply_biome(new_biome)
	else:
		set_biome(new_biome)

func set_biome(new_biome: Biome) -> void:
	if _pending_biome != new_biome:
		_pending_biome = new_biome
		_biome_timer = STABILITY_DELAY

func set_layer(new_layer: Layer) -> void:
	if _pending_layer != new_layer:
		_pending_layer = new_layer
		_layer_timer = STABILITY_DELAY

func _apply_biome(new_biome: Biome) -> void:
	_pending_biome = new_biome
	current_biome = new_biome
	biome_changed.emit(current_biome)
	send_set_biome.rpc_id(Globals.SERVER_ID, new_biome)
	print("[BiomeManager] Confirmed Biome: ", Biome.keys()[Biome.values().find(new_biome)])

func _apply_layer(new_layer: Layer) -> void:
	_pending_layer = new_layer
	current_layer = new_layer
	layer_changed.emit(current_layer)
	send_set_layer.rpc_id(Globals.SERVER_ID, new_layer)
	print("[BiomeManager] Confirmed Layer: ", Layer.keys()[Layer.values().find(new_layer)])

#region Multiplayer / RPCs
@rpc('any_peer', 'call_remote', 'reliable')
func send_set_biome(new_biome: Biome) -> void:
	if multiplayer.is_server():
		player_biomes[multiplayer.get_remote_sender_id()] = new_biome

@rpc('any_peer', 'call_remote', 'reliable')
func send_set_layer(new_layer: Layer) -> void:
	if multiplayer.is_server():
		player_layers[multiplayer.get_remote_sender_id()] = new_layer

func _on_players_changed() -> void:
	for player_id in player_biomes.keys():
		if player_id not in ServerManager.connected_players:
			player_biomes.erase(player_id)
			player_layers.erase(player_id)

func get_player_biome(player_id: int) -> Biome: return player_biomes.get(player_id, Biome.FOREST)
func get_player_layer(player_id: int) -> Layer: return player_layers.get(player_id, Layer.SURFACE)
#endregion
