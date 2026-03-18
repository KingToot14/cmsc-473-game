class_name AcornEntity
extends TileEntity

# --- Variables --- #
const GROW_ODDS := 0.0015
const GROW_STEP := 10
const MAX_GROWTH := 100

var placement_valid := false
var variant := TreeEntity.TreeVariant.FOREST
var branch_seed := 0

var growth := 0

# --- Functions --- #
#region Growth
func get_height() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = branch_seed
	
	return rng.randi_range(15, 21)

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
	id = buffer.get_u32()
	
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
@rpc('any_peer', 'call_local', 'reliable')
static func create(tile_pos: Vector2i) -> bool:
	# create new tree entity
	var entity_scene: PackedScene = EntityManager.tile_entity_registry.get(1).entity_scene
	if not entity_scene:
		return false
	
	# make sure placement is valid
	if not is_placement_valid(tile_pos):
		return false
	
	var entity: AcornEntity = entity_scene.instantiate()
	
	# setup default parameters
	entity.tile_position = tile_pos
	
	entity.branch_seed = randi()
	entity.variant = get_variant(tile_pos) as TreeEntity.TreeVariant
	
	entity.setup_variant()
	
	EntityManager.store_tile_entity(1, entity)
	
	return true

static func get_variant(tile_pos: Vector2i) -> int:
	var block_bl := TileManager.get_block(tile_pos.x,     tile_pos.y + 1)
	var block_br := TileManager.get_block(tile_pos.x + 1, tile_pos.y + 1)
	
	# check placement blocks
	var curr_variant := 0
	
	match block_bl:
		# air
		0:
			return -1
		# dirt or grass
		1, 2:
			curr_variant = TreeEntity.TreeVariant.FOREST
		
		# snow blocks
		6:
			curr_variant = TreeEntity.TreeVariant.WINTER
	
	match block_br:
		# air
		0:
			return -1
		# dirt or grass
		1, 2:
			if curr_variant == TreeEntity.TreeVariant.FOREST:
				return TreeEntity.TreeVariant.FOREST
		
		# snow blocks
		6:
			if curr_variant == TreeEntity.TreeVariant.WINTER:
				return TreeEntity.TreeVariant.WINTER
	
	return -1

static func is_placement_valid(tile_pos: Vector2i) -> bool:
	var block_bl := TileManager.get_block(tile_pos.x,     tile_pos.y)
	var block_br := TileManager.get_block(tile_pos.x + 1, tile_pos.y)
	var block_tl := TileManager.get_block(tile_pos.x,     tile_pos.y - 1)
	var block_tr := TileManager.get_block(tile_pos.x + 1, tile_pos.y - 1)
	
	# can only be placed in a clear 2x2 area
	if block_bl != 0 or block_br != 0 or block_tl != 0 or block_tr != 0:
		return false
	
	# make sure variant is valid
	var curr_variant := get_variant(tile_pos)
	
	return curr_variant != -1

#endregion
