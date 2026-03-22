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
	for x in range(4, world_size.x - 4):
		for y in range(4, world_size.y - 4):
			Globals.water_updater.add_to_queue(Vector2i(x, y))
	
	Globals.water_updater.settle_all()
	
	await Globals.water_updater.settled
