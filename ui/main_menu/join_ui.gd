class_name JoinUi
extends CanvasLayer

# --- Variables --- #


# --- Functions --- #
func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _on_connected_to_server() -> void:
	print("[Wizbowo's Conquest] Client '%s' connected" % multiplayer.get_unique_id())
	
	# hide join ui
	hide()

func _on_connection_failed() -> void:
	print("[Wizbowo's Conquest] Client '%s' failed to connect" % multiplayer.get_unique_id())
	
	# re-enable connect options
	$'connect_options'.show()
	$'joining_panel'.hide()

func create_client() -> Error:
	# get the fields from LineEdits
	var ip_address: String = %'ip_field'.text
	var port_str: String = %'port_field'.text
	
	# check ip address
	var regex = RegEx.new()
	regex.compile(r'([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})')
	var matches = regex.search(ip_address)
	
	if not matches:
		print("[Server Test] ERROR: The entered IP Address was not valid: '%s'" % ip_address)
		return Error.ERR_INVALID_PARAMETER
	
	# check port
	if not port_str.is_valid_int():
		print("[Server Test] ERROR: The entered port is not a positive integer: '%s'" % port_str)
		return Error.ERR_INVALID_PARAMETER
	
	var port: int = int(port_str)
	
	# update ui
	$'connect_options'.hide()
	$'joining_panel'.show()
	
	# create client
	return ServerManager.join_server(ip_address, port)
