class_name CraftingStationEntity
extends TileEntity

# --- Enums --- #
enum CraftingVariant {
	OAK,
	SPRUCE,
	PALM
}

# --- Variables --- #
var variant := CraftingVariant.OAK

@export var variant_sprites: Dictionary[CraftingVariant, Texture2D] = {}

# --- Functions --- #
#region Sprite
func setup_variant() -> void:
	$'sprite'.texture = variant_sprites[variant]

#endregion

#region Interaction
func interact_with(mouse_position: Vector2) -> bool:
	if is_dead:
		return false
	
	if not Globals.player.is_point_in_range(mouse_position):
		return false
	
	# do crafting stuff
	
	return true

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
	
	return buffer.data_array

func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	# process base snapshot
	super(buffer)
	
	# variant
	variant = buffer.get_u16() as CraftingVariant
	
	setup_variant()

#endregion

#region Spawning
static func create(tile_pos: Vector2i, tile_variant := &'normal') -> void:
	# create new tree entity
	var entity_scene: PackedScene = EntityManager.tile_entity_registry.get(9).entity_scene
	if not entity_scene:
		return
	
	# make sure placement is valid
	if not is_placement_valid(tile_pos):
		return
	
	var entity: CraftingStationEntity = entity_scene.instantiate()
	
	# setup default parameters
	entity.tile_position = tile_pos
	entity.global_position = TileManager.tile_to_world(tile_pos.x, tile_pos.y)
	
	match tile_variant:
		&'oak':
			entity.variant = CraftingVariant.OAK
		&'spruce':
			entity.variant = CraftingVariant.SPRUCE
		&'palm':
			entity.variant = CraftingVariant.PALM
	
	entity.setup_variant()
	
	EntityManager.store_tile_entity(9, entity)
	
	return

## Returns whether or not the placement is valid. This uses
## [method get_collision_grid] to check for collision and 
## [method get_variant] to make sure the ground beneath is valid.
static func is_placement_valid(tile_pos: Vector2i) -> bool:
	# make sure bottom tiles are filled
	for x in range(2):
		if TileManager.get_block(tile_pos.x + x, tile_pos.y + 1) == 0:
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
	
	for x in range(2):
		var pos := Vector2i(tile_pos.x + x, tile_pos.y)
		
		grid[pos] = false
		
		if TileManager.get_block(pos.x, pos.y) != 0:
			grid[pos] = true
		elif query_tile_collision(pos):
			grid[pos] = true

	return grid

#endregion
