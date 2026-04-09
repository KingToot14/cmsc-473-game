class_name ChairEntity
extends TileEntity

# --- Enums --- #
enum ChairVariant {
	OAK,
	SPRUCE,
	PALM
}

# --- Variables --- #
@export var variant_sprites: Dictionary[ChairVariant, Texture2D] = {}
var variant: ChairVariant
var direction := 1

# --- Functions --- #
#region Variants
func setup_variant() -> void:
	$'sprite'.texture = variant_sprites[variant]
	$'sprite'.flip_h = direction == -1

func spawn_item() -> void:
	var world_position := TileManager.tile_to_world(tile_position.x, tile_position.y, true)
	
	match variant:
		ChairVariant.OAK:
			ItemDropEntity.spawn(world_position, 77, 1)
		ChairVariant.SPRUCE:
			ItemDropEntity.spawn(world_position, 82, 1)
		ChairVariant.PALM:
			ItemDropEntity.spawn(world_position, 87, 1)

#endregion

#region Serialization
func serialize_spawn_data() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = super()
	
	var cursor := len(buffer.data_array)
	buffer.resize(len(buffer.data_array) + 4 + 2)
	buffer.seek(cursor)
	
	# variant
	buffer.put_u16(variant)
	
	# direction
	buffer.put_8(direction)
	
	return buffer.data_array

func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	# process base snapshot
	super(buffer)
	
	# variant
	variant = buffer.get_u16() as ChairVariant
	
	# direction
	direction = buffer.get_8()
	
	setup_variant()

#endregion

#region Spawning
static func create(tile_pos: Vector2i, tile_variant := &'normal', dir := 1) -> void:
	# create new tree entity
	var entity_scene: PackedScene = EntityManager.tile_entity_registry.get(7).entity_scene
	if not entity_scene:
		return
	
	# make sure placement is valid
	if not is_placement_valid(tile_pos):
		return
	
	var entity: ChairEntity = entity_scene.instantiate()
	
	# setup default parameters
	entity.tile_position = tile_pos
	entity.global_position = TileManager.tile_to_world(tile_pos.x, tile_pos.y)
	
	match tile_variant:
		&'oak':
			entity.variant = ChairVariant.OAK
		&'spruce':
			entity.variant = ChairVariant.SPRUCE
		&'palm':
			entity.variant = ChairVariant.PALM
	
	# set direction
	@warning_ignore('narrowing_conversion')
	entity.direction = dir
	
	entity.setup_variant()
	
	EntityManager.store_tile_entity(7, entity)
	
	return

## Returns whether or not the placement is valid. This uses
## [method get_collision_grid] to check for collision and 
## [method get_variant] to make sure the ground beneath is valid.
static func is_placement_valid(tile_pos: Vector2i) -> bool:
	# make sure bottom tile is filled
	if TileManager.get_block(tile_pos.x, tile_pos.y + 1) == 0:
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
	
	for y in range(2):
		var pos := Vector2i(tile_pos.x, tile_pos.y - y)
		
		grid[pos] = false
		
		if TileManager.get_block(pos.x, pos.y) != 0:
			grid[pos] = true
		elif query_tile_collision(pos):
			grid[pos] = true

	return grid

#endregion
