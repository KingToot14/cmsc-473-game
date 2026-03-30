class_name SettlePass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Settling Down"

func perform_pass(_gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	
	# settle sand
	pass
	
	# settle water
	Globals.water_updater.settle_all()
	
	await Globals.water_updater.settled
