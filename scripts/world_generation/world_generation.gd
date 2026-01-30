class_name WorldGeneration
extends Node

# --- Signals --- #
signal done_generating()

# --- Variables --- #
var generating := false

var display_seed: String
var logical_seed: String

# --- Functions --- #
func generate_world() -> void:
	print("[Wizbowo's Conquest] Generating World")
	generating = true
	
	# perform passes
	ResetPass.new().start_pass(self)
	
	# create terrain
	TerrainPass.new().start_pass(self)
	
	# cleanup
	SpawnPass.new().start_pass(self)
	
	generating = false
	done_generating.emit()
