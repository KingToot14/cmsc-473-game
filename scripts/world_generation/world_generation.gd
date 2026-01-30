class_name WorldGeneration
extends Node

# --- Variables --- #
var display_seed: String
var logical_seed: String

# --- Functions --- #
func generate_world() -> void:
	print("[Wizbowo's Conquest] Generating World")
	
	# perform passes
	ResetPass.new().start_pass(self)
	
	# create terrain
	TerrainPass.new().start_pass(self)
	
	# cleanup
	SpawnPass.new().start_pass(self)
