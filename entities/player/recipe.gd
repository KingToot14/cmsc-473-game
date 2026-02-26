class_name Recipe
extends Resource

@export var result_item_id: int
@export var result_amount: int = 1
@export var ingredients: Dictionary # Dictionary of {item_id: count}
