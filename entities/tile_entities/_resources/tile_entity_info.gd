class_name TileEntityInfo
extends EntityInfo

# --- Variables --- #
@export var preview_sprite: Texture2D

@export var preview_position_offset := Vector2(-4.0, 0.0)
@export var preview_sprite_offset := Vector2(8.0, 0.0)

# --- Functions --- #
func setup_placement_preview(mouse_position: Vector2) -> void:
	# set tile position
	var preview := Globals.mouse.placement_preview
	
	var pos := mouse_position + preview_position_offset
	
	var tile_pos := TileManager.world_to_tile(floori(pos.x), floori(pos.y))
	var snapped_pos := TileManager.tile_to_world(tile_pos.x, tile_pos.y)
	
	preview.global_position = snapped_pos + preview_sprite_offset
	preview.texture = preview_sprite
