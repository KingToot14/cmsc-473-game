class_name ChunkLoader
extends Node

# --- Variables --- #
const LOAD_RANGE := Vector2i(4, 2)

@export var player: PlayerController

# --- Functions --- #
func send_whole_area() -> void:
	var center_chunk := TileManager.world_to_chunk(player.position.x, player.position.y)
	var start_chunk := center_chunk - LOAD_RANGE
	var end_chunk := center_chunk + LOAD_RANGE
