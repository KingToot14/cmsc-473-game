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

@export var crafting_button_scene: PackedScene
@onready var crafting_buttons_container = $"../crafting_container/crafting_buttons"

const HOTBAR_SIZE = 10

var holding_item := false
var hovered_slot := -1

@export var armor_slot_scene: PackedScene # Drag your new armor_slot.tscn here in the inspector
@onready var armor_grid = $"../armor_container/armor_grid"

# --- Functions --- #
func _input(event: InputEvent) -> void:
	# check for hotbar inputs
	for i in range(len(HOTBAR_INPUTS)):
		if event.is_action_pressed(HOTBAR_INPUTS[i]):
			# set i'th hotbar slot to be selected
			hotbar_grid.get_child(i).set_selected(true)
			return
	
	if event.is_action_pressed(&"drop_item"):
		if holding_item and visible and hovered_slot == -1:
			var drop_pos = Globals.player.get_global_mouse_position()
			
			# check if the player exists before calling the inventory
			if Globals.player:
				Globals.player.my_inventory.drop_held_item(drop_pos) 
			
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
	
	# create visual slots
	for i in range(player_inventory.items.size()):
		var new_slot: InventorySlot = slot_scene.instantiate()
		
		# Assign our new reusable variables so the slot knows who it belongs to
		new_slot.target_inventory = player_inventory
		new_slot.slot_index = i
		
		# connect signal to update cursor
		new_slot.mouse_entered.connect(_on_slot_mouse_entered.bind(player_inventory, i))
		new_slot.mouse_exited.connect(_on_slot_mouse_exited.bind(player_inventory, i))
		
		# first 10 go to hotbar, rest to main inventory
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
	
	# Clear old armor slots
	for child in armor_grid.get_children():
		child.free()
		
	# Create the 3 Armor Slots
	for i in range(3):
		var new_armor_slot = armor_slot_scene.instantiate()
		new_armor_slot.target_inventory = player_inventory
		new_armor_slot.slot_index = i # 0: Head, 1: Body, 2: Legs
		new_armor_slot.expected_type = i
		
		# Hook up hover effects
		new_armor_slot.mouse_entered.connect(_on_armor_slot_mouse_entered.bind(player_inventory, i)) 
		new_armor_slot.mouse_exited.connect(_on_slot_mouse_exited.bind(player_inventory, i))
		
		armor_grid.add_child(new_armor_slot)
		new_armor_slot.update_slot(player_inventory.armor_items[i])
	
	player_inventory.inventory_updated.connect(refresh_ui.bind(player_inventory))
	refresh_ui(player_inventory)

func setup_crafting_ui():
	# Clean up old buttons
	for child in crafting_buttons_container.get_children():
		child.queue_free()
	
	# Get the recipes from the inventory we are displaying
	var player_inv = Globals.player.my_inventory
	
	for i in range(player_inv.recipes.size()):
		var recipe = player_inv.recipes[i]
		var btn = crafting_button_scene.instantiate()
		btn.recipe = recipe
		btn.recipe_index = i # This index perfectly matches the inventory array
		crafting_buttons_container.add_child(btn)

func refresh_ui(player_inventory: Inventory):
	# combine children of both grids to match the order of the items array
	var all_slots = hotbar_grid.get_children() + main_grid.get_children()
	for i in range(player_inventory.items.size()):
		all_slots[i].update_slot(player_inventory.items[i])
	
	# NEW: Update the armor slots
	var armor_slots = armor_grid.get_children()
	for i in range(player_inventory.armor_items.size()):
		if i < armor_slots.size():
			armor_slots[i].update_slot(player_inventory.armor_items[i])
	
	for button in crafting_buttons_container.get_children():
		if button is CraftingButton:
			button.update_availability(player_inventory)
	
	# update cursors
	set_is_holding(player_inventory.held_item.item_id != -1)

func _on_armor_slot_mouse_entered(inventory: Inventory, index: int) -> void:
	hovered_slot = index
	
	if not holding_item:
		# check the ARMOR array, not the main items array
		if inventory.armor_items[index].item_id == -1:
			Globals.set_cursor(Globals.CursorType.ARROW)
		else:
			Globals.set_cursor(Globals.CursorType.HAND_OPEN)
		
		Globals.mouse.cursor_locked = true

func refresh_crafting_ui():
	var player_inv = Globals.player.my_inventory
	# Assuming crafting_buttons is your VBoxContainer
	for button in $inventory_container/crafting_buttons.get_children():
		if button is CraftingButton:
			button.update_availability(player_inv)

#region Cursors
func set_is_holding(value: bool) -> void:
	holding_item = value
	
	if holding_item:
		Globals.mouse.cursor_locked = true
		Globals.set_cursor(Globals.CursorType.HAND_GRAB)
	elif hovered_slot != -1:
		Globals.mouse.cursor_locked = true
		Globals.set_cursor(Globals.CursorType.HAND_OPEN)
	else:
		Globals.mouse.cursor_locked = false
		Globals.set_cursor(Globals.CursorType.ARROW)

func _on_slot_mouse_entered(inventory: Inventory, index: int) -> void:
	hovered_slot = index
	
	if not holding_item:
		# don't show hand cursor when hovering empty slots
		if inventory.items[index].item_id == -1:
			Globals.set_cursor(Globals.CursorType.ARROW)
		else:
			Globals.set_cursor(Globals.CursorType.HAND_OPEN)
		
		Globals.mouse.cursor_locked = true

func _on_slot_mouse_exited(_inventory: Inventory, index: int) -> void:
	if hovered_slot == index:
		hovered_slot = -1
		
		if not holding_item:
			Globals.mouse.cursor_locked = false
			Globals.set_cursor(Globals.CursorType.ARROW)

#endregion
