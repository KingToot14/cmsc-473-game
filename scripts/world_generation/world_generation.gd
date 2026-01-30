class_name WorldGeneration
extends Node

# --- Variables --- #
var world_size := Vector2i(16*10, 16*10)
var world_spawn := Vector2i.ZERO

var display_seed: String
var logical_seed: String

# --- Functions --- #
func generate_world() -> void:
	# perform passes
	ResetPass.new().start_pass(self)
	
	# create terrain
	TerrainPass.new().start_pass(self)
	
	# cleanup
	SpawnPass.new().start_pass(self)
