class_name DoorEntity
extends TileEntity

# --- Enums --- #
enum DoorVariant {
	OAK,
	SPRUCE,
	PALM
}

# --- Variables --- #
var variant: DoorVariant

# --- Functions --- #
func setup_variant() -> void:
	match variant:
		DoorVariant.OAK:
			pass
		DoorVariant.SPRUCE:
			pass
		DoorVariant.PALM:
			pass

#region Serialization
func serialize_spawn_data() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = super()
	
	var cursor := len(buffer.data_array)
	buffer.resize(len(buffer.data_array) + 4 + 2)
	buffer.seek(cursor)
	
	# variant
	buffer.put_u16(variant)
	
	return buffer.data_array

func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	# process base snapshot
	super(buffer)
	
	# variant
	variant = buffer.get_u16() as DoorVariant
	
	setup_variant()

#endregion

#region Spawning
static func create(tile_pos: Vector2i, tile_variant := &'normal') -> void:
	# create new tree entity
	var entity_scene: PackedScene = EntityManager.tile_entity_registry.get(4).entity_scene
	if not entity_scene:
		return
	
	# make sure placement is valid
	if not is_placement_valid(tile_pos):
		return
	
	var entity: DoorEntity = entity_scene.instantiate()
	
	# setup default parameters
	entity.tile_position = tile_pos
	entity.global_position = TileManager.tile_to_world(tile_pos.x, tile_pos.y)
	
	match tile_variant:
		&'OAK':
			entity.variant = DoorVariant.OAK
	
	entity.setup_variant()
	
	EntityManager.store_tile_entity(4, entity)
	
	return

## Returns whether or not the placement is valid. This uses
## [method get_collision_grid] to check for collision and 
## [method get_variant] to make sure the ground beneath is valid.
static func is_placement_valid(tile_pos: Vector2i) -> bool:
	# make sure top and bottom tiles are filled
	if TileManager.get_block(tile_pos.x, tile_pos.y + 1) == 0:
		return false
	
	if TileManager.get_block(tile_pos.x, tile_pos.y - 3) == 0:
		return false
	
	# make sure collision grid is null
	var collision_grid := get_collision_grid(tile_pos)
	
	for pos: Vector2i in collision_grid:
		if collision_grid[pos]:
			return false
	
	return true

## Returns a collision grid representing obstacles that are in the way of placement.
## The results is a [code]Dictionary[lb]Vector2i, bool[rb][/code] that maps
## tile positions to whether or not a collision was detected (either a block or
## another tile entity)
static func get_collision_grid(tile_pos: Vector2i) -> Dictionary[Vector2i, bool]:
	var grid: Dictionary[Vector2i, bool] = {}
	
	for y in range(3):
		for x in range(2):
			var pos := Vector2i(tile_pos.x + x, tile_pos.y - y)
			
			grid[pos] = false
			
			if TileManager.get_block(pos.x, pos.y) != 0:
				grid[pos] = true
			elif query_tile_collision(pos):
				grid[pos] = true
	
	return grid

#endregion
