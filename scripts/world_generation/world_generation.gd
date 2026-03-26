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

var hill_positions: Array[Vector2i] = []
var lake_positions: Array[Vector2i] = []

var winter_on_right := false

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
	
	winter_on_right = rng.randf() > 0.5
	
	# perform passes
	await run_pass(ResetPass.new())
	
	# create terrain
	await run_pass(TerrainPass.new())
	await run_pass(DirtWallPass.new())
	
	await run_pass(HillPass.new())
	
	await run_pass(RocksInDirtPass.new())
	await run_pass(DirtInRocksPass.new())
	
	await run_pass(SmallHolesPass.new())
	await run_pass(CavePass.new())
	
	await run_pass(SandPatchPass.new())
	await run_pass(ClayPatchPass.new())
	
	await run_pass(OrePass.new())
	
	await run_pass(LakePass.new())
	await run_pass(OceanPass.new())
	
	# biomes
	await run_pass(DirtToSnowPass.new())
	await run_pass(StoneToIcePass.new())
	
	# after terrain, before decoration
	await run_pass(SmoothPass.new())
	
	# decoration
	await run_pass(TreePass.new())
	
	# cleanup
	await run_pass(GrassPass.new())
	await run_pass(SpawnPass.new())
	
	# add tiles that need updates to the queue
	await run_pass(SettlePass.new())
	await run_pass(LightPass.new())
	#await run_pass(ActivationPass.new())
	
	# start block updates
	Globals.block_updater.set_physics_process(true)
	Globals.water_updater.set_active()
	
	print("[Wizbowo's Conquest] Done Generating World")
	
	generating = false
	done_generating.emit()

func run_pass(gen_pass: WorldGenPass) -> void:
	gen_pass.start_pass(self)
	
	if gen_pass.running:
		await gen_pass.done_with_pass
	
	await get_tree().process_frame
