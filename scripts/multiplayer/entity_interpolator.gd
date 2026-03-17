class_name EntityInterpolator
extends SnapshotInterpolator

# --- Variables --- #


# --- Functions --- #
func perform_action(action_info: PackedByteArray) -> void:
	if root is Entity:
		root.handle_action(action_info)
