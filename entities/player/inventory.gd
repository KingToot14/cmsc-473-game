class_name inventory
extends RefCounted
signal inventory_updated
var items: Array[ItemStack] = []

func _init():
	for i in range(20): #20 empty inventory slots
		items.append(ItemStack.new(null, 0)) #list of items stored in items array

func add_item(new_item: Item, amount: int) -> int:
	for stack in items:
		if not stack.is_empty() and stack.item.item_id == new_item.item_id:
			var space = stack.item.max_stack - stack.count
			var adding = min(space, amount)
			stack.count += adding
			amount -= adding
			if amount <= 0: 
				inventory_updated.emit()
				return 0

	for stack in items:
		if stack.is_empty():
			stack.item = new_item
			stack.count = amount
			inventory_updated.emit()
			return 0
			
	return amount # Return leftovers if full


func remove_item(item: Item, count: int) -> void:
	for stack in items:
		if count <= 0:
			break
		# If this stack contains the item, remove as much as we can
		if not stack.is_empty() and stack.item.item_id == item.item_id:
			var diff = stack.count - count
			stack.count = max(stack.count - count, 0)
			if diff <= 0:
				stack.item = null
				count = abs(diff)
			else:
				count = 0
	inventory_updated.emit()


class ItemStack:
	var item: Item
	var count: int = 0 #quantity of a specific stack
	
	func _init(p_item: Item = null, p_count: int = 0):
		item = p_item
		count = p_count

	func is_empty() -> bool:
		return item == null or count <= 0
