class_name PreviousConnectionButton
extends BaseButton

# --- Variables --- #
var ip_address: String
var port: String

# --- Functions --- #
func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if ip_address.is_empty() or port.is_empty():
		return
	
	# update line edits
	%'ip_field'.text = ip_address
	%'port_field'.text = port
	
	# weird fix to force line edit updates
	get_tree().current_scene.get_node(^'join_ui')._on_ip_changed(ip_address)
	get_tree().current_scene.get_node(^'join_ui')._on_port_changed(port)

func load_connection(connection: String) -> void:
	if connection.is_empty():
		hide()
	else:
		show()
		
		ip_address = connection.split(":")[0]
		port       = connection.split(":")[1]
		
		$'backing/title'.text = connection
