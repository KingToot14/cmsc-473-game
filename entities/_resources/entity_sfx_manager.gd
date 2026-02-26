class_name EntitySfxManager
extends AudioStreamPlayer2D

# --- Variables --- #
@export var sound_effects: Dictionary[StringName, AudioStream] = {}

# --- Functions --- #
func play_sfx(sfx_name: StringName, volume := 0.0) -> void:
	if multiplayer.is_server() or not get_stream_playback():
		return
	
	# play sfx
	#get_stream_playback().play_stream(sound_effects[sfx_name])
	
	var new_player := AudioStreamPlayer2D.new()
	new_player.max_distance = max_distance
	new_player.attenuation = attenuation
	
	new_player.stream = sound_effects[sfx_name]
	new_player.volume_db = volume
	
	new_player.finished.connect(new_player.queue_free)
	
	add_child(new_player)
	new_player.play()
