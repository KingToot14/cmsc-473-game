class_name TileEntity
extends Entity

# --- Variables --- #
var tile_position: Vector2i:
	set(_pos):
		tile_position = _pos
		global_position = TileManager.tile_to_world(_pos.x, _pos.y, false)

# --- Functions --- #
func update_preview(tile_pos: Vector2i) -> void:
	tile_position = tile_pos

func attempt_placement() -> bool:
	return false
