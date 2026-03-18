class_name AcornEntity
extends TileEntity

# --- Variables --- #
const GROW_TIME := 0.25
const GROW_ODDS := 1.0 # 0.015
const GROW_STEP := 10
const MAX_GROWTH := 100

var placement_valid := false
var variant := TreeEntity.TreeVariant.FOREST
var branch_seed := 0

var growth_timer := GROW_TIME
var growth := 0

# --- Functions --- #
func _ready() -> void:
	super()
	
	if multiplayer.is_server():
		hp.died.connect(_on_death)

func _process(delta: float) -> void:
	growth_timer -= delta
	
	if growth_timer <= 0.0:
		growth_timer += GROW_TIME
		
		# try to grow
		if randf() < GROW_ODDS:
			growth += GROW_STEP
			
			if growth >= MAX_GROWTH:
				grow_to_tree()

func _on_death() -> void:
	if is_dead:
		return
	
	kill()

#region Growth
## Attempts to delete this entity and spawn a tree in it's place.
## Fails if there's not enough space above the acorn for the tree to grow
func grow_to_tree() -> void:
	# check if space is valid
	if not TreeEntity.is_space_available(tile_position, variant, branch_seed):
		growth -= GROW_STEP
		return
	
	# create tree
	TreeEntity.create(tile_position, variant, branch_seed)
	
	# remove acorn
	kill()
		
	if multiplayer.is_server():
		EntityManager.clear_entity_data(self)

#endregion

#region Interaction
func break_place(_mouse_position: Vector2) -> bool:
	# check held item
	var item_stack := Globals.player.my_inventory.get_selected_item()
	var item := ItemDatabase.get_item(item_stack.item_id)
	
	# make sure item is a tool
	if not item or item is not ToolItem:
		return false
	
	# make sure tool is an axe
	if not item.tool_type & ToolItem.ToolType.PICKAXE:
		return false
	
	# deal damage based on tool power
	hp.take_damage(item.tool_power, DamageSource.DamageSourceType.PLAYER)
	
	return true

#endregion

#region Placement
func setup_variant() -> void:
	match variant:
		TreeEntity.TreeVariant.FOREST:
			print("Forest")
		TreeEntity.TreeVariant.WINTER:
			print("Winter")

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
	
	# branch seed
	buffer.put_u32(branch_seed)
	
	# growth state
	buffer.put_u8(growth)
	
	return buffer.data_array

func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	# process base snapshot
	super(buffer)
	
	# variant
	variant = buffer.get_u16() as TreeEntity.TreeVariant
	
	# branch seed
	branch_seed = buffer.get_u32()
	
	# growth state
	buffer.put_u8(growth)

#endregion

#region Spawning
## Create a new acorn entity at the given [param tile_pos].
## [br][br]This should only be called on the server (use
## [code]AcornEntity.rpc_id(Globals.SERVER_ID, tile_pos)[/code]
## when calling from a client.
@rpc('any_peer', 'call_local', 'reliable')
static func create(tile_pos: Vector2i, _tile_variant := &'') -> void:
	# create new tree entity
	var entity_scene: PackedScene = EntityManager.tile_entity_registry.get(1).entity_scene
	if not entity_scene:
		return
	
	# make sure placement is valid
	if not is_placement_valid(tile_pos):
		return
	
	var entity: AcornEntity = entity_scene.instantiate()
	
	# setup default parameters
	entity.tile_position = tile_pos
	
	entity.branch_seed = randi()
	entity.variant = get_variant(tile_pos) as TreeEntity.TreeVariant
	
	entity.setup_variant()
	
	EntityManager.store_tile_entity(1, entity)
	
	return

## Returns an integer representation of [enum TreeEntity.TreeVariant].
## [br]Returns [code]-1[/code] if no variant is valid (ground is not solid,
## not valid land, or doesn't match neighboring tile)
static func get_variant(tile_pos: Vector2i) -> int:
	var block_bl := TileManager.get_block(tile_pos.x,     tile_pos.y + 1)
	var block_br := TileManager.get_block(tile_pos.x + 1, tile_pos.y + 1)
	
	# check placement blocks
	var curr_variant := 0
	
	match block_bl:
		# dirt or grass
		1, 2:
			curr_variant = TreeEntity.TreeVariant.FOREST
		
		# snow blocks
		6:
			curr_variant = TreeEntity.TreeVariant.WINTER
		# uncatched
		_:
			return -1
	
	match block_br:
		# dirt or grass
		1, 2:
			if curr_variant == TreeEntity.TreeVariant.FOREST:
				return TreeEntity.TreeVariant.FOREST
		
		# snow blocks
		6:
			if curr_variant == TreeEntity.TreeVariant.WINTER:
				return TreeEntity.TreeVariant.WINTER
		# uncatched
		_:
			return -1
	
	return -1

## Returns whether or not the placement is valid. This uses
## [method get_collision_grid] to check for collision and 
## [method get_variant] to make sure the ground beneath is valid.
static func is_placement_valid(tile_pos: Vector2i) -> bool:
	# make sure collision grid is null
	var collision_grid := get_collision_grid(tile_pos)
	
	for pos: Vector2i in collision_grid:
		if collision_grid[pos]:
			return false
	
	# make sure variant is valid
	var curr_variant := get_variant(tile_pos)
	
	return curr_variant != -1

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
