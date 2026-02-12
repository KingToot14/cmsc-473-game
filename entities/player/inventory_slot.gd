extends PanelContainer
#uncomment this all once we have sprites for the inventory
#@onready var icon = $Icon #change to the correct name of TextureRect
#@onready var count_label = $CountLabel #change to correct name of Label

#func update_slot(stack: inventory.ItemStack):
	#if stack.is_empty():
		#icon.texture = null
		#count_label.text = ""
	#else:
		#icon.texture = stack.item.texture
		## Only show numbers if there is more than 1 item
		#count_label.text = str(stack.count) if stack.count > 1 else ""
