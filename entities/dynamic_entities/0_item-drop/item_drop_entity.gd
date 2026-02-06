class_name ItemDropEntity
extends Entity

# --- Variables --- #
var gravity := 5.0
var terminal_velocity

# --- Functions --- #
func _process(delta: float) -> void:
	super(delta)
	
	if interest_count == 0:
		return
	
	# gravity
