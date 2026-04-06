class_name TrapdoorEntity
extends TileEntity

# --- Enums --- #
enum DoorVariant {
	OAK,
	SPRUCE,
	PALM
}

# --- Variables --- #
const DOOR_STATE_ACTION := 16

@export var variant_sprites: Dictionary[DoorVariant, Texture2D] = {}

var variant: DoorVariant
var open_sprite := AtlasTexture.new()
var close_sprite := AtlasTexture.new()

var is_open := false
var door_state := 0

# --- Functions --- #
#region Variants
func setup_variant() -> void:
	open_sprite.atlas = variant_sprites[variant]
	open_sprite.region = Rect2i(0, 0, 32, 16)
	close_sprite.atlas = variant_sprites[variant]
	close_sprite.region = Rect2i(0, 16, 32, 8)

func spawn_item() -> void:
	var world_position := TileManager.tile_to_world(tile_position.x, tile_position.y, true)
	
	match variant:
		DoorVariant.OAK:
			ItemDropEntity.spawn(world_position, 75, 1)
		DoorVariant.SPRUCE:
			ItemDropEntity.spawn(world_position, 80, 1)
		DoorVariant.PALM:
			ItemDropEntity.spawn(world_position, 85, 1)

#endregion

#region Actions
func send_action_door_state(state: int) -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.resize(4 + 4 + 2)
	
	# entity id
	buffer.put_u32(id)
	
	# time
	buffer.put_float(NetworkTime.time)
	
	# action id
	buffer.put_u16(DOOR_STATE_ACTION)
	
	# door state
	door_state = state
	buffer.put_u8(door_state)
	
	# update data
	EntityManager.update_entity_data(self)
	
	# send to clients
	for player_id in interested_players.keys():
		if player_id not in ServerManager.connected_players:
			continue
		
		Globals.entity_sync.queue_action.rpc_id(player_id, buffer.data_array)

func handle_action(action_info: PackedByteArray) -> void:
	super(action_info)
	
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = action_info
	
	# action id
	var action_id := buffer.get_u16() 
	
	# actions
	match action_id:
		DOOR_STATE_ACTION:
			# door state
			set_door_state(buffer.get_u8())

func set_door_state(state: int) -> void:
	door_state = state
	
	if door_state == 0:
		$'blocker'.process_mode = Node.PROCESS_MODE_INHERIT
		$'sprite'.texture = close_sprite
		$'sprite'.flip_v = false
		$'sprite'.position.y = 4
		
		$'shape'.position.y = 4
		$'shape'.shape.size = Vector2(15.5, 3.5)
		$'hitbox'.position.y = 4
		
		is_open = false
	elif door_state == 1:
		# open door left
		$'blocker'.process_mode = Node.PROCESS_MODE_DISABLED
		$'sprite'.texture = open_sprite
		$'sprite'.flip_v = false
		$'sprite'.position.y = 0
		
		$'shape'.position.y = 0
		$'shape'.shape.size = Vector2(15.5, 15.5)
		$'hitbox'.position.y = 0
		
		is_open = true
	elif door_state == 2:
		# open door right
		$'blocker'.process_mode = Node.PROCESS_MODE_DISABLED
		$'sprite'.texture = open_sprite
		$'sprite'.flip_v = true
		$'sprite'.position.y = 8
		
		$'shape'.position.y = 8
		$'shape'.shape.size = Vector2(15.5, 15.5)
		$'hitbox'.position.y = 8
		
		is_open = true

#endregion

#region Door State
@rpc('any_peer', 'call_remote', 'reliable')
func close_door() -> void:
	$'blocker'.process_mode = Node.PROCESS_MODE_INHERIT
	$'sprite'.texture = close_sprite
	$'sprite'.flip_v = false
	
	is_open = false
	
	send_action_door_state(0)

@rpc('any_peer', 'call_remote', 'reliable')
func open_door(direction := 0, try_again := true) -> void:
	if is_open:
		close_door()
		return
	
	# open either direction, left first
	if direction == 0:
		open_door(-1, false)
		if not is_open:
			open_door(1, false)
	# open top
	elif direction == -1:
		# check top blocks
		for x in range(2):
			if TileManager.get_block(tile_position.x + x, tile_position.y - 1) != 0:
				# default to opening either side
				if try_again:
					open_door(0, false)
				return
		
		# open door top
		$'blocker'.process_mode = Node.PROCESS_MODE_DISABLED
		$'sprite'.texture = open_sprite
		$'sprite'.flip_v = false
		
		is_open = true
		
		send_action_door_state(1)
	# open bottom
	elif direction == 1:
		# check bottom blocks
		for x in range(2):
			if TileManager.get_block(tile_position.x + x, tile_position.y + 1) != 0:
				# default to opening either side
				if try_again:
					open_door(0, false)
				return
		
		# open door bottom
		$'blocker'.process_mode = Node.PROCESS_MODE_DISABLED
		$'sprite'.texture = open_sprite
		$'sprite'.flip_v = true
		
		is_open = true
		
		send_action_door_state(2)

#endregion

#region Interactions
func interact_with(_mouse_position: Vector2) -> bool:
	# get direction
	var player := Globals.player
	
	if player.center_point.y < global_position.y:
		open_door.rpc_id(Globals.SERVER_ID, 1)
	else:
		open_door.rpc_id(Globals.SERVER_ID, -1)
	
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
	
	# door state
	buffer.put_u8(door_state)
	
	return buffer.data_array

func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	# process base snapshot
	super(buffer)
	
	# variant
	variant = buffer.get_u16() as DoorVariant
	
	# door state
	set_door_state(buffer.get_u8())
	
	setup_variant()

#endregion

#region Spawning
static func create(tile_pos: Vector2i, tile_variant := &'normal') -> void:
	# create new tree entity
	var entity_scene: PackedScene = EntityManager.tile_entity_registry.get(5).entity_scene
	if not entity_scene:
		return
	
	# make sure placement is valid
	if not is_placement_valid(tile_pos):
		return
	
	var entity: TrapdoorEntity = entity_scene.instantiate()
	
	# setup default parameters
	entity.tile_position = tile_pos
	entity.global_position = TileManager.tile_to_world(tile_pos.x, tile_pos.y)
	
	match tile_variant:
		&'oak':
			entity.variant = DoorVariant.OAK
		&'spruce':
			entity.variant = DoorVariant.SPRUCE
		&'palm':
			entity.variant = DoorVariant.PALM
	
	entity.setup_variant()
	
	EntityManager.store_tile_entity(5, entity)
	
	return

## Returns whether or not the placement is valid. This uses
## [method get_collision_grid] to check for collision and 
## [method get_variant] to make sure the ground beneath is valid.
static func is_placement_valid(tile_pos: Vector2i) -> bool:
	# make sure left and right tiles are filled
	if not BlockDatabase.is_solid[TileManager.get_block(tile_pos.x - 1, tile_pos.y)]:
		return false
	
	if not BlockDatabase.is_solid[TileManager.get_block(tile_pos.x + 2, tile_pos.y)]:
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
