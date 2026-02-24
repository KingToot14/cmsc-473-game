class_name JoinUi
extends CanvasLayer

# --- Variables --- #
const MAX_PREVIOUS_CONNECTIONS := 6

@export var disabled_button: Texture2D
@export var normal_button: Texture2D
@export var hovered_button: Texture2D

@export var normal_button_color := Color.WHITE
@export var disabled_button_color := Color.WHITE

@export var title_rotate_range := 4.0
@export var title_rotate_msecs := 5000.0
@onready var title_texture: TextureRect = $'title'

var ip_valid := false
var port_valid := false

var button_hovered := false

var previous_connections: Array[String] = []

# --- Functions --- #
func _ready() -> void:
	# multiplayer signals
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	# ui signals
	%'ip_field'.text_changed.connect(_on_ip_changed)
	%'port_field'.text_changed.connect(_on_port_changed)
	
	%'join_button'.mouse_entered.connect(_on_join_mouse_entered)
	%'join_button'.mouse_exited.connect(_on_join_mouse_exited)
	
	# update validity
	_on_ip_changed(%'ip_field'.text)
	_on_port_changed(%'port_field'.text)
	
	# load previous connections
	load_previous_connections()

func _process(_delta: float) -> void:
	title_texture.rotation_degrees = sin(Time.get_ticks_msec() / title_rotate_msecs) * title_rotate_range

func _on_connected_to_server() -> void:
	print("[Wizbowo's Conquest] Client '%s' connected" % multiplayer.get_unique_id())
	
	# store connection

func _on_connection_failed() -> void:
	print("[Wizbowo's Conquest] Client '%s' failed to connect" % multiplayer.get_unique_id())
	
	# re-enable connect options
	$'connect_options'.show()
	$'joining_panel'.hide()
	
	# reload previous connections
	load_previous_connections()

#region Connection Info Parsing
func _on_ip_changed(new_text: String) -> void:
	ip_valid = new_text.is_valid_ip_address()
	
	check_validity()

func _on_port_changed(new_text: String) -> void:
	port_valid = new_text.is_valid_int() and int(new_text) >= 0
	
	check_validity()

func check_validity() -> void:
	%'join_button'.disabled = not (ip_valid and port_valid)
	
	if not (ip_valid and port_valid):
		%'join_button'.get_node(^'button').texture = disabled_button
		%'join_button'.get_node(^'title').self_modulate = disabled_button_color
	elif button_hovered:
		%'join_button'.get_node(^'button').texture = hovered_button
		%'join_button'.get_node(^'title').self_modulate = normal_button_color
	else:
		%'join_button'.get_node(^'button').texture = normal_button
		%'join_button'.get_node(^'title').self_modulate = normal_button_color

func _on_join_mouse_entered() -> void:
	button_hovered = true
	
	if not %'join_button'.disabled:
		%'join_button'.get_node(^'button').texture = hovered_button
		%'join_button'.get_node(^'title').self_modulate = normal_button_color

func _on_join_mouse_exited() -> void:
	button_hovered = false
	
	if not %'join_button'.disabled:
		%'join_button'.get_node(^'button').texture = normal_button
		%'join_button'.get_node(^'title').self_modulate = normal_button_color

#endregion

#region Connection Storing
func load_previous_connections() -> void:
	if not FileAccess.file_exists('user://previous_connections'):
		$'connect_options/previous_connections'.hide()
		return
	
	$'connect_options/previous_connections'.show()
	
	var file: FileAccess = FileAccess.open('user://previous_connections', FileAccess.READ)
	
	previous_connections = file.get_var()
	
	for i in range(MAX_PREVIOUS_CONNECTIONS):
		if i >= len(previous_connections):
			%'connection_boxes'.get_child(i).load_connection("")
		else:
			%'connection_boxes'.get_child(i).load_connection(previous_connections[i])

func save_connection(ip_address: String, port: int) -> void:
	var connection: String = "%s:%s" % [ip_address, port]
	
	# move existing connections to the front
	if connection in previous_connections:
		previous_connections.erase(connection)
	# clear old connections
	elif len(previous_connections) >= MAX_PREVIOUS_CONNECTIONS:
		previous_connections.pop_back()
	
	# push new connection to front
	previous_connections.push_front(connection)
	
	# store previous connections
	var file: FileAccess = FileAccess.open('user://previous_connections', FileAccess.WRITE)
	file.store_var(previous_connections)

#endregion

func create_client() -> Error:
	# get the fields from LineEdits
	var ip_address: String = %'ip_field'.text
	var port_str: String = %'port_field'.text
	
	# check ip address
	if not ip_address.is_valid_ip_address():
		print("[Server Test] ERROR: The entered IP Address was not valid: '%s'" % ip_address)
		return Error.ERR_INVALID_PARAMETER
	
	# check port
	if not (port_str.is_valid_int() and int(port_str) >= 0):
		print("[Server Test] ERROR: The entered port is not a positive integer: '%s'" % port_str)
		return Error.ERR_INVALID_PARAMETER
	
	var port: int = int(port_str)
	
	# update ui
	$'connect_options'.hide()
	$'joining_panel'.show()
	
	$'joining_panel/backing/title'.text = "Joining Server\n%s:%s" % [ip_address, port]
	
	# store connection
	save_connection(ip_address, port)
	
	# create client
	return ServerManager.join_server(ip_address, port)
