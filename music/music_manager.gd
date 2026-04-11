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

# --- Constants --- #
const AREA_TRACKS: Dictionary[Area, Array] = {
	Area.TITLE_SCREEN: [
		"res://music/menus/title.ogg",
		"res://music/menus/Menu A Theme.ogg",
	],
	Area.FOREST_DAY: [
		"res://music/forest/forest_day_2.ogg",
		"res://music/forest/Day 4.ogg",
		"res://music/forest/Forest in the Day.ogg",
	],
	Area.FOREST_NIGHT: [
		"res://music/forest/Night Track.ogg",
		"res://music/forest/Grass in The Night 1.ogg",
		"res://music/forest/Day Overworld.ogg",
		"res://music/forest/Night 2.ogg",
		"res://music/forest/Night 5.ogg",
		"res://music/forest/Another-Night.ogg",
		
	],
	Area.WINTER_DAY: [
		"res://music/winter/winter_day_1.ogg",
		"res://music/winter/winter_day_2.ogg",
	],
	Area.WINTER_NIGHT: [
		"res://music/winter/Ice Night 1.ogg",
		"res://music/forest/Night 2.ogg",
		"res://music/forest/Night 5.ogg",
		"res://music/forest/Another-Night.ogg",
		
	],
	Area.UNDERGROUND: [
		"res://music/Caves/Cave 2.ogg",
		"res://music/Caves/Ice Caves.ogg",
		"res://music/Caves/Ice Caves 2.ogg",
	],
	Area.CAVERN: [
		"res://music/Caves/Deep Cave 1.ogg",
		"res://music/Caves/Deep Cave 2.ogg",
	],
	Area.DUNGEON: [],
	Area.SPACE: [
		"res://music/Space/Space 1.ogg",
		"res://music/Space/Space 2.ogg",
		"res://music/Space/Space 3.ogg",
	],
	Area.OCEAN_DAY: [
		"res://music/Ocean/Ocean 1.ogg",
	],
	Area.OCEAN_NIGHT: [
		"res://music/Ocean/Ocean Night 1.ogg",
		"res://music/forest/Night 2.ogg",
		"res://music/forest/Night 5.ogg",
		"res://music/forest/Another-Night.ogg",
		
	],
}

# Ambient noise mappings - looping background sounds
const AREA_AMBIENCE: Dictionary[Area, String] = {
	Area.TITLE_SCREEN: "",
	Area.FOREST_DAY: "res://music/Ambience/Forest Day/Ambiance_Forest_Birds_Loop_Stereo.ogg",
	Area.FOREST_NIGHT: "res://music/Ambience/Forest Night/Ambiance_Night_Loop_Stereo.ogg",
	Area.WINTER_DAY: "res://music/Ambience/Winter/Ambiance_Wind_Calm_Loop_Stereo.ogg",
	Area.WINTER_NIGHT: "res://music/Ambience/Forest Day/forest-wind_-birds.ogg",
	Area.UNDERGROUND: "res://music/Ambience/Cave/Ambiance_Cave_Drips_Loop_Stereo.ogg",
	Area.CAVERN: "res://music/Ambience/Deep Cave/Ambiance_Cave_Dark_Loop_Stereo.ogg",
	Area.DUNGEON: "",
	Area.SPACE: "res://music/Ambience/Space/liecio-space-sound-hi-109577.ogg",
	Area.OCEAN_DAY: "res://music/Ambience/Beach/beach - very close, waves & foam.ogg",
	Area.OCEAN_NIGHT: "res://music/Ambience/Beach/prettysleepy-crickets-chirping-amp-ocean-waves-by-prettysleepy-art-10372.ogg",
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

# --- Variables --- #
var _track_queues: Dictionary[Area, Array] = {}
var _last_played: Dictionary[Area, String] = {}
var _current_area: Area = Area.TITLE_SCREEN
var _is_day: bool = true

# Ambience player node
var _ambience_player: AudioStreamPlayer
var _current_ambience_area: Area = Area.TITLE_SCREEN

# --- Signals --- #
signal area_changed(area: Area)
signal ambience_changed(area: Area)

# --- Functions --- #

func _ready() -> void:
	bus = "Music"
	Globals.music = self
	finished.connect(_on_track_finished)
	BiomeManager.biome_changed.connect(_on_biome_changed)
	BiomeManager.layer_changed.connect(_on_layer_changed)

	# Setup ambience player
	_setup_ambience_player()

	var args = Globals.parse_arguments()
	if OS.has_feature('dedicated_server') or args.get('server', false) or args.get('no-music', false):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -1000)
		_ambience_player.volume_db = -1000
		return

	play_track(Area.TITLE_SCREEN)

func _setup_ambience_player() -> void:
	"""Initialize the ambience audio player as a child node"""
	_ambience_player = AudioStreamPlayer.new()
	add_child(_ambience_player)
	_ambience_player.bus = "Ambiance"
	_ambience_player.finished.connect(_on_ambience_finished)

func _process(_delta: float) -> void:
	if _current_area == Area.TITLE_SCREEN: return
	
	var is_day: bool = DaytimeManager.is_day()
	if is_day != _is_day:
		_on_time_changed(is_day)

func _on_track_finished() -> void:
	play_track(_current_area)

func _on_ambience_finished() -> void:
	"""Replay ambience when it finishes (for non-looping audio files)"""
	if _current_ambience_area != Area.TITLE_SCREEN:
		play_ambience(_current_ambience_area)

func _on_time_changed(is_day: bool) -> void:
	_is_day = is_day
	if _current_area in DAY_NIGHT_PAIRS or _current_area in DAY_AREAS:
		enter_area(_current_area)

func _resolve_area(area: Area) -> Area:
	"""Resolve day/night areas based on current time"""
	if area not in DAY_NIGHT_PAIRS and area not in DAY_AREAS:
		return area
	var day_version = area if area in DAY_AREAS else DAY_NIGHT_PAIRS[area]
	return day_version if _is_day else DAY_NIGHT_PAIRS[day_version]

func play_track(area: Area, variant := -1) -> void:
	"""Play a music track for the given area"""
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
	
	# Play ambience when music starts
	play_ambience(area)

func play_ambience(area: Area) -> void:
	"""Play ambient noise for the given area"""
	# Resolve day/night ambience if needed
	var resolved_area: Area = _resolve_area(area)
	
	if resolved_area == _current_ambience_area and _ambience_player.playing:
		return  # Already playing the correct ambience

	_current_ambience_area = resolved_area
	
	# Check if area has ambience defined
	if resolved_area not in AREA_AMBIENCE or AREA_AMBIENCE[resolved_area].is_empty():
		_ambience_player.stop()
		return

	var ambience_path: String = AREA_AMBIENCE[resolved_area]
	print("[MusicManager] Playing Ambience: ", ambience_path, " (Area: ", Area.keys()[resolved_area], ")")
	
	var new_ambience = load(ambience_path)
	if new_ambience:
		_ambience_player.stream = new_ambience
		_ambience_player.play()
		ambience_changed.emit(resolved_area)

func enter_area(area: Area) -> void:
	"""Enter a new area, resolving day/night versions"""
	_is_day = DaytimeManager.is_day()
	var resolved: Area = _resolve_area(area)
	
	print("[Music] System Check | Time: %s | Requested: %s | Resolved: %s | Current: %s" % [
		"Day" if _is_day else "Night", Area.keys()[area], Area.keys()[resolved], Area.keys()[_current_area]
	])

	if resolved != _current_area or not playing or _current_area == Area.TITLE_SCREEN:
		reset_area(resolved)
		play_track(resolved)
		area_changed.emit(resolved)

func reset_area(area: Area) -> void:
	"""Reset track queue and last played for an area"""
	_track_queues.erase(area)
	_last_played.erase(area)

func _next_queued_track(area: Area) -> String:
	"""Get next track from shuffled queue, avoiding immediate repeats"""
	if not _track_queues.has(area) or _track_queues[area].is_empty():
		var new_queue: Array = AREA_TRACKS[area].duplicate()
		new_queue.shuffle()
		if new_queue.size() > 1 and new_queue.front() == _last_played.get(area, ""):
			new_queue.append(new_queue.pop_front())
		_track_queues[area] = new_queue

	var track: String = _track_queues[area].pop_front()
	_last_played[area] = track
	return track

# --- Volume Control --- #

func set_music_volume(db: float) -> void:
	"""Set music volume in decibels"""
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db)

func set_ambience_volume(db: float) -> void:
	"""Set ambience volume in decibels"""
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambiance"), db)

func get_music_volume() -> float:
	"""Get current music volume in decibels"""
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))

func get_ambience_volume() -> float:
	"""Get current ambience volume in decibels"""
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambiance"))

# --- Signal Handlers --- #

func _on_biome_changed(new_biome: BiomeManager.Biome) -> void:
	"""Handle biome changes"""
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
	"""Handle layer changes"""
	match new_layer:
		BiomeManager.Layer.SPACE: enter_area(Area.SPACE)
		BiomeManager.Layer.SURFACE: _on_biome_changed(BiomeManager.current_biome)
		BiomeManager.Layer.UNDERGROUND: enter_area(Area.UNDERGROUND)
		BiomeManager.Layer.CAVERN: enter_area(Area.CAVERN)
