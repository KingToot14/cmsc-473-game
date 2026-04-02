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
		
	if event.is_action_pressed(&"inventory_item_transfer"):
		if not target_inventory or not Globals.player:
			return
			
		if target_inventory == Globals.player.my_inventory:
			target_inventory.interact_with_armor_slot(expected_type)
			
		get_viewport().set_input_as_handled()
