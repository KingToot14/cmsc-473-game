class_name MusicManager
extends AudioStreamPlayer

enum Area {
	TITLE_SCREEN,
	FOREST_DAY,
	FOREST_NIGHT,
	WINTER_DAY,
	WINTER_NIGHT,
	DESERT_DAY,
	DESERT_NIGHT,
	UNDERGROUND,
	CAVERN,
	DUNGEON,
	SPACE,
	OCEAN_DAY,
	OCEAN_NIGHT,
	UNDERWORLD,
	JUNGLE_DAY,   # Added Jungle Day
	JUNGLE_NIGHT, # Added Jungle Night
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
	# Jungle Day Placeholder (using Forest Day tracks)
	Area.JUNGLE_DAY: [
		"res://music/forest/forest_day_2.ogg",
		"res://music/forest/Day 4.ogg",
		"res://music/forest/Forest in the Day.ogg",
	],
	# Jungle Night Placeholder (using Forest Night tracks)
	Area.JUNGLE_NIGHT: [
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
	Area.DUNGEON: [
		"res://music/Dungeon/He’ll.ogg"
		
	],
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
	Area.DESERT_DAY: [
		#"res://music/Desert/Possible Desert.ogg",
		"res://music/forest/Day Overworld.ogg",
		"res://music/Desert/Possible Desert 2.ogg",
	],
	Area.DESERT_NIGHT: [
		"res://music/Desert/Possible night.ogg",
		#"res://music/forest/Night 2.ogg",
		#"res://music/forest/Night 5.ogg",
		#"res://music/forest/Another-Night.ogg",
	],
	Area.UNDERWORLD:[
		"res://music/Underworld/He’ll 2.ogg"
	],
}

# Updated to use Arrays for multiple ambient tracks per area
const AREA_AMBIENCE: Dictionary[Area, Array] = {
	Area.TITLE_SCREEN: [],
	Area.FOREST_DAY: [
		"res://music/Ambience/Forest Day/Ambiance_Forest_Birds_Loop_Stereo.ogg",
		"res://music/Ambience/Forest Day/Ambiance_Nature_Meadow_Birds_Flies_Calm_Loop_Stereo.wav",
		"res://music/Ambience/Forest Day/forest-wind_-birds.ogg",
	],
	Area.FOREST_NIGHT: [
		"res://music/Ambience/Forest Night/Ambiance_Night_Loop_Stereo.ogg",
	],
	# Jungle Ambience Placeholder
	Area.JUNGLE_DAY: [
		"res://music/Ambience/Forest Day/Ambiance_Forest_Birds_Loop_Stereo.ogg",
		"res://music/Ambience/Forest Day/Ambiance_Nature_Meadow_Birds_Flies_Calm_Loop_Stereo.wav",
		"res://music/Ambience/Forest Day/forest-wind_-birds.ogg",
	],
	Area.JUNGLE_NIGHT: [
		"res://music/Ambience/Forest Night/Ambiance_Night_Loop_Stereo.ogg",
	],
	Area.WINTER_DAY: [
		"res://music/Ambience/Winter/Ambiance_Wind_Calm_Loop_Stereo.ogg",
	],
	Area.WINTER_NIGHT: [
		"res://music/Ambience/Forest Day/forest-wind_-birds.ogg",
	],
	Area.UNDERGROUND: [
		"res://music/Ambience/Cave/Ambiance_Cave_Drips_Loop_Stereo.ogg",
	],
	Area.CAVERN: [
		"res://music/Ambience/Deep Cave/Ambiance_Cave_Dark_Loop_Stereo.ogg",
	],
	Area.DUNGEON: [],
	Area.SPACE: [
		"res://music/Ambience/Space/liecio-space-sound-hi-109577.ogg",
	],
	Area.OCEAN_DAY: [
		"res://music/Ambience/Beach/beach - very close, waves & foam.ogg",
	],
	Area.OCEAN_NIGHT: [
		"res://music/Ambience/Beach/prettysleepy-crickets-chirping-amp-ocean-waves-by-prettysleepy-art-10372.ogg",
	],
	Area.DESERT_DAY:[
		"res://music/Desert/tanweraman-desert-wind-2-350417.wav",
		"res://music/Desert/tanweraman-desert-wind-1-350398.wav",
		
	],
	Area.DESERT_NIGHT:[
		"res://music/Ambience/Forest Night/Ambiance_Night_Loop_Stereo.ogg",
		"res://music/Desert/freesound_community-semi-desert-insects-ravens-birds-quiet-with-bad-mic-noise-badlands-ab-190818-7028.wav",
	],
	Area.UNDERWORLD:[
		"res://music/Underworld/alex_jauk-nightmarish-hell-223594.wav",
		"res://music/Underworld/freesound_community-ambinet-hell-23836.wav",
		"res://music/Underworld/freesound_community-metallic-ambiance-53909.wav",
		"res://music/Underworld/Ambiance_Fire_Big_Loop_Mono.wav",
	],
}

const WATER_ENTRY_SOUNDS: Array[String] = ["res://music/Water Sounds/splash big 5.wav"]
const WATER_EXIT_SOUNDS: Array[String] = ["res://music/Water Sounds/IMG_9708.wav"]
const TREE_DAMAGE_SOUNDS: Array[String] = ["res://music/Tree sfx/wood hit 16.wav", "res://music/Tree sfx/wood hit 26.wav"]
const TREE_BREAK_SOUNDS: Array[String] = ["res://music/Tree sfx/mollyroselee-falling-tree-ai-generated-431321.wav"]
const ITEM_PICKUP_SOUNDS: Array[String] = ["res://music/Inventory Sounds/Poping Sound.wav"]
const ARMOR_EQUIP_SOUNDS: Array[String] = ["res://music/Inventory Sounds/freesound_community-item-equip-6904.wav"]
const WATER_AMBIENCE_SOUNDS: Array[String] = [
	"res://music/Liquid Ambience/Ambiance_River_Moderate_Loop_Stereo.wav",
	"res://music/Liquid Ambience/Ambiance_Stream_Calm_Loop_Stereo.wav",
]
const LAVA_AMBIENCE_SOUNDS: Array[String] = [
	"res://music/Liquid Ambience/freesound_community-lava-loop-1-67307.wav",
	"res://music/Liquid Ambience/freesound_community-lava-loop-2-67306.wav",
]
const TORCH_PLACE_SOUNDS: Array[String] = ["res://music/Torch sfx/floraphonic-fire-torch-whoosh-3-190299.wav"]
const TORCH_BREAK_SOUNDS: Array[String] = ["res://music/Tree sfx/wood hit 16.wav"]

const CHEST_PLACE_SOUNDS: Array[String] = ["res://music/Chest Sounds/wood chest place.wav"]
const CHEST_BREAK_SOUNDS: Array[String] = ["res://music/Chest Sounds/wooed chest break.wav"]
const CHEST_OPEN_SOUNDS: Array[String] = ["res://music/Chest Sounds/Chest Open.wav"]
const CHEST_CLOSE_SOUNDS: Array[String] = ["res://music/Chest Sounds/Chest Close.wav"]

const DOOR_OPEN_SOUNDS: Array[String] = ["res://music/Door Sounds/Household_Door_Wood_Open_Stereo.wav"]
const DOOR_CLOSE_SOUNDS: Array[String] = ["res://music/Door Sounds/bathroom door close 2.wav"]

const DAY_NIGHT_PAIRS: Dictionary[Area, Area] = {
	Area.FOREST_DAY: Area.FOREST_NIGHT,
	Area.FOREST_NIGHT: Area.FOREST_DAY,
	Area.WINTER_DAY: Area.WINTER_NIGHT,
	Area.WINTER_NIGHT: Area.WINTER_DAY,
	Area.OCEAN_DAY: Area.OCEAN_NIGHT,
	Area.OCEAN_NIGHT: Area.OCEAN_DAY,
	Area.DESERT_DAY: Area.DESERT_NIGHT,
	Area.DESERT_NIGHT: Area.DESERT_DAY,
	Area.JUNGLE_DAY: Area.JUNGLE_NIGHT, # Added Pair
	Area.JUNGLE_NIGHT: Area.JUNGLE_DAY, # Added Pair
}

const DAY_AREAS: Array[Area] = [Area.FOREST_DAY, Area.WINTER_DAY, Area.OCEAN_DAY, Area.DESERT_DAY, Area.JUNGLE_DAY]
const QUEUED_AREAS: Array[Area] = [Area.FOREST_DAY, Area.FOREST_NIGHT, Area.SPACE, Area.OCEAN_DAY, Area.OCEAN_NIGHT, Area.DESERT_DAY, Area.DESERT_NIGHT, Area.JUNGLE_DAY, Area.JUNGLE_NIGHT]

# --- Variables --- #
var _track_queues: Dictionary[Area, Array] = {}
var _ambience_queues: Dictionary[Area, Array] = {}
var _last_played: Dictionary[Area, String] = {}
var _last_ambience_played: Dictionary[Area, String] = {}

var _current_area: Area = Area.TITLE_SCREEN
var _is_day: bool = true

var _ambience_player: AudioStreamPlayer
var _current_ambience_area: Area = Area.TITLE_SCREEN

var _water_sfx_player: AudioStreamPlayer
var _tiles_sfx_player: AudioStreamPlayer
var _inventory_sfx_player: AudioStreamPlayer
var _armor_sfx_player: AudioStreamPlayer
var _torch_sfx_player: AudioStreamPlayer
var _chest_sfx_player: AudioStreamPlayer
var _door_sfx_player: AudioStreamPlayer
var _water_ambience_player: AudioStreamPlayer
var _water_ambience_playing := false

# --- Signals --- #
signal area_changed(area: Area)
signal ambience_changed(area: Area)
signal water_entered
signal water_exited

# --- Functions --- #

func _ready() -> void:
	bus = "Music"
	Globals.music = self
	finished.connect(_on_track_finished)
	BiomeManager.biome_changed.connect(_on_biome_changed)
	BiomeManager.layer_changed.connect(_on_layer_changed)

	_setup_players()

	var args = Globals.parse_arguments()
	if OS.has_feature('dedicated_server') or args.get('server', false) or args.get('no-music', false):
		_mute_audio_server()
		return

	play_track(Area.TITLE_SCREEN)

func _setup_players() -> void:
	_ambience_player = AudioStreamPlayer.new()
	add_child(_ambience_player)
	_ambience_player.bus = "Ambiance"
	_ambience_player.finished.connect(_on_ambience_finished)

	_water_sfx_player = AudioStreamPlayer.new()
	add_child(_water_sfx_player)
	_water_sfx_player.bus = "Water Effects"

	_water_ambience_player = AudioStreamPlayer.new()
	add_child(_water_ambience_player)
	_water_ambience_player.bus = "Liquid Ambiance"
	_water_ambience_player.finished.connect(_on_water_ambience_finished)

	_tiles_sfx_player = AudioStreamPlayer.new()
	add_child(_tiles_sfx_player)
	_tiles_sfx_player.bus = "Tiles"

	_inventory_sfx_player = AudioStreamPlayer.new()
	add_child(_inventory_sfx_player)
	_inventory_sfx_player.bus = "Inventory"
	
	_armor_sfx_player = AudioStreamPlayer.new()
	add_child(_armor_sfx_player)
	_armor_sfx_player.bus = "Armor"

	_torch_sfx_player = AudioStreamPlayer.new()
	add_child(_torch_sfx_player)
	_torch_sfx_player.bus = "Torch"

	_chest_sfx_player = AudioStreamPlayer.new()
	add_child(_chest_sfx_player)
	_chest_sfx_player.bus = "Chest"

	_door_sfx_player = AudioStreamPlayer.new()
	add_child(_door_sfx_player)
	_door_sfx_player.bus = "Door"

func _mute_audio_server() -> void:
	var buses: Array[String] = ["Music", "Ambiance", "Water Effects", "Tiles", "Inventory", "Armor", "Liquid Ambiance", "Torch", "Chest", "Door"]
	for b in buses:
		var idx = AudioServer.get_bus_index(b)
		if idx != -1:
			AudioServer.set_bus_mute(idx, true)

func _process(_delta: float) -> void:
	if _current_area == Area.TITLE_SCREEN: return
	
	if BiomeManager.current_layer == BiomeManager.Layer.SURFACE:
		var is_day: bool = DaytimeManager.is_day()
		if is_day != _is_day:
			_on_time_changed(is_day)

func _on_track_finished() -> void:
	play_track(_current_area)

func _on_ambience_finished() -> void:
	if _current_ambience_area != Area.TITLE_SCREEN:
		play_ambience(_current_ambience_area)

func _on_water_ambience_finished() -> void:
	if _water_ambience_playing:
		_water_ambience_player.play()

func _on_time_changed(is_day: bool) -> void:
	_is_day = is_day
	if _current_area in DAY_NIGHT_PAIRS or _current_area in DAY_AREAS:
		enter_area(_current_area)

func _resolve_area(area: Area) -> Area:
	if area not in DAY_NIGHT_PAIRS and area not in DAY_AREAS:
		return area
	var day_version = area if area in DAY_AREAS else DAY_NIGHT_PAIRS[area]
	return day_version if _is_day else DAY_NIGHT_PAIRS[day_version]

func _load_audio_stream(path: String) -> AudioStream:
	if path == "": return null
	var audio_stream = load(path)
	if not audio_stream:
		print("[MusicManager] Failed to load: ", path)
	return audio_stream

func play_track(area: Area, variant := -1) -> void:
	_current_area = area
	if multiplayer.is_server() and OS.has_feature("dedicated_server"): return

	var path: String = ""
	if variant != -1:
		path = AREA_TRACKS[area][variant]
	elif area in QUEUED_AREAS:
		path = _next_queued_track(area)
	elif not AREA_TRACKS[area].is_empty():
		path = AREA_TRACKS[area].pick_random()

	if path != "":
		# --- Added Print --- #
		print("[MusicManager] Now playing track: ", path.get_file())
		var new_stream = _load_audio_stream(path)
		if new_stream:
			stream = new_stream
			play()
	else:
		stop()
	
	play_ambience(area)

func play_ambience(area: Area) -> void:
	var resolved_area: Area = _resolve_area(area)
	
	if resolved_area == _current_ambience_area and _ambience_player.playing:
		return

	_current_ambience_area = resolved_area
	var ambience_list: Array = AREA_AMBIENCE.get(resolved_area, [])
	
	if ambience_list.is_empty():
		_ambience_player.stop()
		return

	var ambience_path: String = _next_queued_ambience(resolved_area)
	
	var ambience_stream = _load_audio_stream(ambience_path)
	if ambience_stream:
		_ambience_player.stream = ambience_stream
		_ambience_player.play()
		ambience_changed.emit(resolved_area)

func enter_area(area: Area) -> void:
	_is_day = DaytimeManager.is_day()
	var resolved: Area = _resolve_area(area)
	
	if resolved != _current_area or not playing or _current_area == Area.TITLE_SCREEN:
		# --- Added Print --- #
		print("[MusicManager] Entering New Area: ", Area.keys()[resolved])
		reset_area(resolved)
		play_track(resolved)
		area_changed.emit(resolved)

func reset_area(area: Area) -> void:
	_track_queues.erase(area)
	_ambience_queues.erase(area) 
	_last_played.erase(area)
	_last_ambience_played.erase(area)

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

func _next_queued_ambience(area: Area) -> String:
	var ambience_list = AREA_AMBIENCE.get(area, [])
	if ambience_list.is_empty(): return ""
	
	if not _ambience_queues.has(area) or _ambience_queues[area].is_empty():
		var new_queue: Array = ambience_list.duplicate()
		new_queue.shuffle()
		if new_queue.size() > 1 and new_queue.front() == _last_ambience_played.get(area, ""):
			new_queue.append(new_queue.pop_front())
		_ambience_queues[area] = new_queue

	var track: String = _ambience_queues[area].pop_front()
	_last_ambience_played[area] = track
	return track

# --- Sound Effects --- #

func play_torch_place_sound() -> void:
	if not _is_audio_safe(): return
	_play_torch_sfx(TORCH_PLACE_SOUNDS.pick_random())

func play_torch_break_sound() -> void:
	if not _is_audio_safe(): return
	_play_torch_sfx(TORCH_BREAK_SOUNDS.pick_random())

func play_chest_place_sound() -> void:
	if not _is_audio_safe(): return
	_play_chest_sfx(CHEST_PLACE_SOUNDS.pick_random())

func play_chest_break_sound() -> void:
	if not _is_audio_safe(): return
	_play_chest_sfx(CHEST_BREAK_SOUNDS.pick_random())

func play_chest_open_sound() -> void:
	if not _is_audio_safe(): return
	_play_chest_sfx(CHEST_OPEN_SOUNDS.pick_random())

func play_chest_close_sound() -> void:
	if not _is_audio_safe(): return
	_play_chest_sfx(CHEST_CLOSE_SOUNDS.pick_random())

func play_door_open_sound() -> void:
	if not _is_audio_safe(): return
	_play_door_sfx(DOOR_OPEN_SOUNDS.pick_random())

func play_door_close_sound() -> void:
	if not _is_audio_safe(): return
	_play_door_sfx(DOOR_CLOSE_SOUNDS.pick_random())

func _is_audio_safe() -> bool:
	return Engine.get_frames_drawn() > 30

func play_water_entry_sound() -> void:
	if not _is_audio_safe(): return
	_play_sfx(_water_sfx_player, WATER_ENTRY_SOUNDS.pick_random())
	water_entered.emit()

func play_water_exit_sound() -> void:
	if not _is_audio_safe(): return
	_play_sfx(_water_sfx_player, WATER_EXIT_SOUNDS.pick_random())
	water_exited.emit()

func play_tree_damage_sound() -> void:
	if not _is_audio_safe(): return
	_play_sfx(_tiles_sfx_player, TREE_DAMAGE_SOUNDS.pick_random())

func play_tree_break_sound() -> void:
	if not _is_audio_safe(): return
	_play_sfx(_tiles_sfx_player, TREE_BREAK_SOUNDS.pick_random())

func play_item_pickup_sound() -> void:
	if not _is_audio_safe(): return
	if _inventory_sfx_player.playing and _inventory_sfx_player.get_playback_position() < 0.05: return
	_play_sfx(_inventory_sfx_player, ITEM_PICKUP_SOUNDS.pick_random())

func play_armor_equip_sound() -> void:
	if not _is_audio_safe(): return
	if _armor_sfx_player:
		_play_sfx(_armor_sfx_player, ARMOR_EQUIP_SOUNDS.pick_random())

func start_water_ambience() -> void:
	if _water_ambience_playing: return
	_water_ambience_playing = true
	if _water_ambience_player:
		var sound_path = WATER_AMBIENCE_SOUNDS.pick_random()
		_water_ambience_player.stream = _load_audio_stream(sound_path)
		_water_ambience_player.play()

func start_lava_ambience() -> void:
	if _water_ambience_playing: return
	_water_ambience_playing = true
	if _water_ambience_player:
		var sound_path = LAVA_AMBIENCE_SOUNDS.pick_random()
		_water_ambience_player.stream = _load_audio_stream(sound_path)
		_water_ambience_player.play()

func stop_water_ambience() -> void:
	if not _water_ambience_playing: return
	_water_ambience_playing = false
	if _water_ambience_player:
		_water_ambience_player.stop()

func set_liquid_ambience_volume(db: float) -> void:
	if _water_ambience_player:
		_water_ambience_player.volume_db = db

func _play_sfx(player: AudioStreamPlayer, path: String) -> void:
	var sfx_stream = load(path)
	if sfx_stream:
		player.stream = sfx_stream
		player.play()

func _play_torch_sfx(path: String) -> void:
	var sfx_stream = load(path)
	if sfx_stream:
		_torch_sfx_player.stream = sfx_stream
		_torch_sfx_player.play()

func _play_chest_sfx(path: String) -> void:
	var sfx_stream = load(path)
	if sfx_stream:
		_chest_sfx_player.stream = sfx_stream
		_chest_sfx_player.play()

func _play_door_sfx(path: String) -> void:
	var sfx_stream = load(path)
	if sfx_stream:
		_door_sfx_player.stream = sfx_stream
		_door_sfx_player.play()

# --- Volume Control --- #

func set_bus_vol(bus_name: String, db: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, db)

# --- Signal Handlers --- #

func _on_biome_changed(new_biome: BiomeManager.Biome) -> void:
	if BiomeManager.current_layer != BiomeManager.Layer.SURFACE:
		return

	var biome_name = BiomeManager.Biome.keys()[BiomeManager.Biome.values().find(new_biome)]
	print("[MusicManager] Biome Signal Received: ", biome_name)

	match new_biome:
		BiomeManager.Biome.SNOW: enter_area(Area.WINTER_DAY)
		BiomeManager.Biome.FOREST: enter_area(Area.FOREST_DAY)
		BiomeManager.Biome.OCEAN: enter_area(Area.OCEAN_DAY)
		BiomeManager.Biome.DESERT: enter_area(Area.DESERT_DAY)
		BiomeManager.Biome.JUNGLE: enter_area(Area.JUNGLE_DAY) # Switch to Jungle Day Area

func _on_layer_changed(new_layer: BiomeManager.Layer) -> void:
	var layer_name = BiomeManager.Layer.keys()[BiomeManager.Layer.values().find(new_layer)]
	print("[MusicManager] Layer Signal Received: ", layer_name)

	match new_layer:
		BiomeManager.Layer.SPACE: enter_area(Area.SPACE)
		BiomeManager.Layer.SURFACE: 
			_on_biome_changed(BiomeManager.current_biome)
		BiomeManager.Layer.UNDERGROUND: enter_area(Area.UNDERGROUND)
		BiomeManager.Layer.CAVERN: enter_area(Area.CAVERN)
		BiomeManager.Layer.UNDERWORLD: enter_area(Area.UNDERWORLD)
