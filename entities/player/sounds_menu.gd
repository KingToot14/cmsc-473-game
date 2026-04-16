class_name SoundsMenu
extends Control

@onready var bus_vbox = $ScrollContainer/bus_vbox

func _ready() -> void:
	await get_tree().process_frame
	build_audio_menu()

func build_audio_menu() -> void:
	for child in bus_vbox.get_children():
		child.queue_free()
		
	# dynamically grab every bus in default_bus_layout.tres
	for bus_index in range(AudioServer.get_bus_count()):
		var bus_name = AudioServer.get_bus_name(bus_index)
		
		# Create a horizontal row for this bus
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		

		var label = Label.new()
		label.text = bus_name
		hbox.add_child(label)
		label.custom_minimum_size = Vector2(20, 0)
		
		var current_db = AudioServer.get_bus_volume_db(bus_index)
		var current_linear_100 = db_to_linear(current_db) * 100.0
		
		# the Slider
		var slider = HSlider.new()
		slider.custom_minimum_size = Vector2(30, 0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.min_value = 0
		slider.max_value = 100
		slider.value = current_linear_100
		hbox.add_child(slider)
		
		# the Text Input (SpinBox)
		var spinbox = SpinBox.new()
		spinbox.min_value = 0
		spinbox.max_value = 100
		spinbox.value = current_linear_100
		hbox.add_child(spinbox)
		
		# hook up the signals so changing one updates the other and the actual audio
		slider.value_changed.connect(_on_volume_changed.bind(spinbox, bus_index))
		spinbox.value_changed.connect(_on_volume_changed.bind(slider, bus_index))
		
		bus_vbox.add_child(hbox)

func _on_volume_changed(value: float, partner_ui_node: Control, bus_index: int) -> void:
	# keep the slider and the text box in sync
	if partner_ui_node is HSlider and partner_ui_node.value != value:
		partner_ui_node.value = value
	elif partner_ui_node is SpinBox and partner_ui_node.value != value:
		partner_ui_node.value = value
		
	# convert the 0-100 scale back to decibels and apply it to the game
	var db_value = linear_to_db(value / 100.0)
	
	if db_value < -60.0:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, db_value)
