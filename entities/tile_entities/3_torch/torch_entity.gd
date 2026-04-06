class_name TorchEntity
extends TileEntity

# --- Enums --- #
enum AnchorType {
	NONE,
	LEFT,
	RIGHT,
	BOTTOM,
	WALL
}

enum TorchVariant {
	NORMAL
}

# --- Variables --- #
@export var variant: TorchVariant
@export var variant_sprites: Dictionary[TorchVariant, Texture2D] = {}

# --- Functions --- #
func set_entity_id(spawn_id: int, reg_id: int) -> void:
	super(spawn_id, reg_id)
	
	setup_variant()

#region Variants
func setup_variant() -> void:
	match variant:
		TorchVariant.NORMAL:
			# set sprite
			$'sprite'.texture = variant_sprites[TorchVariant.NORMAL]
			
			# add light
			if multiplayer and multiplayer.is_server():
				Globals.light_updater.add_point_light(tile_position, Color.html("#ffd9b3"))
	
	# set variant
	match get_anchor_type(tile_position):
		TorchEntity.AnchorType.BOTTOM:
			$'sprite'.frame = 0
		TorchEntity.AnchorType.LEFT:
			$'sprite'.frame = 1
		TorchEntity.AnchorType.RIGHT:
			$'sprite'.frame = 3
		_:
			$'sprite'.frame = 2

func spawn_item() -> void:
	var world_position := TileManager.tile_to_world(tile_position.x, tile_position.y, true)
	
	match variant:
		TorchVariant.NORMAL:
			ItemDropEntity.spawn(world_position, 28, 1)

#endregion

#region Interactions
func interact_with(_mouse_position: Vector2) -> bool:
	hp.take_damage(10, DamageSource.DamageSourceType.PLAYER)
	
	return true

func _on_death() -> void:
	super()
	
	if multiplayer.is_server():
		# remove light
		Globals.light_updater.remove_point_light(tile_position)

#endregion

#region Serialization
func serialize_spawn_data() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = super()
	
	# snap to end of current buffer
	var cursor := len(buffer.data_array)
	buffer.resize(len(buffer.data_array) + 4 + 2)	# base + uint32 (4) + uint16 (2)
	buffer.seek(cursor)
	
	# variant
	buffer.put_u16(variant)
	
	return buffer.data_array

func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	# process base snapshot
	super(buffer)
	
	# variant
	variant = buffer.get_u16() as TorchVariant

#endregion

#region Spawning
static func create(tile_pos: Vector2i, tile_variant := &'normal') -> void:
	# create new tree entity
	var entity_scene: PackedScene = EntityManager.tile_entity_registry.get(3).entity_scene
	if not entity_scene:
		return
	
	# make sure placement is valid
	if not is_placement_valid(tile_pos):
		return
	
	var entity: TorchEntity = entity_scene.instantiate()
	
	# setup default parameters
	entity.tile_position = tile_pos
	entity.global_position = TileManager.tile_to_world(tile_pos.x, tile_pos.y)
	
	match tile_variant:
		&'normal':
			entity.variant = TorchVariant.NORMAL
	
	EntityManager.store_tile_entity(3, entity)
	
	return

## Returns whether or not the placement is valid. This uses
## [method get_collision_grid] to check for collision and 
## [method get_variant] to make sure the ground beneath is valid.
static func is_placement_valid(tile_pos: Vector2i) -> bool:
	# make sure torch is anchored
	if get_anchor_type(tile_pos) == AnchorType.NONE:
		return false
	
	# make sure collision grid is null
	var collision_grid := get_collision_grid(tile_pos)
	
	for pos: Vector2i in collision_grid:
		if collision_grid[pos]:
			return false
	
	return true

static func get_anchor_type(tile_pos: Vector2i) -> AnchorType:
	# check bottom first
	if TileManager.get_block(tile_pos.x, tile_pos.y + 1) != 0:
		return AnchorType.BOTTOM
	
	# check sides
	if TileManager.get_block(tile_pos.x - 1, tile_pos.y) != 0:
		return AnchorType.LEFT
	if TileManager.get_block(tile_pos.x + 1, tile_pos.y) != 0:
		return AnchorType.RIGHT
	
	# check wall
	if TileManager.get_wall(tile_pos.x, tile_pos.y) != 0:
		return AnchorType.WALL
	
	# not anchored
	return AnchorType.NONE

## Returns a collision grid representing obstacles that are in the way of placement.
## The results is a [code]Dictionary[lb]Vector2i, bool[rb][/code] that maps
## tile positions to whether or not a collision was detected (either a block or
## another tile entity)
static func get_collision_grid(tile_pos: Vector2i) -> Dictionary[Vector2i, bool]:
	var grid: Dictionary[Vector2i, bool] = {
		tile_pos: false
	}
	
	# current position
	if TileManager.get_block(tile_pos.x, tile_pos.y) != 0:
		grid[tile_pos] = true
	elif query_tile_collision(tile_pos):
		grid[tile_pos] = true
	
	return grid

#endregion
