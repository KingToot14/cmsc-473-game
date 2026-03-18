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

## Whether or not the mouse is currently being pressed
var mouse_pressed := false

# --- Functions --- #
#region Interactions
@warning_ignore('unused_parameter')
func handle_process(_player: PlayerController, mouse_position: Vector2) -> void:
	pass

## Called from [class InputSynchronizer] when the player clicks on the screen
## with the mouse. Does not happen when clicking inside the inventory
func handle_interact_mouse_press(player: PlayerController, mouse_position: Vector2) -> void:
	mouse_pressed = true
	player.interpolator.queue_mouse_press(NetworkTime.time, item_id, mouse_position)

func handle_interact_mouse_release(player: PlayerController, mouse_position: Vector2) -> void:
	mouse_pressed = false
	player.interpolator.queue_mouse_release(NetworkTime.time, item_id, mouse_position)

## Called from [class InputSynchronizer] when the player presses the interact
## key on an item in the inventory
@warning_ignore('unused_parameter')
func handle_interact_key(player: PlayerController) -> void:
	pass

func handle_selected_start() -> void:
	pass

func handle_selected_end() -> void:
	pass

#endregion

#region Simulation
@warning_ignore('unused_parameter')
func simulate_process(player: PlayerController, mouse_position: Vector2) -> void:
	pass

## Called from [class InputSynchronizer] when the player clicks on the screen
## with the mouse. Does not happen when clicking inside the inventory.
## [br][br]Does not interact with the world, this function should be purely visual
@warning_ignore('unused_parameter')
func simulate_interact_mouse_press(player: PlayerController, mouse_position: Vector2) -> void:
	mouse_pressed = true

@warning_ignore('unused_parameter')
func simulate_interact_mouse_release(player: PlayerController, mouse_position: Vector2) -> void:
	mouse_pressed = false

## Called from [class InputSynchronizer] when the player presses the interact
## key on an item in the inventory.
## [br][br]Does not interact with the world, this function should be purely visual
@warning_ignore('unused_parameter')
func simulate_interact_key(player: PlayerController) -> void:
	pass

#endregion

#region Item Actions
@warning_ignore('unused_parameter')
## Called when the player selects this item either in the hotbar or as the held item
func item_selected(player: PlayerController, mouse_position) -> void:
	pass

@warning_ignore('unused_parameter')
## Called when the player deselects this item either in the hotbar or as the held item
func item_deselected(player: PlayerController, mouse_position) -> void:
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
