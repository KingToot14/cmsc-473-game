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
		"res://music/menus/title.ogg",
	],
	Area.FOREST_DAY: [
		"res://music/forest/forest_day_2.ogg",
		"res://music/forest/Day Overworld.ogg",
		#"res://music/forest/Surface Track.ogg",
	],
	Area.FOREST_NIGHT: [
		"res://music/forest/Night Track.ogg",
		"res://music/forest/Grass in The Night 1.ogg",
	],
	Area.WINTER_DAY: [
		"res://music/winter/winter_day_1.ogg",
		"res://music/winter/winter_day_2.ogg",
	],
	Area.WINTER_NIGHT: [],
	Area.UNDERGROUND: [],
	Area.CAVERN: [],
	Area.DUNGEON: [],
}

# Areas that use a shuffled queue instead of random selection
const QUEUED_AREAS: Array[Area] = [
	Area.FOREST_DAY,
	Area.FOREST_NIGHT,
]

# The track to always play first when entering a queued area.
const AREA_INTRO_TRACKS: Dictionary[Area, String] = {
	Area.FOREST_DAY: "res://music/forest/forest_day_2.ogg",
}

var _track_queues: Dictionary[Area, Array] = {}
var _intro_played: Dictionary[Area, bool] = {}
var _last_played: Dictionary[Area, String] = {}
var _current_area: Area = Area.TITLE_SCREEN

# --- Functions --- #
func _ready() -> void:
	Globals.music = self
	finished.connect(_on_track_finished)

	# start playback
	var args := Globals.parse_arguments()

	# only play on clients that haven't disabled music
	if OS.has_feature('dedicated_server') or args.get('server', false) or args.get('no-music', false):
		return
	play_track(Area.TITLE_SCREEN)


func _on_track_finished() -> void:
	play_track(_current_area)


## Returns the next track path for a queued area, refilling and reshuffling
## the queue once all tracks have been played.
func _next_queued_track(area: Area) -> String:
	# Play the intro track once if one is defined and hasn't been played yet
	if AREA_INTRO_TRACKS.has(area) and not _intro_played.get(area, false):
		_intro_played[area] = true
		_last_played[area] = AREA_INTRO_TRACKS[area]
		return AREA_INTRO_TRACKS[area]

	if not _track_queues.has(area) or _track_queues[area].is_empty():
		var new_queue: Array = AREA_TRACKS[area].duplicate()
		new_queue.shuffle()
		# if the first track in the new queue matches the last played, move it to the end
		if new_queue.size() > 1 and new_queue.front() == _last_played.get(area, ""):
			new_queue.append(new_queue.pop_front())
		_track_queues[area] = new_queue

	var track: String = _track_queues[area].pop_front()
	_last_played[area] = track
	return track


## Plays a music track for the given [param area].
func play_track(area: Area, variant := -1) -> void:
	print("play_track called, area: ", area, " is_server: ", multiplayer.is_server())

	_current_area = area

	var path: String
	if variant != -1:
		path = AREA_TRACKS[area][variant]
	elif area in QUEUED_AREAS:
		path = _next_queued_track(area)
	elif AREA_TRACKS[area].is_empty():
		return
	else:
		path = AREA_TRACKS[area][randi_range(0, len(AREA_TRACKS[area]) - 1)]

	print("Loading path: ", path)
	var new_stream: AudioStreamOggVorbis = load(path)
	new_stream.loop = AREA_TRACKS[area].size() == 1

	stream = new_stream
	play()
	print("Is playing: ", playing)


## Resets the queue and intro state for [param area], so the intro plays
## again next time the player enters it.
func reset_area(area: Area) -> void:
	_intro_played.erase(area)
	_track_queues.erase(area)
	_last_played.erase(area)
