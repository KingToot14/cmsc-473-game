class_name Entity
extends Node2D

# --- Variables --- #
var id := 0
var data: Dictionary[StringName, Variant]

# --- Functions --- #
func initialize(new_id: int, spawn_data: Dictionary[StringName, Variant]) -> void:
	id = new_id
	data = spawn_data
	
	setup_entity()

func setup_entity() -> void:
	pass
