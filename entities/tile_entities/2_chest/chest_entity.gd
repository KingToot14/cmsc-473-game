class_name ChestEntity
extends TileEntity

# --- Enums --- #
enum ChestVariant {
	NORMAL,
	OAK,
	SPRUCE,
	PALM
}

# --- Variables --- #
const SYNC_ACTION := 16
const OPEN_STATE_ACTION := 17

const INVENTORY_SIZE := 40

@export var variant_sprites: Dictionary[ChestVariant, Texture2D] = {}

var variant := ChestVariant.NORMAL

var inventory := Inventory.new()
var in_use_by := 0

# --- Functions --- #
func _ready() -> void:
	super()
	inventory.name = "inventory"
	add_child(inventory) 
	inventory.inventory_updated.connect(send_inventory_update)
	inventory.inventory_updated.connect(EntityManager.update_entity_data.bind(self))
	if multiplayer.is_server():
		hp.died.connect(_on_death)

#region Sprite
func setup_variant() -> void:
	$'sprite'.texture = variant_sprites[variant]
	
	match variant:
		ChestVariant.NORMAL:
			pass

#endregion

#region Interaction
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var mouse_pos = get_global_mouse_position()
		var chest_size_pixels = TileManager.TILE_SIZE * 2
		var chest_size = Vector2(chest_size_pixels, chest_size_pixels)
		var top_left_corner = global_position - Vector2(0, TileManager.TILE_SIZE)
		var click_rect = Rect2(top_left_corner, chest_size)
		
		if click_rect.has_point(mouse_pos):
			if interact_with(mouse_pos):
				get_viewport().set_input_as_handled()

func interact_with(mouse_position: Vector2) -> bool:
	if is_dead:
		return false
	
	if not Globals.player.is_point_in_range(mouse_position):
		return false
	
	# ask the server for permission to open this chest
	if multiplayer.is_server():
		request_open_chest()
	else:
		request_open_chest.rpc_id(Globals.SERVER_ID)
	
	return true

@rpc('any_peer', 'call_remote', 'reliable')
func request_open_chest() -> void:
	# get the ID of the player asking
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: # host clicked on it
		sender_id = 1 
	
	# if the chest is free, or if the person asking already owns the lock
	if in_use_by == 0 or in_use_by == sender_id:
		in_use_by = sender_id
		
		# update open state
		send_open_state(true)
		
		# tell that specific player to open their UI
		if sender_id == 1:
			open_chest_client()
		else:
			open_chest_client.rpc_id(sender_id)
	else:
		print("Chest is currently in use by player: ", in_use_by)

@rpc('authority', 'call_remote', 'reliable')
func open_chest_client() -> void:
	# this only runs on the client who got permission
	var chest_ui = Globals.player.get_node_or_null("inventory_ui/chest_container")
	
	if chest_ui:
		chest_ui.open_chest(self)
		Globals.player.get_node("inventory_ui/inventory_container").show() 

@rpc('any_peer', 'call_remote', 'reliable')
func release_chest() -> void:
	# get the ID of the player telling us to unlock it
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	
	# only the player who locked it is allowed to unlock it
	if in_use_by == sender_id:
		in_use_by = 0
		
		# update open state
		send_open_state(false)

func break_place(_mouse_position: Vector2) -> bool:
	if is_dead:
		return false
	# check held item
	var item_stack := Globals.player.my_inventory.get_selected_item()
	var item := ItemDatabase.get_item(item_stack.item_id)
	
	# make sure item is a tool
	if not item or item is not ToolItem:
		return false
	
	# make sure tool is an axe (since it's a wooden chest)
	if not item.tool_type & ToolItem.ToolType.AXE:
		return false
	
	# deal damage based on the axe's power
	hp.take_damage(item.tool_power, DamageSource.DamageSourceType.PLAYER)
	
	return true

func _on_death() -> void:
	if is_dead:
		return
	
	kill()
	
	if multiplayer.is_server():
		EntityManager.clear_entity_data(self)
		
		# Add a slight offset to center the dropped items on the 2x2 chest
		var drop_pos = global_position + Vector2(16, 16) 
		
		# 1. Drop the chest item itself (Item ID 24)
		ItemDropEntity.spawn(drop_pos, 24, 1)
		
		# 2. Drop everything inside the chest
		for stack in inventory.items:
			if not stack.is_empty():
				ItemDropEntity.spawn(drop_pos, stack.item_id, stack.count)
				
		# 3. Tell the server AND all clients to delete the chest visuals!
		destroy_chest.rpc()

# This RPC forces the node to delete itself on every single player's screen
@rpc('authority', 'call_local', 'reliable')
func destroy_chest() -> void:
	queue_free()

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
			inventory.receive_inventory(buffer.get_data(inventory_size)[1])
		OPEN_STATE_ACTION:
			var is_open := buffer.get_u8() == 1
			
			if is_open:
				$'sprite'.frame = 1
			else:
				$'sprite'.frame = 0

func send_open_state(is_open: bool) -> void:
	var inventory_data := inventory.serialize_inventory()
	
	var buffer := StreamPeerBuffer.new()
	buffer.resize(4 + 4 + 2 + 2 + len(inventory_data)) 
	
	# entity id
	buffer.put_u32(id)
	
	# time
	buffer.put_float(NetworkTime.time)
	
	# action id
	buffer.put_u16(OPEN_STATE_ACTION)
	
	# state
	buffer.put_u8(1 if is_open else 0)
	
	for player_id in interested_players.keys():
		if player_id not in ServerManager.connected_players:
			continue
		
		Globals.entity_sync.queue_action.rpc_id(player_id, buffer.data_array)

func send_inventory_update() -> void:
	var inventory_data := inventory.serialize_inventory()
	
	var buffer := StreamPeerBuffer.new()
	buffer.resize(4 + 4 + 2 + 2 + len(inventory_data)) 
	
	# entity id
	buffer.put_u32(id)
	
	# time
	buffer.put_float(NetworkTime.time)
	
	# action id
	buffer.put_u16(SYNC_ACTION)
	
	# inventory size
	buffer.put_u16(len(inventory_data))
	
	# inventory
	buffer.put_data(inventory_data)
	
	for player_id in interested_players.keys():
		if player_id not in ServerManager.connected_players:
			continue
		
		Globals.entity_sync.queue_action.rpc_id(player_id, buffer.data_array)

#endregion

#region Serialization
func serialize_spawn_data() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = super()
	
	var inventory_data := inventory.serialize_inventory() # Move this up!
	
	# snap to end of current buffer (add inventory length to resize)
	var cursor := len(buffer.data_array)
	buffer.resize(len(buffer.data_array) + 4 + 2 + len(inventory_data))	
	buffer.seek(cursor)
	
	# variant
	buffer.put_u16(variant)
	
	# inventory size
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
	entity.global_position = TileManager.tile_to_world(tile_pos.x, tile_pos.y)
	
	match tile_variant:
		&'normal':
			entity.variant = ChestVariant.NORMAL
		&'oak':
			entity.variant = ChestVariant.OAK
		&'spruce':
			entity.variant = ChestVariant.SPRUCE
		&'palm':
			entity.variant = ChestVariant.PALM
	
	entity.setup_variant()
	
	EntityManager.store_tile_entity(2, entity)
	
	return

## Returns whether or not the placement is valid. This uses
## [method get_collision_grid] to check for collision and 
## [method get_variant] to make sure the ground beneath is valid.
static func is_placement_valid(tile_pos: Vector2i) -> bool:
	 # make sure bottom tiles are filled
	if TileManager.get_block(tile_pos.x + 0, tile_pos.y + 1) == 0:
		return false
	if TileManager.get_block(tile_pos.x + 1, tile_pos.y + 1) == 0:
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
