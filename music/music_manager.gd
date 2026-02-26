class_name MusicManager
extends AudioStreamPlayer

# --- Enums --- #
enum Area {
	TITLE_SCREEN,
	FOREST_DAY,
	FOREST_NIGHT,
	WINTER_DAY,
	WINTER_NIGHT,
	UNDERGROUND,
	CAVERN,
	DUNGEON
}

# --- Variables --- #
const AREA_TRACKS: Dictionary[Area, Array] = {
	Area.TITLE_SCREEN: [
		0, # res://music/menus/title.ogg
	],
	Area.FOREST_DAY: [
		1, # res://music/forest/forest_day_1.ogg,
		2, # res://music/forest/forest_day_2.ogg
	],
	Area.FOREST_NIGHT: [
		0,
	],
	Area.WINTER_DAY: [
		3, # res://music/winter/winter_day_1.ogg,
		4, # res://music/winter/winter_day_2.ogg
	],
	Area.WINTER_NIGHT: [
		0,
	],
	Area.UNDERGROUND: [
		0,
	],
	Area.CAVERN: [
		0,
	],
	Area.DUNGEON: [
		0,
	],
}

# --- Functions --- #
func _ready() -> void:
	Globals.music = self
	
	# setup cross-fade transition
	stream.add_transition(
		AudioStreamInteractive.CLIP_ANY, AudioStreamInteractive.CLIP_ANY,
		AudioStreamInteractive.TransitionFromTime.TRANSITION_FROM_TIME_IMMEDIATE,
		AudioStreamInteractive.TransitionToTime.TRANSITION_TO_TIME_START,
		AudioStreamInteractive.FadeMode.FADE_CROSS, 4
	)
	
	# start playback
	var args := Globals.parse_arguments()
	
	# only play on clients that haven't disabled music
	if OS.has_feature('dedicated_server') or args.get('server', false) or args.get('no-music', false):
		return

	play()

## Plays a music track that plays in the given [param area]. Defaults to a random
## selection from the available options, but can be specified using [param variant]
func play_track(area: Area, variant := -1) -> void:
	if multiplayer.is_server() or not is_instance_valid(get_stream_playback() ):
		return
	
	if variant == -1:
		variant = randi_range(0, len(AREA_TRACKS[area]))
	
	# fade to new track
	get_stream_playback().switch_to_clip(AREA_TRACKS[area][variant])
