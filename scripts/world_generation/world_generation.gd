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
	await run_pass(ResetPass.new())
	
	# create terrain
	await run_pass(TerrainPass.new())
	
	# cleanup
	await run_pass(SpawnPass.new())
	
	generating = false
	done_generating.emit()

func run_pass(gen_pass: WorldGenPass) -> void:
	gen_pass.start_pass(self)
	
	if gen_pass.running:
		await gen_pass.done_with_pass
	
	await get_tree().process_frame
