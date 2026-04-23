class_name PauseMenu
extends CanvasLayer

@onready var main_panel = $main_panel
@onready var sounds_menu_panel = $sounds_menu_panel
@onready var sounds_button = $main_panel/sounds_button
@onready var back_button = $sounds_menu_panel/back_button

func _ready() -> void:
	hide()
	sounds_menu_panel.hide()
	
	# Hook up our buttons
	sounds_button.pressed.connect(_on_sounds_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		if visible:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()

func open_menu() -> void:
	show()
	main_panel.show()
	sounds_menu_panel.hide()
	
	# Free the mouse so the player can click the menu
	Globals.mouse.cursor_locked = false
	Globals.set_cursor(Globals.CursorType.ARROW)
	
	# Optional: Force close the inventory if it's open so they don't overlap
	if Globals.player:
		var inv_container = Globals.player.get_node_or_null("inventory_ui/inventory_container")
		if inv_container and inv_container.visible:
			# Simulate an inventory toggle to close everything cleanly
			var ev = InputEventAction.new()
			ev.action = "inventory_toggle"
			ev.pressed = true
			Input.parse_input_event(ev)

func close_menu() -> void:
	hide()
	# The player controller's _process will naturally recapture the mouse 
	# based on the equipped item when the menu goes away.

func _on_sounds_button_pressed() -> void:
	main_panel.hide()
	sounds_menu_panel.show()

func _on_back_button_pressed() -> void:
	sounds_menu_panel.hide()
	main_panel.show()
