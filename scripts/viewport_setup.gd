class_name ViewportSetup
extends SubViewport

# --- Variables --- #
@export var target_layer: int

# --- Functions --- #
func _ready() -> void:
	var viewport := get_tree().root
	world_2d = viewport.world_2d
	
	viewport.set_canvas_cull_mask_bit(target_layer, false)
