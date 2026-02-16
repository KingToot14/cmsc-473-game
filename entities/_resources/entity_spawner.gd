class_name EntitySpawner
extends Node

# --- Variables --- #
@export var spawn_rate := 1.0
var spawn_timer := spawn_rate

# --- Functions --- #
func _ready() -> void:
	set_process(false)
	ServerManager.server_started.connect(func (): set_process(true))

func _process(delta: float) -> void:
	if len(ServerManager.connected_players) == 0:
		return
	
	# decrement timer
	spawn_timer -= delta
	
	if spawn_timer <= 0.0:
		spawn_timer += spawn_rate
		
		var bounding_boxes: Dictionary[int, Rect2i] = {}
		
		for player_id in ServerManager.connected_players.keys():
			var player: PlayerController = ServerManager.connected_players[player_id]
			var chunk: Vector2i = TileManager.world_to_chunk(player.center_point.x, player.center_point.y)
			var start_chunk: Vector2i = chunk - ChunkLoader.VISUAL_RANGE
			var size: Vector2i = 2 * ChunkLoader.VISUAL_RANGE + Vector2i.ONE
			
			# check bounds
			start_chunk.x = max(start_chunk.x, 0)
			start_chunk.y = max(start_chunk.y, 0)
			size.x = min(size.x + start_chunk.x, Globals.world_chunks.x) - start_chunk.x
			size.y = min(size.y + start_chunk.y, Globals.world_chunks.y) - start_chunk.y
			
			bounding_boxes[player_id] = Rect2i(start_chunk, size)
		
		# attempt to spawn entity
		for player_id in ServerManager.connected_players.keys():
			var player: PlayerController = ServerManager.connected_players[player_id]
			var chunk: Vector2i = TileManager.world_to_chunk(player.center_point.x, player.center_point.y)
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
					for o_player_id in ServerManager.connected_players.keys():
						var o_box: Rect2i = bounding_boxes[o_player_id]
						
						if o_box.has_point(Vector2i(x, y)):
							continue
						
						valid_chunks[Vector2i(x, y)] = true
			
			if len(valid_chunks) == 0:
				return
			
			# get world position
			var spawn_chunk: Vector2i = valid_chunks.keys().pick_random()
			var tile_origin: Vector2i = TileManager.chunk_to_tile(spawn_chunk.x, spawn_chunk.y)
			
			var tile_x: int = randi_range(0, 15)
			var tile_y: int = randi_range(0, 15)
			
			var world_position: Vector2 = TileManager.tile_to_world(
				tile_origin.x + tile_x,
				tile_origin.y + tile_y
			)
			
			# spawn entity from pool
			EntityManager.create_entity(1, world_position, {
				&'variant': &'green'
			})
