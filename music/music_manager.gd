class_name MusicManager
extends AudioStreamPlayer

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
		1, # res://music/forest/forest_day_2.ogg
		5, # res://music/forest/Day Overworld.ogg
	],
	Area.FOREST_NIGHT: [
		0,
	],
	Area.WINTER_DAY: [
		2, # res://music/winter/winter_day_1.ogg,
		3, # res://music/winter/winter_day_2.ogg
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

# Areas that use a shuffled queue instead of random selection
const QUEUED_AREAS: Array[Area] = [
	Area.FOREST_DAY,
	Area.FOREST_NIGHT,
]

# The clip to always play first when entering a queued area.
# If an area has no entry here, the queue starts immediately.
const AREA_INTRO_TRACKS: Dictionary[Area, int] = {
	Area.FOREST_DAY: 1, # res://music/forest/forest_day_1.ogg
}

var _track_queues: Dictionary[Area, Array] = {}
var _intro_played: Dictionary[Area, bool] = {}
var _current_area: Area = Area.TITLE_SCREEN
var _last_clip: int = -1

# --- Functions --- #
func _ready() -> void:
	Globals.music = self
	finished.connect(_on_track_finished)
	
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


func _process(_delta: float) -> void:
	if not is_instance_valid(get_stream_playback()):
		return
	
	var current_clip: int = get_stream_playback().get_current_clip_index()
	
	# detect when a track has finished and moved on
	if current_clip != _last_clip:
		_last_clip = current_clip
	elif not playing:
		play_track(_current_area)


func _on_track_finished() -> void:
	play_track(_current_area)


## Returns the next track index for a queued area, refilling and reshuffling
## the queue once all tracks have been played.
func _next_queued_track(area: Area) -> int:
	# Play the intro track once if one is defined and hasn't been played yet
	if AREA_INTRO_TRACKS.has(area) and not _intro_played.get(area, false):
		_intro_played[area] = true
		return AREA_INTRO_TRACKS[area]

	if not _track_queues.has(area) or _track_queues[area].is_empty():
		var new_queue: Array = AREA_TRACKS[area].duplicate()
		# Remove the intro track from the queue so it doesn't repeat
		if AREA_INTRO_TRACKS.has(area):
			new_queue.erase(AREA_INTRO_TRACKS[area])
		new_queue.shuffle()
		_track_queues[area] = new_queue

	return _track_queues[area].pop_front()


## Plays a music track that plays in the given [param area]. Defaults to a random
## selection from the available options, but can be specified using [param variant].
## Queued areas (e.g. forest) cycle through all tracks before repeating.
func play_track(area: Area, variant := -1) -> void:
	if multiplayer.is_server() or not is_instance_valid(get_stream_playback()):
		return

	_current_area = area

	var clip: int
	if variant != -1:
		clip = AREA_TRACKS[area][variant]
	elif area in QUEUED_AREAS:
		clip = _next_queued_track(area)
	else:
		clip = AREA_TRACKS[area][randi_range(0, len(AREA_TRACKS[area]) - 1)]

	# fade to new track
	get_stream_playback().switch_to_clip(clip)


## Resets the queue and intro state for [param area], so the intro plays
## again next time the player enters it.
func reset_area(area: Area) -> void:
	_intro_played.erase(area)
	_track_queues.erase(area)
