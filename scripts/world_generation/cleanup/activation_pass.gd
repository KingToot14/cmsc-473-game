class_name ActivationPass
extends WorldGenPass

# --- Variables --- #


# --- Functions --- #
func get_pass_name() -> String:
	return "Activating Tiles"

func perform_pass(_gen: WorldGeneration) -> void:
	var world_size := Globals.world_size
	var updater := Globals.block_updater
	
	# add blocks to the queue
	for x in range(1, world_size.x - 1):
		for y in range(1, world_size.y - 1):
			updater.add_to_queue(Vector2i(x, y))
	
	# start block updates
	updater.set_physics_process(true)
