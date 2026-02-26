class_name InventorySlot
extends Control

# --- Variables --- #
@onready var icon = $'item'
@onready var count_label = $'count_label'

@export var is_display_only := false

var current_item: Inventory.ItemStack

var is_hotbar := false

# --- Functions --- #
func _ready() -> void:
	# If this is a crafting slot, make sure it (and its children) ignore the mouse
	# so the click passes through to the CraftingButton underneath!
	if is_display_only:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		$'backing'.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$'item'.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$'count_label'.mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_slot(stack: Inventory.ItemStack):
	current_item = stack
	
	if stack.is_empty():
		icon.texture = null
		count_label.text = ""
	else:
		var item: Item = ItemDatabase.get_item(stack.item_id)
		
		icon.texture = item.texture
		# Only show numbers if there is more than 1 item
		count_label.text = str(stack.count) if stack.count > 1 else ""

func set_selected(value: bool) -> void:
	# only hotbar slots can be selected
	if not is_hotbar:
		return
	
	# only switch hotbars when items are not in use
	if not Globals.player.can_act():
		return
	
	if value:
		# update panel size
		$'backing'.offset_left   = -10
		$'backing'.offset_top    = -10
		$'backing'.offset_right  =  10
		$'backing'.offset_bottom =  10
		
		# update panel style
		$'backing'.region_rect.position.x = 8.0
		
		# update player's hotbar slot
		Globals.player.my_inventory.hotbar_slot = get_index()
		
		# update other hotbar slots
		for slot: InventorySlot in get_tree().get_nodes_in_group(&'hotbar_slot'):
			if slot == self:
				continue
			
			slot.set_selected(false)
	else:
		# update panel size
		$'backing'.offset_left   = -9
		$'backing'.offset_top    = -9
		$'backing'.offset_right  =  9
		$'backing'.offset_bottom =  9
		
		# update panel style
		$'backing'.region_rect.position.x = 0.0

func _gui_input(event: InputEvent) -> void:
	#Stop right here if it's just a visual slot
	if is_display_only:
		return
	if event.is_action_pressed(&"inventory_item_transfer"):
		# If inventory not open, stop here
		var inventory_container = Globals.player.get_node("inventory_ui/inventory_container")
		if not inventory_container.visible:
			return 
		
		var inventory = Globals.player.my_inventory
		# Calculate the correct index in the inventory array.
		var true_index = get_index()
		if not is_hotbar:
			# Because the main inventory slots are in a separate GridContainer, their get_index() starts back at 0. We need to offset them by the hotbar size!
			true_index += 10 
			
		inventory.interact_with_slot(true_index)
		
		# Tell Godot we handled this input so it doesn't click through the UI
		get_viewport().set_input_as_handled()
