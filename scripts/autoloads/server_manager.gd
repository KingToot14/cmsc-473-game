extends Node

# --- Variables --- # 
const DEFAULT_PORT = 7000

var connected_players: Dictionary[int, PlayerController] = {}

# --- Functions --- #
func _ready() -> void:
	var args := Globals.parse_arguments()
	
	if OS.has_feature('dedicated_server') or args.get('server', false):
		# disable ui for servers
		get_tree().current_scene.get_node(^'join_ui').hide()
		
		# get seed
		var world_gen: WorldGeneration = get_tree().current_scene.get_node(^'world_generation')
		var world_seed = args.get('seed', randi())
		
		# world generation flags
		var world_name: String = args.get('world_name', '')
		var delete_mode: bool = args.get('delete', false)
		
		# TODO: Add world loading + deletion
		if not world_name.strip_edges().is_empty():
			if delete_mode:
				print("[Wizbowo's Conquest] Deleting world '%s' (Not implemented)" % world_name)
				get_tree().quit()
				return
			else:
				print("[Wizbowo's Conquest] Loading world '%s' (Not implemented)" % world_name)
				get_tree().quit()
				return
		elif delete_mode:
			printerr("[Wizbowo's Conquest] Must specify world name to delete")
			get_tree().quit()
			return
		
		# start world generation
		world_gen.set_seed(world_seed)
		await world_gen.generate_world()
		
		# load initial spawn tilemap
		print("[Wizbowo's Conquest] Loading Spawn Area Collision")
		var center_chunk := TileManager.tile_to_chunk(Globals.world_spawn.x, Globals.world_spawn.y)
		
		await Globals.server_map.load_tiles(
			(center_chunk - ChunkLoader.LOAD_RANGE).x * TileManager.CHUNK_SIZE,
			(center_chunk - ChunkLoader.LOAD_RANGE).y * TileManager.CHUNK_SIZE,
			ChunkLoader.LOAD_RANGE.x * 2 * TileManager.CHUNK_SIZE,
			ChunkLoader.LOAD_RANGE.y * 2 * TileManager.CHUNK_SIZE
		)
		
		# start server
		var port = args.get('port', DEFAULT_PORT)
		if port is String:
			if port.is_valid_int():
				port = int(port)
			else:
				printerr("[Wizbowo's Conquest] Port '%s' is not a valid integer" % port)
		
		var max_connections = args.get('max_connections', 32)
		if max_connections is String:
			if max_connections.is_valid_int():
				max_connections = int(max_connections)
			else:
				printerr("[Wizbowo's Conquest] Max Connections '%s' is not a valid integer" % max_connections)
		
		start_server(port, max_connections)
	else:
		get_tree().current_scene.get_node(^'join_ui').show()

#region Server Connections
func start_server(port := DEFAULT_PORT, max_connections := 32) -> Error:
	print("[Wizbowo's Conquest] Starting server on port %s" % DEFAULT_PORT)
	
	# create the server peer
	var peer := ENetMultiplayerPeer.new()
	var error = peer.create_server(port, max_connections)
	
	if error:
		print("[Wizbowo's Conquest] ERROR: %s" % error_string(error))
		return error
	
	print("[Wizbowo's Conquest] Status: %s" % error_string(error))
	
	multiplayer.peer_connected.connect(_on_player_connect)
	multiplayer.peer_disconnected.connect(_on_player_disconnect)
	multiplayer.multiplayer_peer = peer
	
	print("[Wizbowo's Conquest] Server started")
	
	return Error.OK

func join_server(ip_address := '127.0.0.1', port := 7000) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip_address, port)
	
	if error:
		print("[Wizbowo's Conquest] ERROR: %s" % error_string(error))
		return error
	
	# set multiplayer
	multiplayer.peer_disconnected.connect(_on_player_disconnect)
	multiplayer.multiplayer_peer = peer
	
	return Error.OK

func _on_player_connect(id: int) -> void:
	if not multiplayer.is_server():
		return
	
	print("[Wizbowo's Conquest] Client '%s' has joined the server" % id)
	
	# wait for world generation
	var gen: WorldGeneration = get_tree().current_scene.get_node(^'world_generation')
	if gen.generating:
		await gen.done_generating
	
	# setup player
	var player: PlayerController = preload("uid://do1dgabbmwjjn").instantiate()
	player.name = "player_%s" % id
	player.owner_id = id
	connected_players[id] = player
	
	# set position
	var world_position := TileManager.tile_to_world(Globals.world_spawn.x, Globals.world_spawn.y)
	player.spawn_point = world_position
	player.position = world_position
	
	get_tree().current_scene.get_node(^'players').add_child(player)
	
	# send data
	await get_tree().process_frame
	player.get_node(^'chunk_loader').send_whole_area()

func _on_player_disconnect(id: int) -> void:
	var player = get_tree().current_scene.get_node('players/player_%s' % id)
	connected_players.erase(id)
	
	if player:
		player.queue_free()
	
	if multiplayer.is_server():
		print("[Wizbowo's Conquest] Client '%s' has left the server" % id)

#endregion
