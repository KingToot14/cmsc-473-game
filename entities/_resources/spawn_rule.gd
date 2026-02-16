class_name SpawnRule
extends Resource

# --- Enums --- #
enum Biome {
	FOREST = 1,
	DESERT = 2,
	SNOW   = 4,
	OCEAN  = 8
}

enum Layer {
	SPACE       = 1,
	SURFACE     = 2,
	UNDERGROUND = 4,
	CAVERN      = 8,
	UNDERWORLD  = 16
}

enum TimeState {
	DAY   = 1,
	NIGHT = 2
}

enum SpawnLocation {
	GROUND      = 1,
	AIR         = 2,
	UNDERGROUND = 4
}

# --- Variables --- #
@export var spawn_location := SpawnLocation.GROUND

@export_flags('forest', 'desert', 'snow', 'ocean') var spawn_biomes := 0
@export_flags('space', 'surface', 'underground', 'cavern', 'underworld') var spawn_layers := 0
@export_flags('day', 'night') var spawn_times := 0

@export var spawn_weight := 25

@export var spawn_data: Dictionary = {}

# --- Functions --- #
func is_spawnable(biome: Biome, layer: Layer, time_state: TimeState) -> bool:
	return (biome & spawn_biomes) and (layer & spawn_layers) and (time_state & spawn_times)
