class_name FallingBlockEntity
extends Entity

# --- Variables --- #
var block_id: int
var x_position := 0.0

@export var gravity := 980.0
@export var terminal_velocity := 380.0

# --- Functions --- #
func _physics_process(delta: float) -> void:
	# gravity
	if not is_on_floor():
		velocity.y = clampf(velocity.y + gravity * delta, -terminal_velocity, terminal_velocity)
	else:
		velocity.y = 0.0
	
	move_and_slide()
	global_position.x = x_position
	
	# check for solid blocks
	var tile_position := TileManager.world_to_tile(
		floori(global_position.x),
		floori(global_position.y)
	)
	var below_position := TileManager.world_to_tile(
		floori(global_position.x),
		floori(global_position.y + TileManager.TILE_SIZE / 2.0)
	)
	
	if TileManager.get_block(below_position.x, below_position.y) != 0:
		TileManager.set_block(tile_position.x, tile_position.y, block_id)
		TileManager.send_tile_update(tile_position.x, tile_position.y)
		kill()

func load_block() -> void:
	pass

#region Serialization
func serialize_spawn_data() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = super()
	
	# snap to end of current buffer
	var cursor := len(buffer.data_array)
	buffer.resize(len(buffer.data_array) + 4 + 2)	# base + uint32 (4) + uint16 (2)
	buffer.seek(cursor)
	
	# block id
	buffer.put_u16(block_id)
	
	return buffer.data_array

func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	id = buffer.get_u32()
	
	# process base snapshot
	super(buffer)
	
	# item id
	block_id = buffer.get_u16()
	
	load_block()

#endregion

#region Spawning
@warning_ignore("shadowed_variable")
static func spawn(tile_position: Vector2i, block_id: int) -> void:
	# create new item drop entity
	var entity_scene: PackedScene = EntityManager.enemy_registry.get(2).entity_scene
	if not entity_scene:
		return
	
	# get world position
	var world_position := TileManager.tile_to_world(tile_position.x, tile_position.y, true)
	
	# create entity
	var entity: FallingBlockEntity = entity_scene.instantiate()
	entity.global_position = world_position
	entity.x_position = world_position.x
	
	entity.block_id = block_id
	
	# start entity logic
	entity.load_block()
	
	# sync to players
	EntityManager.add_entity(2, entity)

#endregion
