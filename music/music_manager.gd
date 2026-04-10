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
	Area.TITLE_SCREEN: ["res://music/menus/title.ogg"],
	Area.FOREST_DAY: [
		"res://music/forest/forest_day_2.ogg",
		#"res://music/forest/Day Overworld.ogg",
		#"res://music/forest/Surface Track.ogg",
		#"res://music/forest/Grass in The Night 1.ogg",
		#"res://music/forest/Day 5.ogg",
		"res://music/forest/Day 4.ogg",
		"res://music/forest/Forest in the Day.ogg",
	],
	Area.FOREST_NIGHT: [
		"res://music/forest/Night Track.ogg",
		"res://music/forest/Grass in The Night 1.ogg",
		"res://music/forest/Day Overworld.ogg",
	],
	Area.WINTER_DAY: [
		"res://music/winter/winter_day_1.ogg",
		"res://music/winter/winter_day_2.ogg",
	],
	Area.WINTER_NIGHT: ["res://music/winter/Ice Night 1.ogg"],
	Area.UNDERGROUND: ["res://music/Caves/Cave 2.ogg"],
	Area.CAVERN: ["res://music/Caves/Deep Cave 1.ogg"],
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
	Area.OCEAN_NIGHT: ["res://music/Ocean/Ocean Night 1.ogg"],
}

const DAY_NIGHT_PAIRS: Dictionary[Area, Area] = {
	Area.FOREST_DAY:   Area.FOREST_NIGHT,
	Area.FOREST_NIGHT: Area.FOREST_DAY,
	Area.WINTER_DAY:   Area.WINTER_NIGHT,
	Area.WINTER_NIGHT: Area.WINTER_DAY,
	Area.OCEAN_DAY:    Area.OCEAN_NIGHT,
	Area.OCEAN_NIGHT:  Area.OCEAN_DAY,
}

const DAY_AREAS: Array[Area] = [Area.FOREST_DAY, Area.WINTER_DAY, Area.OCEAN_DAY]
const QUEUED_AREAS: Array[Area] = [Area.FOREST_DAY, Area.FOREST_NIGHT, Area.SPACE, Area.OCEAN_DAY, Area.OCEAN_NIGHT]

var _track_queues: Dictionary[Area, Array] = {}
var _last_played: Dictionary[Area, String] = {}
var _current_area: Area = Area.TITLE_SCREEN
var _is_day: bool = true

# --- Functions --- #

func _ready() -> void:
	bus = "Music"
	Globals.music = self
	finished.connect(_on_track_finished)
	BiomeManager.biome_changed.connect(_on_biome_changed)
	BiomeManager.layer_changed.connect(_on_layer_changed)

	var args = Globals.parse_arguments()
	if OS.has_feature('dedicated_server') or args.get('server', false) or args.get('no-music', false):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -1000)
		return

	play_track(Area.TITLE_SCREEN)

func _process(_delta: float) -> void:
	if _current_area == Area.TITLE_SCREEN: return
	
	var is_day: bool = DaytimeManager.is_day()
	if is_day != _is_day:
		_on_time_changed(is_day)

func _on_track_finished() -> void:
	play_track(_current_area)

func _on_time_changed(is_day: bool) -> void:
	_is_day = is_day
	if _current_area in DAY_NIGHT_PAIRS or _current_area in DAY_AREAS:
		enter_area(_current_area)

func _resolve_area(area: Area) -> Area:
	if area not in DAY_NIGHT_PAIRS and area not in DAY_AREAS:
		return area
	var day_version = area if area in DAY_AREAS else DAY_NIGHT_PAIRS[area]
	return day_version if _is_day else DAY_NIGHT_PAIRS[day_version]

func play_track(area: Area, variant := -1) -> void:
	_current_area = area
	if multiplayer.is_server() and OS.has_feature("dedicated_server"): return

	var path: String
	if variant != -1:
		path = AREA_TRACKS[area][variant]
	elif area in QUEUED_AREAS:
		path = _next_queued_track(area)
	elif AREA_TRACKS[area].is_empty():
		stop()
		return
	else:
		path = AREA_TRACKS[area].pick_random()

	print("[MusicManager] Playing: ", path, " (Area: ", Area.keys()[area], ")")
	var new_stream = load(path)
	if new_stream:
		stream = new_stream
		play()

func enter_area(area: Area) -> void:
	_is_day = DaytimeManager.is_day()
	var resolved: Area = _resolve_area(area)
	
	print("[Music] System Check | Time: %s | Requested: %s | Resolved: %s | Current: %s" % [
		"Day" if _is_day else "Night", Area.keys()[area], Area.keys()[resolved], Area.keys()[_current_area]
	])

	if resolved != _current_area or not playing or _current_area == Area.TITLE_SCREEN:
		reset_area(resolved)
		play_track(resolved)

func reset_area(area: Area) -> void:
	_track_queues.erase(area)
	_last_played.erase(area)

func _next_queued_track(area: Area) -> String:
	if not _track_queues.has(area) or _track_queues[area].is_empty():
		var new_queue: Array = AREA_TRACKS[area].duplicate()
		new_queue.shuffle()
		if new_queue.size() > 1 and new_queue.front() == _last_played.get(area, ""):
			new_queue.append(new_queue.pop_front())
		_track_queues[area] = new_queue

	var track: String = _track_queues[area].pop_front()
	_last_played[area] = track
	return track

# --- Signal Handlers --- #

func _on_biome_changed(new_biome: BiomeManager.Biome) -> void:
	if BiomeManager.current_layer != BiomeManager.Layer.SURFACE:
		# Handle sub-surface layers
		match BiomeManager.current_layer:
			BiomeManager.Layer.SPACE: return
			BiomeManager.Layer.UNDERGROUND: enter_area(Area.UNDERGROUND)
			BiomeManager.Layer.CAVERN: enter_area(Area.CAVERN)
		return

	match new_biome:
		BiomeManager.Biome.SNOW: enter_area(Area.WINTER_DAY)
		BiomeManager.Biome.FOREST: enter_area(Area.FOREST_DAY)
		BiomeManager.Biome.OCEAN: enter_area(Area.OCEAN_DAY)

func _on_layer_changed(new_layer: BiomeManager.Layer) -> void:
	match new_layer:
		BiomeManager.Layer.SPACE: enter_area(Area.SPACE)
		BiomeManager.Layer.SURFACE: _on_biome_changed(BiomeManager.current_biome)
		BiomeManager.Layer.UNDERGROUND: enter_area(Area.UNDERGROUND)
		BiomeManager.Layer.CAVERN: enter_area(Area.CAVERN)