class_name CraftingManager
extends Node

static func can_craft(recipe: Recipe, inventory: Inventory) -> bool:
	for key in recipe.ingredients:
		var item_id = int(str(key)) # Force the key to be an integer
		var required_amount = recipe.ingredients[key]
		var total_found = 0
		
		for stack in inventory.items:
			if not stack.is_empty() and stack.item_id == item_id:
				total_found += stack.count
		
		if total_found < required_amount:
			return false
	return true

static func craft_item(recipe: Recipe, inventory: Inventory) -> void:
	if not can_craft(recipe, inventory):
		return
		
	# Remove ingredients 
	for key in recipe.ingredients:
		var item_id = int(str(key)) # Force the key to be an integer
		inventory.remove_item(item_id, recipe.ingredients[key])
	
	# Add the result 
	inventory.add_item(recipe.result_item_id, recipe.result_amount)
