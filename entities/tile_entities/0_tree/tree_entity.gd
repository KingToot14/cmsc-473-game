class_name TreeEntity
extends Entity

# --- Variables --- #


# --- Functions --- #
func setup_entity() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = data.get(&'branch_seed', 0)
	
	# create visuals
	
