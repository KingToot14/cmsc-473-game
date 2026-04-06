class_name SettlePass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Settling Down"

func perform_pass(gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	# settle sand
	pass
	
	# settle water
	Globals.liquid_updater.settle_all(gen)
	
	await Globals.liquid_updater.settled
