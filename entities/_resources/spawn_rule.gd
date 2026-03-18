class_name SpawnRule
extends Resource

# --- Enums --- #
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

# --- Functions --- #
func is_spawnable(biome: BiomeManager.Biome, layer: BiomeManager.Layer, time_state: TimeState) -> bool:
	return (biome & spawn_biomes) and (layer & spawn_layers) and (time_state & spawn_times)

@warning_ignore("unused_parameter")
func do_spawn(position: Vector2) -> void:
	return
