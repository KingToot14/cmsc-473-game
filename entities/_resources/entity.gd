class_name Entity
extends Node2D

# --- Variables --- #
var id := 0

# --- Functions --- #
func initialize(new_id: int, spawn_data: Dictionary[StringName, Variant]) -> void:
	id = new_id
	
	print("Spawned entity: %s" % new_id)
