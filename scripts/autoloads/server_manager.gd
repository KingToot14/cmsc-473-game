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
		
		start_server()

#region Server Connections
func start_server() -> Error:
	print("[Server Test] Starting server on port %s" % SERVER_PORT)
	
	# create the server peer
	var peer := ENetMultiplayerPeer.new()
	var error = peer.create_server(SERVER_PORT)
	
	if error:
		print("[Server Test] ERROR: %s" % error_string(error))
		return error
	
	print("[Server Test] Status: %s" % error_string(error))
	
	multiplayer.peer_connected.connect(_on_player_connect)
	multiplayer.peer_disconnected.connect(_on_player_disconnect)
	multiplayer.multiplayer_peer = peer
	
	print("[Server Test] Server started")
	
	return Error.OK

func join_server(ip_address := '127.0.0.1', port := 7000) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip_address, port)
	
	if error:
		print("[Server Test] ERROR: %s" % error_string(error))
		return error
	
	# set multiplayer
	multiplayer.multiplayer_peer = peer
	
	return Error.OK

func _on_player_connect(id: int) -> void:
	if not multiplayer.is_server():
		return
	
	# setup player
	print("[Server Test] Client '%s' has joined the server" % id)
	
	var player: PlayerController = preload("uid://do1dgabbmwjjn").instantiate()
	player.name = "player_%s" % id
	player.owner_id = id
	
	player.position = Vector2(randf_range(20.0, 460.0), randf_range(20.0, 250.0))
	
	get_tree().current_scene.get_node(^'entities').add_child(player)

func _on_player_disconnect(id: int) -> void:
	if not multiplayer.is_server():
		return
	
	print("[Server Test] Client '%s' has left the server" % id)
	
	var player = get_tree().current_scene.get_node('entities/player_%s' % id)
	
	if player:
		player.queue_free()

#endregion
