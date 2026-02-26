class_name CraftingButton
extends Button

@export var recipe: Recipe
@onready var result_slot = $h_box_container/result_slot
#@onready var name_label = $h_box_container/recipe_name

func _ready():
	if not recipe:
		return
		
	# Show what this recipe makes using your InventorySlot logic
	var temp_stack = Inventory.ItemStack.new(recipe.result_item_id, recipe.result_amount)
	result_slot.update_slot(temp_stack)
	
	# Get the item's name from your database for the label
	var item_data: Item = ItemDatabase.get_item(recipe.result_item_id)
	#name_label.text = item_data.item_name
	
	# Connect the button click to our function
	pressed.connect(_on_pressed)

func update_availability(inv: Inventory):
	# Enable/Disable based on whether the player has materials
	disabled = not CraftingManager.can_craft(recipe, inv)
	modulate.a = 1.0 if not disabled else 0.5

func _on_pressed():
	CraftingManager.craft_item(recipe, Globals.player.my_inventory)
