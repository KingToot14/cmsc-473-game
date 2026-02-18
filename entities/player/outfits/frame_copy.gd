class_name FrameCopy
extends Sprite2D

# --- Variables --- #
@export var target: Sprite2D

# --- Functions --- #
func _ready() -> void:
	target.frame_changed.connect(update_frame)

func update_frame() -> void:
	frame = target.frame
