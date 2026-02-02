class_name WorldGeneration
extends Node

# --- Signals --- #
signal done_generating()

# --- Enums --- #
enum SeedType {
	STANDARD,
	SUPERFLAT
}

# --- Variables --- #
var generating := false

var seed_type := SeedType.STANDARD
var world_seed: int

var rng: RandomNumberGenerator

var surface_high := 0
var surface_low := 0
var underground_high := 0
var underground_low := 0

# --- Functions --- #
func set_seed(new_seed: Variant) -> void:
	# get special seeds
	if new_seed is String:
		new_seed = new_seed.lower()
	
	if new_seed in [0, 'super_flat', 'superflat']:
		seed_type = SeedType.SUPERFLAT
		new_seed = randi()
	
	# hash seed if needed
	if new_seed is String:
		new_seed = hash(new_seed)
	
	world_seed = new_seed

func generate_world() -> void:
	print("[Wizbowo's Conquest] Generating World")
	generating = true
	
	# set rng
	rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	
	# perform passes
	await run_pass(ResetPass.new())
	
	# create terrain
	await run_pass(TerrainPass.new())
	
	# after terrain, before decoration
	await run_pass(SmoothPass.new())
	
	# cleanup
	await run_pass(GrassPass.new())
	await run_pass(SpawnPass.new())
	
	generating = false
	done_generating.emit()

func run_pass(gen_pass: WorldGenPass) -> void:
	gen_pass.start_pass(self)
	
	if gen_pass.running:
		await gen_pass.done_with_pass
	
	await get_tree().process_frame
