extends Node

# -- Signals --- #
signal world_size_changed(size: Vector2i)

# --- Variables --- #
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

# --- Functions --- #
func _ready() -> void:
	world_size = world_size

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
