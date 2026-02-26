class_name Inventory
extends RefCounted

# --- Signals --- #
signal inventory_updated

# --- Variables --- #
const INVENTORY_SLOTS := 50

var items: Array[ItemStack] = []
var hotbar_slot := 0
var held_item := ItemStack.new(-1, 0)
# --- Functions --- #
func _init():
	for i in range(INVENTORY_SLOTS): # 50 empty inventory slots
		items.append(ItemStack.new(-1, 0)) # list of items stored in items array

#region Inventory Management
func add_item(item_id: int, amount: int) -> int:
	var item: Item = ItemDatabase.get_item(item_id)
	
	if not item:
		return amount
	
	# attempt to add to existing stacks
	for stack in items:
		if not stack.is_empty() and stack.item_id == item_id:
			var space = item.max_stack - stack.count
			var adding = min(space, amount)
			stack.count += adding
			amount -= adding
			if amount <= 0: 
				inventory_updated.emit()
				return 0
	
	# add to first empty stack
	for stack in items:
		if stack.is_empty():
			stack.item_id = item_id
			stack.count = amount
			inventory_updated.emit()
			return 0
			
	return amount # Return leftovers if full

func remove_item(item_id: int, count: int) -> void:
	var item: Item = ItemDatabase.get_item(item_id)
	
	if not item:
		return
	
	for stack in items:
		if count <= 0:
			break
		
		# If this stack contains the item, remove as much as we can
		if not stack.is_empty() and stack.item_id == item_id:
			var diff = stack.count - count
			stack.count = max(stack.count - count, 0)
			
			if diff <= 0:
				stack.item_id = -1
				count = abs(diff)
			else:
				count = 0
	
	inventory_updated.emit()
#Unique inventory stuff: compare owner_id from player controler with multiplayer.get_unique_id() also from player controler

# Logic to handle picking up/swapping items at a specific slot
func interact_with_slot(index: int) -> void:
	print('interacting with slot')
	var slot_item = items[index]
	
	# If both are empty, do nothing
	if held_item.is_empty() and slot_item.is_empty():
		return
		
	# Scenario 1: Pick up (Mouse empty, Slot full)
	if held_item.is_empty() and not slot_item.is_empty():
		held_item.item_id = slot_item.item_id
		held_item.count = slot_item.count
		
		slot_item.item_id = -1
		slot_item.count = 0
		print('Scenario 1')
		
	# Scenario 2: Place (Mouse full, Slot empty)
	elif not held_item.is_empty() and slot_item.is_empty():
		slot_item.item_id = held_item.item_id
		slot_item.count = held_item.count
		
		held_item.item_id = -1
		held_item.count = 0
		print('Scenario 2')
		
	# Scenario 3: Merge (Both full, SAME item ID)
	elif not held_item.is_empty() and not slot_item.is_empty() and held_item.item_id == slot_item.item_id:
		var item_data: Item = ItemDatabase.get_item(slot_item.item_id)
		var max_stack = item_data.max_stack
		var space_left = max_stack - slot_item.count
		# If there is room in the slot, pour items in from the held stack
		if space_left > 0:
			var amount_to_move = min(space_left, held_item.count)
			slot_item.count += amount_to_move
			held_item.count -= amount_to_move
			
			# If we emptied the held stack, clear it
			if held_item.count <= 0:
				held_item.item_id = -1
				held_item.count = 0
		print('Scenario 3')
				
	# Scenario 4: Swap (Both full, DIFFERENT item IDs)
	elif not held_item.is_empty() and not slot_item.is_empty() and held_item.item_id != slot_item.item_id:
		var temp_id = slot_item.item_id
		var temp_count = slot_item.count
		
		slot_item.item_id = held_item.item_id
		slot_item.count = held_item.count
		
		held_item.item_id = temp_id
		held_item.count = temp_count
		print('Scenario 4')
	
	# Update the UI
	inventory_updated.emit()

func remove_item_at(item_id: int, count: int, slot: int) -> void:
	var item: Item = ItemDatabase.get_item(item_id)
	
	if not item:
		return
	
	var stack := items[slot]
	
	# If this stack contains the item, remove as much as we can
	if not stack.is_empty() and stack.item_id == item_id:
		var diff = stack.count - count
		stack.count = max(stack.count - count, 0)
		
		if diff <= 0:
			stack.item_id = -1
			count = abs(diff)
		else:
			count = 0
	
	inventory_updated.emit()

func load_inventory() -> void:
	# TODO: fetch inventory from database
	
	# if database entry not available, setup standard inventory
	add_item(6, 1)		# wooden sword
	add_item(7, 1) 		#wooden pickaxe
	add_item(3, 30)		# dirt blocks
	add_item(4, 10)		# stone blocks


#endregion

#region Selected Item
func get_selected_item() -> ItemStack:
	# TODO: Check item held by mouse
	
	# If no item held in mouse, return current hotbar item
	return items[hotbar_slot]

func has_item(item_id: int, count := 1) -> bool:
	for stack in items:
		# If this stack contains the item, remove as much as we can
		if not stack.is_empty() and stack.item_id == item_id:
			var diff = stack.count - count
			
			if diff < 0:
				count = abs(diff)
			else:
				return true
	
	return false

#endregion

# --- Classes --- #
class ItemStack:
	var item_id: int = -1
	var count: int = 0 #quantity of a specific stack
	
	func _init(p_item: int = -1, p_count: int = 0):
		item_id = p_item
		count = p_count

	func is_empty() -> bool:
		return item_id < 0 or count <= 0
