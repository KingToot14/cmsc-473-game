class_name ArmorSlot
extends InventorySlot

# --- Variables
@export var slot_atlas: AtlasTexture

@export var expected_type: ArmorItem.ArmorType:
	set(_type):
		expected_type = _type
		
		match _type:
			ArmorItem.ArmorType.HEAD:
				slot_atlas.region = Rect2i(0, 0, 16, 16)
			ArmorItem.ArmorType.BODY:
				slot_atlas.region = Rect2i(16, 0, 16, 16)
			ArmorItem.ArmorType.LEGS:
				slot_atlas.region = Rect2i(0, 16, 16, 16)

func _gui_input(event: InputEvent) -> void:
	if is_display_only:
		return
		
	# Check for standard Left Click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if target_inventory:
			# Pass the enum value as the index (0, 1, or 2)
			target_inventory.interact_with_armor_slot(int(expected_type))
			get_viewport().set_input_as_handled()
			return

	# Keep your Shift+Click (transfer) logic if you want it
	if event.is_action_pressed(&"inventory_item_transfer"):
		if target_inventory:
			target_inventory.interact_with_armor_slot(int(expected_type))
			get_viewport().set_input_as_handled()
