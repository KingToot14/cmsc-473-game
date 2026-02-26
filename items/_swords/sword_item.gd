class_name SwordItem
extends SwingItem

# --- Variables --- #


# --- Functions --- #
func handle_interact_mouse(player: PlayerController, mouse_position: Vector2) -> void:
	# play swing sfx
	player.sfx.play_sfx(&'whoosh', 8.0)
	
	super(player, mouse_position)
