class_name ChestEntity
extends TileEntity

# --- Enums --- #
enum ChestVariant {
	NORMAL
}

# --- Variables --- #
const SYNC_ACTION := 16

const INVENTORY_SIZE := 40

@export var variant := ChestVariant.NORMAL

var inventory := Inventory.new(INVENTORY_SIZE)

# --- Functions --- #
func _ready() -> void:
	super()
	
	inventory.inventory_updated.connect(send_inventory_update)

#region Sprite
func setup_variant() -> void:
	var info := EntityManager.tile_entity_registry[2]
	
	match variant:
		ChestVariant.NORMAL:
			pass

#endregion

#region Interaction
func interact_with(mouse_position: Vector2) -> bool:
	# make sure player is within interaction range
	if not Globals.player.is_point_in_range(mouse_position):
		return false
	
	# handle interaction 
	# NOTE: the 'id' variable in this script is a unique id that is synchronized between the server
	# and the client, so you could use this to handle opening and displaying the chest inventory.
	print("Chest Interacted!")
	
	return true

func handle_action(action_info: PackedByteArray) -> void:
	super(action_info)
	
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = action_info
	
	# action id
	var action_id := buffer.get_u16()
	
	# actions
	match action_id:
		SYNC_ACTION:
			var inventory_size := buffer.get_u16()
			
			inventory.receive_inventory(buffer.get_data(inventory_size))

func send_inventory_update() -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.resize(4 + 4 + 2)
	
	# entity id
	buffer.put_u32(id)
	
	# time
	buffer.put_float(NetworkTime.time)
	
	# action id
	buffer.put_u16(SYNC_ACTION)
	
	# inventory size
	var inventory_data := inventory.serialize_inventory()
	buffer.put_u16(len(inventory_data))
	
	# inventory
	buffer.put_data(inventory_data)
	
	for player_id in interested_players.keys():
		if not ServerManager.get_player(player_id):
			continue
		
		Globals.entity_sync.queue_action.rpc_id(player_id, buffer.data_array)

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
	
	# inventory size
	var inventory_data := inventory.serialize_inventory()
	buffer.put_u16(len(inventory_data))
	
	# inventory
	buffer.put_data(inventory_data)
	
	return buffer.data_array

func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	# process base snapshot
	super(buffer)
	
	# variant
	variant = buffer.get_u16() as ChestVariant
	
	# inventory size
	var inventory_size := buffer.get_u16()
	
	# inventory
	inventory.receive_inventory(buffer.get_data(inventory_size)[1])
	
	setup_variant()

#endregion

#region Spawning
static func create(tile_pos: Vector2i, tile_variant := &'normal') -> void:
	# create new tree entity
	var entity_scene: PackedScene = EntityManager.tile_entity_registry.get(2).entity_scene
	if not entity_scene:
		return
	
	# make sure placement is valid
	if not is_placement_valid(tile_pos):
		return
	
	var entity: ChestEntity = entity_scene.instantiate()
	
	# setup default parameters
	entity.tile_position = tile_pos
	
	match tile_variant:
		&'normal':
			entity.variant = ChestVariant.NORMAL
	
	entity.setup_variant()
	
	EntityManager.store_tile_entity(2, entity)
	
	return

## Returns whether or not the placement is valid. This uses
## [method get_collision_grid] to check for collision and 
## [method get_variant] to make sure the ground beneath is valid.
static func is_placement_valid(tile_pos: Vector2i) -> bool:
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
	var pos_bl := Vector2i(tile_pos.x,     tile_pos.y)
	var pos_br := Vector2i(tile_pos.x + 1, tile_pos.y)
	var pos_tl := Vector2i(tile_pos.x,     tile_pos.y - 1)
	var pos_tr := Vector2i(tile_pos.x + 1, tile_pos.y - 1)
	
	var grid: Dictionary[Vector2i, bool] = {
		pos_bl: false,
		pos_br: false,
		pos_tl: false,
		pos_tr: false
	}
	
	# bottom left
	if TileManager.get_block(pos_bl.x, pos_bl.y) != 0:
		grid[pos_bl] = true
	elif query_tile_collision(pos_bl):
		grid[pos_bl] = true
	
	# bottom right
	if TileManager.get_block(pos_br.x, pos_br.y) != 0:
		grid[pos_br] = true
	elif query_tile_collision(pos_br):
		grid[pos_br] = true
	
	# top left
	if TileManager.get_block(pos_tl.x, pos_tl.y) != 0:
		grid[pos_tl] = true
	elif query_tile_collision(pos_tl):
		grid[pos_tl] = true
	
	# top right
	if TileManager.get_block(pos_tr.x, pos_tr.y) != 0:
		grid[pos_tr] = true
	elif query_tile_collision(pos_tr):
		grid[pos_tr] = true
	
	return grid

#endregion
