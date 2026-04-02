class_name ArmorSlot
extends InventorySlot

@export var expected_type: ArmorItem.ArmorType

func _gui_input(event: InputEvent) -> void:
	# Breadcrumb 1: Did the UI even feel the click?
	if event is InputEventMouseButton and event.pressed:
		print("1. CLICK DETECTED ON ARMOR SLOT ", slot_index)
		
	if is_display_only:
		return
		
	if event.is_action_pressed(&"inventory_item_transfer"):
		print("2. INPUT ACTION REGISTERED")
		
		if not target_inventory or not Globals.player:
			print("ERROR: Target inventory or player is null!")
			return
			
		if target_inventory == Globals.player.my_inventory:
			print("3. CALLING INVENTORY FUNCTION")
			target_inventory.interact_with_armor_slot(expected_type)
			
		get_viewport().set_input_as_handled()
