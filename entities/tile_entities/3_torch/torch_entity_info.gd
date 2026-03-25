class_name TorchEntityInfo
extends TileEntityInfo

# --- Variables --- #


# --- Functions --- #
func setup_placement_preview(mouse_position: Vector2, variant: StringName) -> void:
	# set tile position
	var preview := Globals.mouse.placement_preview
	
	var pos := mouse_position + preview_position_offset
	
	var tile_pos := TileManager.world_to_tile(floori(pos.x), floori(pos.y))
	var snapped_pos := TileManager.tile_to_world(tile_pos.x, tile_pos.y)
	
	preview.global_position = snapped_pos + preview_sprite_offset
	
	# check for variants
	if len(preview_sprite_variants) > 0:
		var sprite: Texture2D = preview_sprite_variants.get(variant)
		if sprite:
			preview.texture = sprite
		else:
			preview.texture = preview_sprite
	else:
		preview.texture = preview_sprite
	
	# set texutre to atlas texture
	var atlas := AtlasTexture.new()
	atlas.atlas = preview.texture
	
	preview.texture = atlas
	
	# check anchored variety
	var anchor_type := TorchEntity.get_anchor_type(tile_pos)
	
	match anchor_type:
		TorchEntity.AnchorType.BOTTOM:
			atlas.region = Rect2i( 0, 0, 8, 16)
		TorchEntity.AnchorType.LEFT:
			atlas.region = Rect2i( 8, 0, 8, 16)
		TorchEntity.AnchorType.RIGHT:
			atlas.region = Rect2i(24, 0, 8, 16)
		_:
			atlas.region = Rect2i(16, 0, 8, 16)
