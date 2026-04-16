class_name CraftingBenchUI
extends Control

@export var crafting_button_scene: PackedScene
@onready var crafting_bench_buttons = $crafting_bench_buttons

# the item IDs for the wooden sword, pickaxe, hammer, and axe
const CRAFTING_BENCH_ITEM_IDS = [6, 7, 9, 10, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 50, 53, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87]

var current_bench: CraftingBenchEntity

func _ready() -> void:
	hide()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_action_pressed("interact") or event.is_action_pressed("inventory_toggle"):
		close_crafting_bench()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if visible and current_bench:
		if not is_instance_valid(current_bench) or current_bench.is_queued_for_deletion():
			close_crafting_bench()
		elif Globals.player and not Globals.player.is_point_in_range(current_bench.global_position):
			close_crafting_bench()

func setup_bench_ui() -> void:
	for child in crafting_bench_buttons.get_children():
		child.queue_free()
	
	var player_inv = Globals.player.my_inventory
	
	for i in range(player_inv.recipes.size()):
		var recipe = player_inv.recipes[i]
		
		# ONLY add the recipe if it is in our designated bench list
		if recipe.result_item_id in CRAFTING_BENCH_ITEM_IDS:
			var btn = crafting_button_scene.instantiate()
			btn.recipe = recipe
			btn.recipe_index = i 
			crafting_bench_buttons.add_child(btn)

func open_crafting_bench(bench: CraftingBenchEntity) -> void:
	if current_bench == bench:
		return
	if current_bench:
		close_crafting_bench()
	
	current_bench = bench
	
	if crafting_bench_buttons.get_child_count() == 0:
		setup_bench_ui()
		
	refresh_ui()
	show()
	
	if Globals.player:
		var player_inv_ui = Globals.player.get_node_or_null("inventory_ui/inventory_container")
		var armor_ui = Globals.player.get_node_or_null("inventory_ui/armor_container")
		var standard_crafting_ui = Globals.player.get_node_or_null("inventory_ui/crafting_container")
		var furnace_ui = Globals.player.get_node_or_null("inventory_ui/furnace_container")
		
		if player_inv_ui: player_inv_ui.show()
		if armor_ui: armor_ui.show()
		
		# Hide the other crafting menus so they don't overlap
		if standard_crafting_ui: standard_crafting_ui.hide()
		if furnace_ui: furnace_ui.hide()

func close_crafting_bench() -> void:
	hide()
	
	# Break the ghost hover trap
	Globals.mouse.cursor_locked = false
	Globals.set_cursor(Globals.CursorType.ARROW)
	
	if current_bench:
		if multiplayer.is_server():
			current_bench.release_bench()
		else:
			current_bench.release_bench.rpc_id(Globals.SERVER_ID)
			
	if Globals.player:
		var player_inv_ui = Globals.player.get_node_or_null("inventory_ui/inventory_container")
		var armor_ui = Globals.player.get_node_or_null("inventory_ui/armor_container")
		
		if player_inv_ui: player_inv_ui.hide()
		if armor_ui: armor_ui.hide()
			
	current_bench = null

func refresh_ui() -> void:
	if not Globals.player: return
	
	var player_inv = Globals.player.my_inventory
	for button in crafting_bench_buttons.get_children():
		if button is CraftingButton: 
			button.update_availability(player_inv)
