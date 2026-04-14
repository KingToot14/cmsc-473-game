class_name FurnaceEntity
extends TileEntity

# --- Variables --- #
var in_use_by := 0

# --- Functions --- #
func interact_with(mouse_position: Vector2) -> bool:
	if is_dead:
		return false
	
	if not Globals.player.is_point_in_range(mouse_position):
		return false
	
	# Ask the server for permission to lock/open this furnace
	if multiplayer.is_server():
		request_open_furnace()
	else:
		request_open_furnace.rpc_id(Globals.SERVER_ID)
	
	return true

@rpc('any_peer', 'call_remote', 'reliable')
func request_open_furnace() -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: 
		sender_id = 1 
	
	if in_use_by == 0 or in_use_by == sender_id:
		in_use_by = sender_id
		
		if sender_id == 1:
			open_furnace_client()
		else:
			open_furnace_client.rpc_id(sender_id)

@rpc('authority', 'call_remote', 'reliable')
func open_furnace_client() -> void:
	var furnace_ui = Globals.player.get_node_or_null("inventory_ui/furnace_container")
	if furnace_ui:
		furnace_ui.open_furnace(self)

@rpc('any_peer', 'call_remote', 'reliable')
func release_furnace() -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	
	if in_use_by == sender_id:
		in_use_by = 0

func spawn_item() -> void:
	# Drop the furnace item (Item ID 99)
	var drop_pos = global_position + Vector2(8, 8) 
	ItemDropEntity.spawn(drop_pos, 99, 1)
	
	destroy_furnace.rpc()

@rpc('authority', 'call_local', 'reliable')
func destroy_furnace() -> void:
	queue_free()

# --- Spawning and Placement --- #
static func create(tile_pos: Vector2i, tile_variant := &'normal') -> void:
	# Assuming Furnace is Tile Entity ID 8 based on your folder name "8_furnace"
	var entity_scene: PackedScene = EntityManager.tile_entity_registry.get(8).entity_scene
	if not entity_scene:
		return
	
	if not is_placement_valid(tile_pos):
		return
	
	var entity: FurnaceEntity = entity_scene.instantiate()
	entity.tile_position = tile_pos
	entity.global_position = TileManager.tile_to_world(tile_pos.x, tile_pos.y)
	
	EntityManager.store_tile_entity(8, entity)

static func is_placement_valid(tile_pos: Vector2i) -> bool:
	if TileManager.get_block(tile_pos.x + 0, tile_pos.y + 1) == 0:
		return false
	if TileManager.get_block(tile_pos.x + 1, tile_pos.y + 1) == 0:
		return false
	
	var collision_grid := get_collision_grid(tile_pos)
	for pos: Vector2i in collision_grid:
		if collision_grid[pos]:
			return false
			
	return true

static func get_collision_grid(tile_pos: Vector2i) -> Dictionary[Vector2i, bool]:
	var pos_bl := Vector2i(tile_pos.x,     tile_pos.y)
	var pos_br := Vector2i(tile_pos.x + 1, tile_pos.y)
	var pos_tl := Vector2i(tile_pos.x,     tile_pos.y - 1)
	var pos_tr := Vector2i(tile_pos.x + 1, tile_pos.y - 1)
	
	var grid: Dictionary[Vector2i, bool] = {
		pos_bl: false, pos_br: false, pos_tl: false, pos_tr: false
	}
	
	for pos in [pos_bl, pos_br, pos_tl, pos_tr]:
		if TileManager.get_block(pos.x, pos.y) != 0 or query_tile_collision(pos):
			grid[pos] = true
			
	return grid
