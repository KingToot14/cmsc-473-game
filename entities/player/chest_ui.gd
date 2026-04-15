class_name ChestUI
extends Control

@export var slot_scene: PackedScene
@onready var chest_grid = $chest_grid

var current_chest: ChestEntity

func _ready() -> void:
	hide()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	# close the chest if you press "e" or tab
	if event.is_action_pressed("interact") or event.is_action_pressed("inventory_toggle"):
		close_chest()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if visible and current_chest:
		# if the chest was destroyed or is marked for deletion, close the UI.
		if not is_instance_valid(current_chest) or current_chest.is_queued_for_deletion():
			close_chest()

func open_chest(chest: ChestEntity) -> void:
	if current_chest == chest:
		return
	if current_chest:
		close_chest()
	
	current_chest = chest
	show()
	
	# clear old slots
	for child in chest_grid.get_children():
		child.queue_free()
		
	# create visual slots for the chest
	for i in range(chest.inventory.items.size()):
		var new_slot: InventorySlot = slot_scene.instantiate()
		new_slot.target_inventory = chest.inventory
		new_slot.slot_index = i
		chest_grid.add_child(new_slot)
		new_slot.update_slot(chest.inventory.items[i])
		
	chest.inventory.inventory_updated.connect(refresh_ui)
	
	if Globals.player:
		var player_inv_ui = Globals.player.get_node_or_null("inventory_ui/inventory_container")
		var armor_ui = Globals.player.get_node_or_null("inventory_ui/armor_container")
		
		var standard_crafting_ui = Globals.player.get_node_or_null("inventory_ui/crafting_container")
		var furnace_ui = Globals.player.get_node_or_null("inventory_ui/furnace_container")
		var bench_ui = Globals.player.get_node_or_null("inventory_ui/crafting_bench_container")
		
		if player_inv_ui: 
			player_inv_ui.show()
		if armor_ui: 
			armor_ui.show()
		
		# Force all crafting menus to hide
		if standard_crafting_ui: 
			standard_crafting_ui.hide()
		if furnace_ui: 
			furnace_ui.hide()
		if bench_ui: 
			bench_ui.hide()

func close_chest() -> void:
	hide()
	if current_chest:
		if multiplayer.is_server():
			current_chest.release_chest()
		else:
			current_chest.release_chest.rpc_id(Globals.SERVER_ID)
			
		if current_chest.inventory.inventory_updated.is_connected(refresh_ui):
			current_chest.inventory.inventory_updated.disconnect(refresh_ui)
			
	if Globals.player:
		var player_inv_ui = Globals.player.get_node_or_null("inventory_ui/inventory_container")
		var armor_ui = Globals.player.get_node_or_null("inventory_ui/armor_container")
		
		if player_inv_ui:
			player_inv_ui.hide()
		if armor_ui:
			armor_ui.hide()
	current_chest = null
	
	

func refresh_ui() -> void:
	if not current_chest: return
	
	var all_slots = chest_grid.get_children()
	for i in range(current_chest.inventory.items.size()):
		if i < all_slots.size():
			all_slots[i].update_slot(current_chest.inventory.items[i])
