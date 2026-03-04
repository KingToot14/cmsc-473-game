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
	var pass = password_field.text

	var id = DatabaseManager.login(user, pass)

	if id != -1:
		DatabaseManager.remember_player_id(id)
		status_label.text = "Login successful!"
		emit_signal("login_success", id)
	else:
		status_label.text = "Invalid username or password."

func _on_create_button_pressed():
	var user = username_field.text
	var pass = password_field.text

	if DatabaseManager.create_account(user, pass):
		status_label.text = "Account created! You can now log in."
	else:
		status_label.text = "Username already exists."
