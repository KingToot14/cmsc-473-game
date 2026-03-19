class_name BlockInfo
extends Resource

# --- Variables --- #
## The sprite to display when attempting to place this tile
@export var preview_sprite: Texture2D

## The tile's item_id to drop when this tile is broken. This will
## be ignored if [member custom_break_logic] is [code]true[/code].
@export var break_item_id := 0
## Whether or not this block has custom break logic. If [code]true[/code],
## breaking this block will have to be handled manually instead of just
## dropping the [member break_item_id].
@export var custom_break_logic := false

## The sound effect to play when this tile is broken.
@export var break_sfx: AudioStream
## Determines the volume of [member break_sfx] in decibels.
@export var break_volume: float

## The sound effect to play when this tile is placed.
@export var place_sfx: AudioStream
## Determines the volume of [member place_sfx] in decibels.
@export var place_volume: float
@export var block_health := 50

# --- Functions --- #
func setup_placement_preview(mouse_position: Vector2) -> void:
	# set tile position
	var preview := Globals.mouse.placement_preview
	
	var pos := mouse_position
	
	var tile_pos := TileManager.world_to_tile(floori(pos.x), floori(pos.y))
	var snapped_pos := TileManager.tile_to_world(tile_pos.x, tile_pos.y)
	
	preview.global_position = snapped_pos + Vector2(4.0, 4.0)
	preview.texture = preview_sprite
