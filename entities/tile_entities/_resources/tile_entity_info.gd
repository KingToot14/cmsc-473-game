class_name TileEntityInfo
extends EntityInfo

# --- Variables --- #
@export var preview_sprite: Texture2D
@export var preview_sprite_variants: Dictionary[StringName, Texture2D] = {}

@export var preview_position_offset := Vector2(-4.0, 0.0)
@export var preview_sprite_offset := Vector2(8.0, 0.0)

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

@rpc('any_peer', 'call_remote', 'reliable')
@warning_ignore('unused_parameter')
func create_entity(player_id: int, tile_pos: Vector2i, variant: StringName) -> void:
	entity_script.create(tile_pos, variant)
