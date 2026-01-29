class_name WorldGeneration
extends Node

# --- Variables --- #
var world_size := Vector2i(8400, 2400)

var display_seed: String
var logical_seed: String

# --- Functions --- #
func generate_world() -> void:
	# perform passes
	ResetPass.new().start_pass(self)

func generate_chunks() -> void:
	pass
