class_name TileEntityHitbox
extends Area2D

# --- Signals --- #
signal interacted_with()

# --- Variables --- #
@export var entity: Node2D

# --- Functions --- #
func _ready() -> void:
	# setup signals
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)

func _on_mouse_enter() -> void:
	# set on hover
	Globals.hovered_hitbox = self

func _on_mouse_exit() -> void:
	# clear on un-hover
	if Globals.hovered_hitbox == self:
		Globals.hovered_hitbox = null
