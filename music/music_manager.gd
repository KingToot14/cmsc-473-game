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
	DUNGEON,
	SPACE,
	OCEAN_DAY,
	OCEAN_NIGHT,
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
		#"res://music/forest/Grass in The Night 1.ogg",
		#"res://music/forest/Day 5.ogg",
		"res://music/forest/Day 4.ogg",
		"res://music/forest/Forest in the Day.ogg",
	],
	Area.FOREST_NIGHT: [
		"res://music/forest/Night Track.ogg",
		"res://music/forest/Grass in The Night 1.ogg",
	],
	Area.WINTER_DAY: [
		"res://music/winter/winter_day_1.ogg",
		"res://music/winter/winter_day_2.ogg",
	],
	Area.WINTER_NIGHT: [
		"res://music/winter/Ice Night 1.ogg"
	],
	Area.UNDERGROUND: [
		"res://music/Caves/Cave 2.ogg",
	],
	Area.CAVERN: [
		"res://music/Caves/Deep Cave 1.ogg",
	],
	Area.DUNGEON: [],
	Area.SPACE: [
		"res://music/Space/Space 1.ogg",
		"res://music/Space/Space 2.ogg",
		"res://music/Space/Space 3.ogg",
	],
	Area.OCEAN_DAY: [
		#"res://music/ocean/ocean_day_1.ogg",
		#"res://music/ocean/ocean_day_2.ogg",
		#"res://music/ocean/ocean_day_3.ogg",
		"res://music/Ocean/Ocean 1.ogg",
	],
	Area.OCEAN_NIGHT: [
		"res://music/Ocean/Ocean Night 1.ogg"
	],
}

# Maps each day area to its night equivalent and vice versa.
const DAY_NIGHT_PAIRS: Dictionary[Area, Area] = {
	Area.FOREST_DAY:   Area.FOREST_NIGHT,
	Area.FOREST_NIGHT: Area.FOREST_DAY,
	Area.WINTER_DAY:   Area.WINTER_NIGHT,
	Area.WINTER_NIGHT: Area.WINTER_DAY,
	Area.OCEAN_DAY:    Area.OCEAN_NIGHT,
	Area.OCEAN_NIGHT:  Area.OCEAN_DAY,
}

# Areas that use a shuffled queue instead of random selection
const QUEUED_AREAS: Array[Area] = [
	Area.FOREST_DAY,
	Area.FOREST_NIGHT,
	Area.SPACE,
	Area.OCEAN_DAY,
	Area.OCEAN_NIGHT,
]

# No fixed intro tracks — all areas start on a random track.
const AREA_INTRO_TRACKS: Dictionary[Area, String] = {}

var _track_queues: Dictionary[Area, Array] = {}
var _intro_played: Dictionary[Area, bool] = {}
var _last_played: Dictionary[Area, String] = {}
var _current_area: Area = Area.TITLE_SCREEN
var _is_day: bool = true

# --- Functions --- #
func _ready() -> void:
	Globals.music = self
	finished.connect(_on_track_finished)

	BiomeManager.biome_changed.connect(_on_biome_changed)
	BiomeManager.layer_changed.connect(_on_layer_changed)

	# start playback
	var args = Globals.parse_arguments()

	# only play on clients that haven't disabled music
	if OS.has_feature('dedicated_server') or args.get('server', false) or args.get('no-music', false):
		AudioServer.set_bus_volume_db(0, -1000)
		return

	# Don't read DaytimeManager here — world isn't loaded yet.
	# _process will sync _is_day once the world is running.
	play_track(Area.TITLE_SCREEN)


func _process(_delta: float) -> void:
	# Poll DaytimeManager each frame and trigger a music switch if day/night has flipped.
	var is_day: bool = DaytimeManager.is_day()
	if is_day != _is_day:
		_on_time_changed(is_day)


func _on_track_finished() -> void:
	play_track(_current_area)


## Called when the time of day crosses the day/night boundary.
func _on_time_changed(is_day: bool) -> void:
	_is_day = is_day

	# Only switch if we're in a surface biome with a day/night pair
	if _current_area not in DAY_NIGHT_PAIRS:
		return

	var target_area: Area = DAY_NIGHT_PAIRS[_current_area]
	# If the target area has no tracks, stay on the current one
	if not AREA_TRACKS[target_area].is_empty():
		enter_area(target_area)


## Returns the next track path for a queued area, refilling and reshuffling
## the queue once all tracks have been played.
func _next_queued_track(area: Area) -> String:
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


## Plays a music track for a given [param area].
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
	if new_stream == null:
		push_error("MusicManager: failed to load track: " + path)
		return

	new_stream.loop = AREA_TRACKS[area].size() == 1

	stream = new_stream
	play()
	print("Is playing: ", playing)


func _on_biome_changed(new_biome: BiomeManager.Biome) -> void:
	# layer overrides biome music for non-surface layers
	match BiomeManager.current_layer:
		BiomeManager.Layer.SPACE:
			return
		BiomeManager.Layer.UNDERGROUND:
			enter_area(Area.UNDERGROUND)
			return
		BiomeManager.Layer.CAVERN:
			enter_area(Area.CAVERN)
			return

	# surface biome music — respect current time of day
	match new_biome:
		BiomeManager.Biome.SNOW:
			enter_area(Area.WINTER_DAY if _is_day else Area.WINTER_NIGHT)
		BiomeManager.Biome.FOREST:
			enter_area(Area.FOREST_DAY if _is_day else Area.FOREST_NIGHT)
		BiomeManager.Biome.OCEAN:
			enter_area(Area.OCEAN_DAY if _is_day else Area.OCEAN_NIGHT)


func _on_layer_changed(new_layer: BiomeManager.Layer) -> void:
	match new_layer:
		BiomeManager.Layer.SPACE:
			enter_area(Area.SPACE)
		BiomeManager.Layer.SURFACE:
			_on_biome_changed(BiomeManager.current_biome)
		BiomeManager.Layer.UNDERGROUND:
			enter_area(Area.UNDERGROUND)
		BiomeManager.Layer.CAVERN:
			enter_area(Area.CAVERN)


## Switches to a new area, resetting the queue so a fresh random track plays.
func enter_area(area: Area) -> void:
	if area == _current_area:
		return
	reset_area(area)
	play_track(area)


## Resets the queue and intro state for [param area], so a fresh random track
## plays next time the player enters it.
func reset_area(area: Area) -> void:
	_intro_played.erase(area)
	_track_queues.erase(area)
	_last_played.erase(area)
