extends Node

# --- Enums --- #
enum Biome {
	FOREST = 1,
	DESERT = 2,
	SNOW   = 4,
	OCEAN  = 8
}

enum Layer {
	SPACE       = 1,
	SURFACE     = 2,
	UNDERGROUND = 4,
	CAVERN      = 8,
	UNDERWORLD  = 16
}

# The biome manager signals when it detects a biome change.
# --- Signals --- #
signal biome_changed(new_biome: Biome)
signal layer_changed(new_layer: Layer)

# --- Constants --- #
const WINTER_THRESHOLD := 250 # number of blocks to be in scanning radius before signaling
const SCAN_RADIUS := 3 # number of chunks to scan around the player

# --- Variables --- #
var current_biome: Biome = Biome.FOREST
var current_layer: Layer = Layer.SURFACE

var player_biomes: Dictionary[int, Biome] = {}
var player_layers: Dictionary[int, Layer] = {}

# --- Functions --- #
func _ready() -> void:
	ServerManager.players_changed.connect(_on_players_changed)

func check_biome(player_pos: Vector2) -> void:
	var center_tile = TileManager.world_to_tile(
		floori(player_pos.x),
		floori(player_pos.y)
	) 
	
	# check layer (lower y = higher elevation)
	if center_tile.y > Globals.underground:
		set_layer(Layer.CAVERN)
	elif center_tile.y > Globals.surface:
		set_layer(Layer.UNDERGROUND)
	elif center_tile.y > Globals.space:
		set_layer(Layer.SURFACE)
	else:
		set_layer(Layer.SPACE)
	
	# check biome
	var snow_ice_count := 0
	
	var scan_range = SCAN_RADIUS * TileManager.CHUNK_SIZE
	var start_x = clampi(center_tile.x - scan_range, 0, Globals.world_size.x)
	var start_y = clampi(center_tile.y - scan_range, 0, Globals.world_size.y)
	var end_x = clampi(center_tile.x + scan_range, 0, Globals.world_size.x)
	var end_y = clampi(center_tile.y + scan_range, 0, Globals.world_size.y)
	
	# loop through tiles in range
	var processed := 0
	
	# TODO: Add remaining biome checks
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			var block_id = TileManager.get_block_unsafe(x, y) 
			if block_id == 6 or block_id == 7: # Snow or Ice
				snow_ice_count += 1
				
			if snow_ice_count >= WINTER_THRESHOLD:
				set_biome(Biome.SNOW)
				return
			
			processed += 1
			
			if processed == 256:
				await get_tree().process_frame
				processed = 0
			
	set_biome(Biome.FOREST) #default is forest

#region Biome Setting
func set_biome(new_biome: Biome) -> void:
	if current_biome != new_biome:
		current_biome = new_biome
		biome_changed.emit(current_biome)
		
		send_set_biome.rpc_id(Globals.SERVER_ID, new_biome)
		print("[BiomeManager] Switched to: ", current_biome)

func set_layer(new_layer: Layer) -> void:
	if current_layer != new_layer:
		current_layer = new_layer
		layer_changed.emit(current_layer)
		
		send_set_layer.rpc_id(Globals.SERVER_ID, new_layer)
		print("[BiomeManager] Switched to: ", current_layer)

@rpc('any_peer', 'call_remote', 'reliable')
func send_set_biome(new_biome: Biome) -> void:
	if not multiplayer.is_server():
		return
	
	var player_id := multiplayer.get_remote_sender_id()
	player_biomes[player_id] = new_biome

@rpc('any_peer', 'call_remote', 'reliable')
func send_set_layer(new_layer: Layer) -> void:
	if not multiplayer.is_server():
		return
	
	var player_id := multiplayer.get_remote_sender_id()
	player_layers[player_id] = new_layer

#endregion

#region Multiplayer
func _on_players_changed() -> void:
	# clear disconnected players
	for player_id in player_biomes:
		if player_id not in ServerManager.connected_players:
			player_biomes.erase(player_id)
			player_layers.erase(player_id)

func get_player_biome(player_id: int) -> Biome:
	return player_biomes.get(player_id, Biome.FOREST)

func get_player_layer(player_id: int) -> Layer:
	return player_layers.get(player_id, Layer.SURFACE)

#endregion
