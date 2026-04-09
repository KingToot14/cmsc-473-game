class_name CraftingManager
extends Node

static func can_craft(recipe: Recipe, inventory: Inventory) -> bool:
	# Enforce type safety on the dictionary if possible.
	# If your recipe.ingredients is strictly typed as Dictionary[int, int],
	# you avoid string conversion bugs entirely.
	for key in recipe.ingredients:
		# Use Godot's built-in String-to-int method which handles invisible characters better
		var item_id: int = key if key is int else str(key).to_int()
		var required_amount: int = recipe.ingredients[key]
		var total_found: int = 0
	
		for stack in inventory.items:
			if not stack.is_empty() and stack.item_id == item_id:
				total_found += stack.count
	
		if total_found < required_amount:
			return false
			
	return true

static func craft_item(recipe: Recipe, inventory: Inventory) -> void:
	# If this is a multiplayer game with shared inventories, you may need a Mutex 
	# or an RPC lock around this entire function to prevent race conditions.
	if not can_craft(recipe, inventory):
		return
	
	# Safely remove ingredients
	for key in recipe.ingredients:
		var item_id: int = key if key is int else str(key).to_int()
		inventory.remove_item(item_id, recipe.ingredients[key])
	
	# Add the result
	inventory.add_item(recipe.result_item_id, recipe.result_amount)
