class_name AcornEntityInfo
extends TileEntityInfo

# --- Variables --- #
@export var preview_sprites: Dictionary[TreeEntity.TreeVariant, Texture2D] = {}

var curr_variant := TreeEntity.TreeVariant.FOREST

# --- Functions --- #
func setup_placement_preview(mouse_position: Vector2) -> void:
	# set tile position
	var preview := Globals.mouse.placement_preview
	
	var pos := mouse_position + preview_position_offset
	
	var tile_pos := TileManager.world_to_tile(floori(pos.x), floori(pos.y))
	var snapped_pos := TileManager.tile_to_world(tile_pos.x, tile_pos.y)
	
	# get variant
	var variant := AcornEntity.get_variant(tile_pos)
	
	if variant == -1:
		variant = curr_variant
	else:
		curr_variant = variant as TreeEntity.TreeVariant
	
	# update preview
	preview.global_position = snapped_pos + preview_sprite_offset
	preview.texture = preview_sprites[variant]
