class_name Inventory
extends RefCounted

# --- Signals --- #
signal inventory_updated

# --- Variables --- #
const INVENTORY_SLOTS := 50

var items: Array[ItemStack] = []
var hotbar_slot := 0

# --- Functions --- #
func _init():
	for i in range(INVENTORY_SLOTS): #20 empty inventory slots
		items.append(ItemStack.new(-1, 0)) #list of items stored in items array

#region Inventory Management
func add_item(item_id: int, amount: int) -> int:
	var item: Item = ItemDatabase.get_item(item_id)
	
	if not item:
		return amount
	
	for stack in items:
		if not stack.is_empty() and stack.item_id == item_id:
			var space = item.max_stack - stack.count
			var adding = min(space, amount)
			stack.count += adding
			amount -= adding
			if amount <= 0: 
				inventory_updated.emit()
				return 0

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

func load_inventory() -> void:
	# TODO: fetch inventory from database
	
	# if database entry not available, setup standard inventory
	items[0].item_id = 6	# wooden sword
	items[0].count = 1
	
	items[1].item_id = 3	# dirt block
	items[1].count = 10

#endregion

#region Selected Item
func get_selected_item() -> ItemStack:
	# TODO: Check item held by mouse
	
	# If no item held in mouse, return current hotbar item
	return items[hotbar_slot]

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
