class_name FurnaceUI
extends Control

@export var crafting_button_scene: PackedScene
@onready var furnace_buttons = $furnace_buttons

# the item IDs for Copper, Iron, Silver, and Gold bars
const FURNACE_ITEM_IDS = [95, 96, 97, 98]

var current_furnace: FurnaceEntity

func _ready() -> void:
	hide()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	# close the furnace if you press interact or inventory toggle
	if event.is_action_pressed("interact") or event.is_action_pressed("inventory_toggle"):
		close_furnace()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if visible and current_furnace:
		# if the furnace was destroyed or player walks too far away, close UI
		if not is_instance_valid(current_furnace) or current_furnace.is_queued_for_deletion():
			close_furnace()
		elif Globals.player and not Globals.player.is_point_in_range(current_furnace.global_position):
			close_furnace()

func setup_furnace_ui() -> void:
	# clean up old buttons
	for child in furnace_buttons.get_children():
		child.queue_free()
	
	var player_inv = Globals.player.my_inventory
	
	for i in range(player_inv.recipes.size()):
		var recipe = player_inv.recipes[i]
		
		# only add the recipe if it creates one of our bars
		if recipe.result_item_id in FURNACE_ITEM_IDS:
			var btn = crafting_button_scene.instantiate()
			btn.recipe = recipe
			btn.recipe_index = i # This absolute index maintains sync with inventory.gd
			furnace_buttons.add_child(btn)

func open_furnace(furnace: FurnaceEntity) -> void:
	if current_furnace == furnace:
		return
	if current_furnace:
		close_furnace()
	
	current_furnace = furnace
	
	# only setup the buttons once to save performance
	if furnace_buttons.get_child_count() == 0:
		setup_furnace_ui()
		
	refresh_ui()
	show()
	
	# open Player Inventory and Armor, but HIDE normal crafting
	if Globals.player:
		var player_inv_ui = Globals.player.get_node_or_null("inventory_ui/inventory_container")
		var armor_ui = Globals.player.get_node_or_null("inventory_ui/armor_container")
		var standard_crafting_ui = Globals.player.get_node_or_null("inventory_ui/crafting_container")
		
		if player_inv_ui:
			player_inv_ui.show()
		if armor_ui:
			armor_ui.show()
		if standard_crafting_ui:
			standard_crafting_ui.hide()

func close_furnace() -> void:
	hide()
	if current_furnace:
		if multiplayer.is_server():
			current_furnace.release_furnace()
		else:
			current_furnace.release_furnace.rpc_id(Globals.SERVER_ID)
			
	# hide the inventory menus when we step away from the furnace
	if Globals.player:
		var player_inv_ui = Globals.player.get_node_or_null("inventory_ui/inventory_container")
		var armor_ui = Globals.player.get_node_or_null("inventory_ui/armor_container")
		
		if player_inv_ui:
			player_inv_ui.hide()
		if armor_ui:
			armor_ui.hide()
			
	current_furnace = null

func refresh_ui() -> void:
	if not Globals.player: return
	
	var player_inv = Globals.player.my_inventory
	for button in furnace_buttons.get_children():
		if button is CraftingButton: # ensure your button script has class_name CraftingButton
			button.update_availability(player_inv)
