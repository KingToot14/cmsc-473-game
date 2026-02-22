class_name InventorySlot
extends Control

# --- Variables --- #
@onready var icon = $'item'
@onready var count_label = $'count_label'

var current_item: Inventory.ItemStack

# --- Functions --- #
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
