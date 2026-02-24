class_name ItemToolObject
extends Node2D

# --- Variables --- #
## A list of [class Node2D]s that get disabled when simulating an item action.
## [br]This is done by setting each node's [member Node.process_mode] to
## [member Node.PROCESS_MODE_DISABLED]
@export var disabled_on_simulate: Array[Node2D] = []

# --- Functions --- #
func set_to_simulate() -> void:
	for node in disabled_on_simulate:
		node.process_mode = Node.PROCESS_MODE_DISABLED
