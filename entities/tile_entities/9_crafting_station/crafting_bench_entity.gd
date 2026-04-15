class_name CraftingBenchEntity
extends TileEntity

# --- Enums --- #
enum CraftingVariant {
	OAK,
	SPRUCE,
	PALM
}

# --- Variables --- #
var variant := CraftingVariant.OAK
var in_use_by := 0

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
	
	# Ask the server for permission to lock/open this bench
	if multiplayer.is_server():
		request_open_bench()
	else:
		request_open_bench.rpc_id(Globals.SERVER_ID)
	
	return true

@rpc('any_peer', 'call_remote', 'reliable')
func request_open_bench() -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: 
		sender_id = 1 
	
	if in_use_by == 0 or in_use_by == sender_id:
		in_use_by = sender_id
		
		if sender_id == 1:
			open_bench_client()
		else:
			open_bench_client.rpc_id(sender_id)

@rpc('authority', 'call_remote', 'reliable')
func open_bench_client() -> void:
	var bench_ui = Globals.player.get_node_or_null("inventory_ui/crafting_bench_container")
	if bench_ui:
		bench_ui.open_crafting_bench(self)

@rpc('any_peer', 'call_remote', 'reliable')
func release_bench() -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	
	if in_use_by == sender_id:
		in_use_by = 0

func spawn_item() -> void:
	# Drop the crafting bench item (Item ID 100)
	var drop_pos = global_position + Vector2(8, 8) 
	ItemDropEntity.spawn(drop_pos, 100, 1)
	
	destroy_bench.rpc()

@rpc('authority', 'call_local', 'reliable')
func destroy_bench() -> void:
	queue_free()

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
	var entity_scene: PackedScene = EntityManager.tile_entity_registry.get(9).entity_scene
	if not entity_scene:
		return
	
	# make sure placement is valid
	if not is_placement_valid(tile_pos):
		return
	
	var entity: CraftingBenchEntity = entity_scene.instantiate()
	
	# setup default parameters
	entity.tile_position = tile_pos
	entity.global_position = TileManager.tile_to_world(tile_pos.x, tile_pos.y)
	
	match tile_variant:
		&'oak', &'normal':
			entity.variant = CraftingVariant.OAK
		&'spruce':
			entity.variant = CraftingVariant.SPRUCE
		&'palm':
			entity.variant = CraftingVariant.PALM
	
	entity.setup_variant()
	
	EntityManager.store_tile_entity(9, entity)
	return

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
