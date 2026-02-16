extends Control

# --- Variables --- #
@onready var icon = $'item'
@onready var count_label = $'count_label'

# --- Functions --- #
func update_slot(stack: Inventory.ItemStack):
	if stack.is_empty():
		icon.texture = null
		count_label.text = ""
	else:
		var item: Item = ItemDatabase.get_item(stack.item_id)
		
		icon.texture = item.texture
		# Only show numbers if there is more than 1 item
		count_label.text = str(stack.count) if stack.count > 1 else ""
