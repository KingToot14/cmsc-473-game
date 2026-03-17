class_name BlockInfo
extends Resource

# --- Variables --- #
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

# --- Functions --- #
