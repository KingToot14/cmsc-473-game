class_name TileEntity
extends Entity

# --- Variables --- #
var tile_position: Vector2i

# --- Functions --- #
func update_preview(tile_pos: Vector2i) -> void:
	tile_position = tile_pos

func attempt_placement() -> bool:
	return false

#region Serialization
func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	id = buffer.get_u32()
	
	super(buffer)
	
	# set tile position
	tile_position = TileManager.world_to_tile(
		floori(global_position.x),
		floori(global_position.y)
	)

#endregion

#region Helpers
static func query_tile_collision(tile_pos: Vector2i) -> bool:
	# create query
	var direct_space: PhysicsDirectSpaceState2D = \
		Globals.get_tree().current_scene.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = Vector2(8.0, 8.0)
	query.transform.origin = TileManager.tile_to_world(tile_pos.x, tile_pos.y, true)
	query.collision_mask = 0b01000000	# Only collides with Tile layer
	
	# check collision
	return not direct_space.intersect_shape(query, 1).is_empty()

#endregion
