class_name InventoryUI
extends Control

# --- Variables --- #
const HOTBAR_INPUTS = [
	&'hotbar_1', &'hotbar_2', &'hotbar_3', &'hotbar_4', &'hotbar_5',
	&'hotbar_6', &'hotbar_7', &'hotbar_8', &'hotbar_9', &'hotbar_10'
]

@export var slot_scene: PackedScene
@onready var main_grid = $"inventory_grid"
@onready var hotbar_grid = $"../hotbar_container/hotbar_grid"

@export var recipes: Array[Recipe] = [] # Populate this in the Inspector
@export var crafting_button_scene: PackedScene
@onready var crafting_buttons_container = $"../crafting_container/crafting_buttons"

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
	
	#set first hotbar slot to be selected
	hotbar_grid.get_child(0).set_selected(true)
	#setup the crafting menu
	setup_crafting_ui()
	player_inventory.inventory_updated.connect(refresh_ui.bind(player_inventory))
	refresh_ui(player_inventory)

func setup_crafting_ui():
	# Clear any dummy buttons you made in the editor
	for child in crafting_buttons_container.get_children():
		child.queue_free()
		
	var path = "res://entities/player/recipes"
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			# Make sure we only load Godot resource files
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				# Load the Recipe resource
				var recipe = load(path + "/" + file_name) as Recipe
				if recipe:
					# Spawn a button for it!
					var btn = crafting_button_scene.instantiate()
					btn.recipe = recipe
					crafting_buttons_container.add_child(btn)
				file_name = dir.get_next()

func refresh_ui(player_inventory: Inventory):
	# Combine children of both grids to match the order of the items array
	var all_slots = hotbar_grid.get_children() + main_grid.get_children()
	for i in range(player_inventory.items.size()):
		all_slots[i].update_slot(player_inventory.items[i])
	
	for button in crafting_buttons_container.get_children():
		if button is CraftingButton:
			button.update_availability(player_inventory)
		
func refresh_crafting_ui():
	var player_inv = Globals.player.my_inventory
	# Assuming crafting_buttons is your VBoxContainer
	for button in $inventory_container/crafting_buttons.get_children():
		if button is CraftingButton:
			button.update_availability(player_inv)
