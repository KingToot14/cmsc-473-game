extends Node

# -- Signals --- #
signal world_size_changed(size: Vector2i)

# --- Enums --- #
enum GameState {
	MAIN_MENU,
	JOINING,
	IN_GAME
}

enum CursorType {
	ARROW,
	BEAM,
	CROSS,
	PICKAXE,
	AXE,
	HAMMER,
	OPEN
}

# --- Variables --- #
const SERVER_ID := 1

const CURSOR_SIZE := 12
const IN_GAME_CURSOR_SCALE := 0.75

var game_state := GameState.MAIN_MENU

# - World Size
var world_size := Vector2i(4200, 1200):
	set(_size):
		world_chunks = Vector2i(
			ceili(float(_size.x) / TileManager.CHUNK_SIZE),
			ceili(float(_size.y) / TileManager.CHUNK_SIZE)
		)
		world_size = _size
		world_size_changed.emit(world_size)

@warning_ignore("integer_division")
var world_chunks: Vector2i = Vector2i(
	ceili(float(world_size.x) / TileManager.CHUNK_SIZE),
	ceili(float(world_size.y) / TileManager.CHUNK_SIZE)
)
var world_spawn: Vector2i

# - TileMaps
var server_map: ServerTileMap
var world_map: WorldTileMap

# - Player Interactions
var hovered_hitbox: TileEntityHitbox

# - Player
var player: PlayerController
var music: MusicManager

# - Items
var item_registry: Dictionary[int, String] = {}

# - Cursor
var current_cursor := CursorType.ARROW
var scale_factor := 1.0

# --- Functions --- #
func _ready() -> void:
	world_size = world_size
	
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	_on_viewport_size_changed()

func parse_arguments() -> Dictionary:
	var arguments: Dictionary = {}
	
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		arg = arg.replace('--', '')
		if arg.contains('='):
			var tokens := arg.split('=')
			arguments[tokens[0]] = tokens[1]
		else:
			arguments[arg] = true
	
	return arguments

func set_game_state(state: GameState) -> void:
	game_state = state
	
	reset_cursors()

#region Cursors
func _on_viewport_size_changed() -> void:
	var scale := get_viewport().get_stretch_transform().get_scale()
	scale_factor = min(scale.x, scale.y)
	
	reset_cursors()

func reset_cursors() -> void:
	# set beam cursor
	var beam_image := get_cursor_image(1, 0)
	Input.set_custom_mouse_cursor(beam_image, Input.CURSOR_IBEAM, Vector2(CURSOR_SIZE, CURSOR_SIZE))
	
	# reload current cursor
	set_cursor(current_cursor)

func set_cursor(type: CursorType) -> void:
	var cursor_image: Image
	var hotspot := Vector2(CURSOR_SIZE / 2.0, CURSOR_SIZE / 2.0)
	
	current_cursor = type
	
	# set image and hotspots
	match type:
		CursorType.ARROW:
			cursor_image = get_cursor_image(0, 0)
			hotspot = Vector2(2, 1)
		CursorType.BEAM:
			cursor_image = get_cursor_image(1, 0)
		CursorType.CROSS:
			cursor_image = get_cursor_image(2, 0)
		CursorType.PICKAXE:
			cursor_image = get_cursor_image(0, 1)
			hotspot = Vector2(1, 1)
		CursorType.AXE:
			cursor_image = get_cursor_image(1, 1)
			hotspot = Vector2(1, 1)
		CursorType.HAMMER:
			cursor_image = get_cursor_image(2, 1)
			hotspot = Vector2(1, 1)
		CursorType.OPEN:
			cursor_image = get_cursor_image(0, 2)
			hotspot = Vector2(1, 1)
	
	# set custom mouse
	var scale := scale_factor
	
	if game_state == GameState.IN_GAME:
		scale *= IN_GAME_CURSOR_SCALE
	
	Input.set_custom_mouse_cursor(
		cursor_image,
		Input.CURSOR_ARROW,
		Vector2(floori(hotspot.x * scale), floori(hotspot.y * scale))
	)

func get_cursor_image(x: int, y: int) -> Image:
	var cursor_texture := AtlasTexture.new()
	cursor_texture.atlas = preload("res://ui/cursors.png")
	cursor_texture.region = Rect2(x * CURSOR_SIZE, y * CURSOR_SIZE, CURSOR_SIZE, CURSOR_SIZE)
	
	var scale := scale_factor
	
	if game_state == GameState.IN_GAME:
		scale *= IN_GAME_CURSOR_SCALE
	
	# resize to fit viewport
	var image := cursor_texture.get_image()
	image.resize(
		floori(CURSOR_SIZE * scale),
		floori(CURSOR_SIZE * scale),
		Image.INTERPOLATE_NEAREST
	)
	
	return image

#endregion
