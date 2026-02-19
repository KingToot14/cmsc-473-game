extends Control

<<<<<<< Updated upstream
#Uncomment this all once we have inventory_slot.gd working

#@export var slot_scene: PackedScene #Needs inventory_slot.tscn here in the Inspector
#@onready var grid = $inventory_grid
#
#func setup_ui(player_inventory: inventory):
	#for child in grid.get_children():
		#child.queue_free()
	#
	#for stack in player_inventory.items:
		#var new_slot = slot_scene.instantiate()
		#grid.add_child(new_slot)
		#new_slot.update_slot(stack)
	#
	#player_inventory.inventory_updated.connect(refresh_ui.bind(player_inventory))
#
#func refresh_ui(player_inventory: inventory):
	#var slots = grid.get_children()
	#for i in range(player_inventory.items.size()):
		#slots[i].update_slot(player_inventory.items[i])
=======
# --- Variables --- #
@export var slot_scene: PackedScene # Needs inventory_slot.tscn here in the Inspector
@onready var main_grid = $"inventory_grid"
@onready var hotbar_grid = $"../hotbar_container/hotbar_grid"

const HOTBAR_SIZE = 10

# --- Functions --- #
func setup_ui(player_inventory: Inventory):
	for child in main_grid.get_children() + hotbar_grid.get_children():
		child.free()
	
	# Create visual slots
	for i in range(player_inventory.items.size()):
		var new_slot = slot_scene.instantiate()
		
		# First 10 go to hotbar, rest to main inventory
		if i < HOTBAR_SIZE:
			hotbar_grid.add_child(new_slot)
		else:
			main_grid.add_child(new_slot)
			
		new_slot.update_slot(player_inventory.items[i])
	
	player_inventory.inventory_updated.connect(refresh_ui.bind(player_inventory))

func refresh_ui(player_inventory: Inventory):
	# Combine children of both grids to match the order of the items array
	var all_slots = hotbar_grid.get_children() + main_grid.get_children()
	for i in range(player_inventory.items.size()):
		all_slots[i].update_slot(player_inventory.items[i])
>>>>>>> Stashed changes
