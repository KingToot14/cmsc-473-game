class_name WorldGenPass
extends RefCounted

# --- Variables --- #
var allowed_seeds = []
var restricted_seeds = []

# --- Functions --- #
func set_allowed_seeds(seeds: Array[String]) -> WorldGenPass:
	allowed_seeds = seeds
	
	return self

func set_restricted_seeds(seeds: Array[String]) -> WorldGenPass:
	restricted_seeds = seeds
	
	return self

func start_pass(gen: WorldGeneration) -> void:
	# check seed restrictions
	if not allowed_seeds.is_empty() and gen.logical_seed not in allowed_seeds:
		return
	
	if not restricted_seeds.is_empty() and gen.logical_seed in restricted_seeds:
		return
	
	# perform pass
	perform_pass(gen)

func perform_pass(_gen: WorldGeneration) -> void:
	return
