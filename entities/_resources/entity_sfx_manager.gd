class_name EntitySfxManager
extends AudioStreamPlayer2D

# --- Variables --- #
@export var sound_effects: Dictionary[StringName, AudioStream] = {}

# --- Functions --- #
func play_sfx(sfx_name: StringName) -> void:
	if multiplayer.is_server() or not get_stream_playback():
		return
	
	# play sfx
	get_stream_playback().play_stream(sound_effects[sfx_name])
