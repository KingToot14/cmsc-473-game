extends Control

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
