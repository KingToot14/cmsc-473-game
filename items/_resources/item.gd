class_name Item
extends Resource

# --- Enums --- #
enum ItemType {
	MATERIAL,
	BLOCK,
	CONSUMABLE
}

# --- Variables --- #
var item_id: int = 0

@export var item_name: String
@export var texture: Texture2D

@export_multiline var tooltip: String

@export var item_type: ItemType
@export var max_stack: int = 99 #pretty sure this is gonna end up being extra

# --- Functions --- #
#region Interactions
func handle_interact_mouse(_mouse_position: Vector2) -> void:
	pass

func handle_interact_key() -> void:
	pass

#endregion

#region Helper Functions
func is_point_in_range(position: Vector2, range_modifier := 0) -> bool:
	var player: PlayerController = Globals.player
	var player_range: float = (player.base_range + range_modifier) * TileManager.TILE_SIZE
	
	return position.distance_to(player.center_point) <= player_range

#endregion
