extends Control

signal login_success(player_id)

@onready var username_field = $UsernameField
@onready var password_field = $PasswordField
@onready var status_label = $StatusLabel

func _ready():
	var remembered = DatabaseManager.load_remembered_player_id()
	if remembered != -1:
		status_label.text = "Welcome back!"
		emit_signal("login_success", remembered)

func _on_login_button_pressed():
	var user = username_field.text
	var password = password_field.text

	if user.is_empty() or password.is_empty():
		status_label.text = "Please enter username and password."
		return

	status_label.text = "Logging in..."

	DatabaseManager.login.rpc_id(1, user, password)

func _on_create_button_pressed():
	var user = username_field.text
	var password = password_field.text

	if user.is_empty() or password.is_empty():
		status_label.text = "Please enter username and password."
		return

	status_label.text = "Creating account..."

	DatabaseManager.create_account.rpc_id(1, user, password)

@rpc("authority", "call_remote", "reliable")
func login_result(player_id: int):
	if player_id == -1:
		status_label.text = "Invalid username or password."
		return

	status_label.text = "Login successful!"
	DatabaseManager.remember_player_id(player_id)
	emit_signal("login_success", player_id)

@rpc("authority", "call_remote", "reliable")
func create_account_result(player_id: int):
	if player_id == -1:
		status_label.text = "Username already exists."
		return

	status_label.text = "Account created! You can now log in."
