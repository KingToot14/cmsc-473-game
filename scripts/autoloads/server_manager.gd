extends Node

# --- Variables --- #
const SERVER_IP = '127.0.0.1'
const SERVER_PORT = 7000

# --- Functions --- #
func _ready() -> void:
	var args := Globals.parse_arguments()
	
	if OS.has_feature('dedicated_server') or args.get('server', false):
		# disable ui for servers
		get_tree().current_scene.get_node(^'join_ui').hide()
		
		# get seed
		var world_gen: WorldGeneration = get_tree().current_scene.get_node(^'world_generation')
		var world_seed = args.get('seed', randi())
		
		# start world generation
		world_gen.set_seed(world_seed)
		world_gen.generate_world()
		
		start_server()
	else:
		get_tree().current_scene.get_node(^'join_ui').show()

#region Server Connections
func start_server() -> Error:
	print("[Wizbowo's Conquest] Starting server on port %s" % SERVER_PORT)
	
	# create the server peer
	var peer := ENetMultiplayerPeer.new()
	var error = peer.create_server(SERVER_PORT)
	
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
	
	# set position
	player.spawn_point = Globals.world_spawn
	player.position = Globals.world_spawn
	
	get_tree().current_scene.get_node(^'entities').add_child(player)
	
	# send data
	player.get_node(^'chunk_loader').send_whole_area()

func _on_player_disconnect(id: int) -> void:
	if not multiplayer.is_server():
		return
	
	print("[Wizbowo's Conquest] Client '%s' has left the server" % id)
	
	var player = get_tree().current_scene.get_node('entities/player_%s' % id)
	
	if player:
		player.queue_free()

#endregion
