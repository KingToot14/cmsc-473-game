class_name ArmorSlot
extends InventorySlot

@export var expected_type: ArmorItem.ArmorType

func _gui_input(event: InputEvent) -> void:
	if is_display_only:
		return
		
	if event.is_action_pressed(&"inventory_item_transfer"):
		if not target_inventory or not Globals.player:
			return
			
		if target_inventory == Globals.player.my_inventory:
			target_inventory.interact_with_armor_slot(expected_type)
			
		get_viewport().set_input_as_handled()
