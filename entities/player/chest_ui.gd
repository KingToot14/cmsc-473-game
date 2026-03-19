class_name ChestUI
extends Control

@onready var grid = $chest_grid
@export var slot_scene: PackedScene

var current_chest: ChestEntity

func _ready() -> void:
	$close_button.pressed.connect(close)

func open(chest: ChestEntity):
	current_chest = chest
	show()
	
	# Clear old slots
	for child in grid.get_children():
		child.queue_free()
	
	# Create chest slots
	for i in range(chest.inventory.items.size()):
		var new_slot: InventorySlot = slot_scene.instantiate()
		grid.add_child(new_slot)
		
		# We need to tell the slot WHICH inventory it's talking to
		# We'll update InventorySlot next to support this
		new_slot.target_inventory = chest.inventory
		new_slot.slot_index = i
		
		new_slot.update_slot(chest.inventory.items[i])
	
	# Connect signal for updates
	if not current_chest.inventory.inventory_updated.is_connected(refresh):
		current_chest.inventory.inventory_updated.connect(refresh)

func refresh():
	if not current_chest: return
	var slots = grid.get_children()
	for i in range(current_chest.inventory.items.size()):
		slots[i].update_slot(current_chest.inventory.items[i])

func close():
	if current_chest and current_chest.inventory.inventory_updated.is_connected(refresh):
		current_chest.inventory.inventory_updated.disconnect(refresh)
	current_chest = null
	hide()
