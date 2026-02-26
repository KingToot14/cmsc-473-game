class_name PlayerSfxManager
extends AudioStreamPlayer2D

# --- Enums --- #
enum SFX {
	JUMP,
	LAND
}

# --- Variables --- #
@export var jump_sound: AudioStream
@export var land_sound: AudioStream

# --- Functions --- #
## Plays a standard player sound effect specified by [param sfx]
func play_sfx(sfx: SFX) -> void:
	if multiplayer.is_server():
		return
	
	match sfx:
		SFX.JUMP:
			get_stream_playback().play_stream(jump_sound)
		SFX.LAND:
			get_stream_playback().play_stream(land_sound)
