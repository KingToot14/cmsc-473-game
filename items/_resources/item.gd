class_name Item
extends Resource

# --- Enums --- #
enum ItemType {
	MATERIAL,
	BLOCK,
	CONSUMABLE
}

# --- Variables --- #
## The internal item id for this item. This is overwritten at runtime
@export var item_id: int
## The item's name that appears in the tooltip UI
@export var item_name: String
## The item's texture that appears in the inventory
@export var texture: Texture2D

## The base item's description that appears at the top of the item's tooltip
@export_multiline var tooltip: String

## The item's type (might be removed in the future)
@export var item_type: ItemType
## How many of this item can be stacked at once
@export var max_stack: int = 9999 #pretty sure this is gonna end up being extra

# --- Functions --- #
#region Interactions
## Called from [class InputSynchronizer] when the player clicks on the screen
## with the mouse. Does not happen when clicking inside the inventory
func handle_interact_mouse(_player: PlayerController, _mouse_position: Vector2) -> void:
	pass

## Called from [class InputSynchronizer] when the player presses the interact
## key on an item in the inventory
func handle_interact_key(_player: PlayerController, ) -> void:
	pass

## Called from [class InputSynchronizer] when the player clicks on the screen
## with the mouse. Does not happen when clicking inside the inventory.
## [br][br]Does not interact with the world, this function should be purely visual
func simulate_interact_mouse(_player: PlayerController, _mouse_position: Vector2) -> void:
	pass

## Called from [class InputSynchronizer] when the player presses the interact
## key on an item in the inventory.
## [br][br]Does not interact with the world, this function should be purely visual
func simulate_interact_key(_player: PlayerController, ) -> void:
	pass

#endregion

#region Helper Functions
## Returns whether or not [param position] is in range of [param player].
## [br]Has an optional [param range_modifier] which gets added to
## [member PlayerController.base_range]
func is_point_in_range(player: PlayerController, position: Vector2, range_modifier := 0) -> bool:
	var player_range: float = (player.base_range + range_modifier) * TileManager.TILE_SIZE
	
	return position.distance_to(player.center_point) <= player_range

#endregion
