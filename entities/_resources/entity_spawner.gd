class_name EntitySpawner
extends Node

# --- Variables --- #
const PLAYER_CAP := 20.0
const GLOBAL_CAP := 150.0

@export var spawn_rate := 2.0
var spawn_timer := spawn_rate

var current_player_count := 0
var spawn_player_queue: Array[int] = []
var spawn_player_index := 0

var rng := RandomNumberGenerator.new()

# --- Functions --- #
func _ready() -> void:
	set_process(false)
	ServerManager.server_started.connect(func (): set_process(true))

func _process(delta: float) -> void:
	if len(ServerManager.connected_players.keys()) == 0:
		return
	
	# decrement timer
	spawn_timer -= delta
	
	if spawn_timer <= 0.0:
		spawn_timer += spawn_rate
		
		attempt_spawn()

@warning_ignore_start('confusable_local_declaration')
func attempt_spawn() -> void:
	var player_count: int = len(ServerManager.connected_players.keys())
	
	# reset queue if changed
	if player_count != current_player_count:
		spawn_player_index = 0
		spawn_player_queue = ServerManager.connected_players.keys()
		current_player_count = player_count
	
	# get current spawning player
	var spawn_player_id: int = spawn_player_queue[spawn_player_index]
	var spawn_player: PlayerController = ServerManager.connected_players.get(spawn_player_id)
	if not spawn_player:
		return
	
	spawn_player_index = (spawn_player_index + 1) % current_player_count
	
	var bounding_boxes: Dictionary[int, Rect2i] = {}
	
	var total_entities := 0
	for player_id in ServerManager.connected_players.keys():
		var player: PlayerController = ServerManager.connected_players[player_id]
		
		var chunk: Vector2i = TileManager.world_to_chunk(
			floori(player.center_point.x),
			floori(player.center_point.y)
		)
		var start_chunk: Vector2i = chunk - ChunkLoader.VISUAL_RANGE
		var size: Vector2i = 2 * ChunkLoader.VISUAL_RANGE + Vector2i.ONE
		
		# check bounds
		start_chunk.x = max(start_chunk.x, 0)
		start_chunk.y = max(start_chunk.y, 0)
		size.x = min(size.x + start_chunk.x, Globals.world_chunks.x) - start_chunk.x
		size.y = min(size.y + start_chunk.y, Globals.world_chunks.y) - start_chunk.y
		
		bounding_boxes[player_id] = Rect2i(start_chunk, size)
		
		# update entity count
		total_entities += len(player.interested_entities)
	
	# check current cap
	var spawn_mod = max(len(spawn_player.interested_entities) / PLAYER_CAP, total_entities / GLOBAL_CAP)
	
	if rng.randf() >= (1.0 - spawn_mod * spawn_mod):
		return
	
	# attempt to spawn entity
	var chunk: Vector2i = TileManager.world_to_chunk(
		floori(spawn_player.center_point.x),
		floori(spawn_player.center_point.y)
	)
	var start_chunk: Vector2i = chunk - ChunkLoader.LOAD_RANGE
	var end_chunk: Vector2i = chunk + ChunkLoader.LOAD_RANGE
	
	# check bounds
	start_chunk.x = max(start_chunk.x, 0)
	start_chunk.y = max(start_chunk.y, 0)
	end_chunk.x = min(end_chunk.x, Globals.world_chunks.x)
	end_chunk.y = min(end_chunk.y, Globals.world_chunks.y)
	
	# calculate valid spawn chunks
	var valid_chunks: Dictionary[Vector2i, bool] = {}
	
	for x in range(start_chunk.x, end_chunk.x):
		for y in range(start_chunk.y, end_chunk.y):
			for player_id in ServerManager.connected_players.keys():
				var box: Rect2i = bounding_boxes[player_id]
				
				if box.has_point(Vector2i(x, y)):
					continue
				
				valid_chunks[Vector2i(x, y)] = true
	
	if len(valid_chunks) == 0:
		return
	
	# get entity from pool
	var biome := SpawnRule.Biome.FOREST
	var layer := SpawnRule.Layer.SURFACE
	var time := SpawnRule.TimeState.DAY
	
	var spawn_rule_ids: Dictionary[SpawnRule, int] = {}
	var possible_rules: Array[SpawnRule] = []
	var possible_weights: Array[int] = []
	
	# gather possible rules
	for id in EntityManager.enemy_registry.keys():
		for spawn_rule: SpawnRule in EntityManager.enemy_registry[id].spawn_rules:
			if not spawn_rule.is_spawnable(biome, layer, time):
				continue
			
			spawn_rule_ids[spawn_rule] = id
			possible_rules.append(spawn_rule)
			possible_weights.append(spawn_rule.spawn_weight)
	
	# select random from pool
	if len(possible_rules) == 0:
		return
	
	var spawn_rule: SpawnRule = possible_rules[RandomNumberGenerator.new().rand_weighted(possible_weights)]
	var entity_id := spawn_rule_ids[spawn_rule]
	var spawn_data: Dictionary = spawn_rule.spawn_data
	
	# get world position
	for i in range(10):
		var spawn_chunk: Vector2i = valid_chunks.keys().pick_random()
		var valid := false
		
		var tile_origin: Vector2i = TileManager.chunk_to_tile(spawn_chunk.x, spawn_chunk.y)
		tile_origin.x += randi_range(0, 15)
		
		# scan downward for a valid position
		for y in range(32):
			if (TileManager.get_block(tile_origin.x, tile_origin.y + y + 1) == 0 or 
				TileManager.get_block(tile_origin.x, tile_origin.y + y) != 0):
				continue
			
			valid = true
			tile_origin.y += y
			break
		
		# retry if not valid
		if not valid:
			continue
		
		# spawn entity from pool
		var world_position: Vector2 = TileManager.tile_to_world(tile_origin.x, tile_origin.y)
		EntityManager.create_entity(entity_id, world_position, spawn_data)
		return

@warning_ignore_restore('confusable_local_declaration')
