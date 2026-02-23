class_name InventoryUI
extends Control

# --- Variables --- #
const HOTBAR_INPUTS = [
	&'hotbar_1', &'hotbar_2', &'hotbar_3', &'hotbar_4', &'hotbar_5',
	&'hotbar_6', &'hotbar_7', &'hotbar_8', &'hotbar_9', &'hotbar_10'
]

@export var slot_scene: PackedScene # Needs inventory_slot.tscn here in the Inspector
@onready var main_grid = $"inventory_grid"
@onready var hotbar_grid = $"../hotbar_container/hotbar_grid"

const HOTBAR_SIZE = 10

# --- Functions --- #
func _input(event: InputEvent) -> void:
	# check for hotbar inputs
	for i in range(len(HOTBAR_INPUTS)):
		if event.is_action_pressed(HOTBAR_INPUTS[i]):
			# set i'th hotbar slot to be selected
			hotbar_grid.get_child(i).set_selected(true)
			
			# consume input
			get_viewport().set_input_as_handled()
	
	# check for scroll-wheel
	if event is InputEventMouseButton:
		var hotbar_slot := Globals.player.my_inventory.hotbar_slot
		
		# adjust current hotbar slot based on scroll wheel direction
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			hotbar_slot = posmod(hotbar_slot + 1, HOTBAR_SIZE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			hotbar_slot = posmod(hotbar_slot - 1, HOTBAR_SIZE)
		
		hotbar_grid.get_child(hotbar_slot).set_selected(true)

func setup_ui(player_inventory: Inventory):
	for child in main_grid.get_children() + hotbar_grid.get_children():
		child.free()
	
	# Create visual slots
	for i in range(player_inventory.items.size()):
		var new_slot = slot_scene.instantiate()
		
		# First 10 go to hotbar, rest to main inventory
		if i < HOTBAR_SIZE:
			hotbar_grid.add_child(new_slot)
			new_slot.is_hotbar = true
		else:
			main_grid.add_child(new_slot)
			
		new_slot.update_slot(player_inventory.items[i])
	
	# set first hotbar slot to be selected
	hotbar_grid.get_child(0).set_selected(true)
	
	# add refresh signal
	player_inventory.inventory_updated.connect(refresh_ui.bind(player_inventory))

func refresh_ui(player_inventory: Inventory):
	# Combine children of both grids to match the order of the items array
	var all_slots = hotbar_grid.get_children() + main_grid.get_children()
	for i in range(player_inventory.items.size()):
		all_slots[i].update_slot(player_inventory.items[i])
