class_name TileEntity
extends Entity

# --- Variables --- #
var tile_position: Vector2i

## Whether or not to use the standard tile entity damage system. This
## means that whenever this entity receives the [method break_place] call,
## it takes damage and drops an item on death using [method spawn_item].
@export var use_standard_damage := true
## The tool type required to deal damage/break this entity
@export var required_tool := ToolItem.ToolType.PICKAXE

# --- Functions --- #
func _ready() -> void:
	super()
	
	if use_standard_damage and multiplayer.is_server():
		hp.died.connect(_on_death)

func update_preview(tile_pos: Vector2i) -> void:
	tile_position = tile_pos

func attempt_placement() -> bool:
	return false

#region Lifecycle
## Called whenever the [member hp] dies.
func _on_death() -> void:
	if is_dead:
		return
	
	kill()
	
	if multiplayer.is_server():
		# spawn item
		spawn_item()

## Spawns the item that this entity should drop. This should just be the item
## that places down this entity
func spawn_item() -> void:
	return

func break_place(_mouse_position: Vector2) -> bool:
	# check held item
	var item_stack := Globals.player.my_inventory.get_selected_item()
	var item := ItemDatabase.get_item(item_stack.item_id)
	
	# make sure item is a tool
	if not item or item is not ToolItem:
		return false
	
	# make sure tool is an axe
	if not (item.tool_type & required_tool):
		return false
	
	hp.take_damage(item.tool_power, DamageSource.DamageSourceType.PLAYER)
	
	return true

#endregion

#region Serialization
func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	id = buffer.get_u32()
	
	super(buffer)
	
	# set tile position
	tile_position = TileManager.world_to_tile(
		floori(global_position.x),
		floori(global_position.y)
	)

#endregion

#region Helpers
static func query_tile_collision(tile_pos: Vector2i) -> bool:
	# create query
	var direct_space: PhysicsDirectSpaceState2D = \
		Globals.get_tree().current_scene.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = Vector2(8.0, 8.0)
	query.transform.origin = TileManager.tile_to_world(tile_pos.x, tile_pos.y, true)
	query.collision_mask = 0b01000000	# Only collides with Tile layer
	
	# check collision
	return not direct_space.intersect_shape(query, 1).is_empty()

#endregion
