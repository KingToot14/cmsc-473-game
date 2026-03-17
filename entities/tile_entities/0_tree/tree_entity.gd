class_name TreeEntity
extends TileEntity

# --- Enums --- #
enum TreeVariant {
	FOREST,
	WINTER
}

# --- Variables --- #
const HP_UPDATE_ACTION := 16

const APPLE_DROP_ODDS := 0.10

var branch_seed := 0

var layer_hp: Array[EntityHp] = []
var height := 0
var curr_height := 0
var variant := TreeVariant.FOREST

var is_setup := false

# --- Functions --- #
#region Visuals
func setup_height() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = branch_seed
	
	height = rng.randi_range(15, 21)

func setup_entity() -> void:
	tile_position = TileManager.world_to_tile(
		floori(global_position.x),
		floori(global_position.y)
	)
	
	# create deterministic rng
	var rng := RandomNumberGenerator.new()
	rng.seed = branch_seed
	
	# create visuals
	var sprite: TileMapLayer = $'sprite'
	
	sprite.clear()
	
	# trunk
	sprite.set_cell(Vector2i(0, 1), variant, Vector2i(0, 1))
	sprite.set_cell(Vector2i(1, 1), variant, Vector2i(1, 1))
	sprite.set_cell(Vector2i(0, 0), variant, Vector2i(0, 0))
	sprite.set_cell(Vector2i(1, 0), variant, Vector2i(1, 0))
	
	# main body
	height = rng.randi_range(15, 21)
	curr_height = height
	layer_hp.resize(height)
	
	for i in range(height):
		var new_hp := EntityPoolHp.new()
		new_hp.pool_id = i
		new_hp.main_hp = hp
		new_hp.name = "HP_%s" % i
		
		new_hp.entity = self
		new_hp.set_max_hp(100)
		
		layer_hp[i] = new_hp
		layer_hp[i].died.connect(_on_layer_death.bind(i))
		
		if multiplayer.is_server():
			layer_hp[i].hp_modified.connect(func (_d): send_hp_update())
		
		hp.hp_pool[i] = new_hp
		add_child(new_hp)
	
	var last_branch_l := 0
	var last_branch_r := 0
	
	for y in range(height):
		# left
		var branch := 0
		if y > 0 and y < height - 1 and  rng.randf() < 0.5:
			branch = rng.randi_range(1, 3)
			if branch == last_branch_l:
				branch = 0
			last_branch_l = branch
		sprite.set_cell(Vector2i(0, -(y + 1)), variant, Vector2i(2, branch))
		
		# right
		branch = 0
		if y > 0 and y < height - 1 and  rng.randf() < 0.5:
			branch = rng.randi_range(1, 3)
			if branch == last_branch_r or branch == last_branch_l:
				branch = 0
			last_branch_r = branch
		sprite.set_cell(Vector2i(1, -(y + 1)), variant, Vector2i(3, branch))
	
	# tree top
	var tree_top := $'tree_top'
	
	tree_top.position.y = -(height + 2) * 8.0
	tree_top.show()
	
	# hitbox
	$'hitbox'.position.y = -(height * 8.0 / 2.0)
	$'hitbox/shape'.shape.size.y = (height * 8.0)

func resize_tree() -> void:
	var sprite: TileMapLayer = $'sprite'
	
	# hide leaves
	$'tree_top'.hide()
	
	# set stump texture
	sprite.set_cell(Vector2i(0, -(curr_height + 1)), variant, Vector2i(0, 2))
	sprite.set_cell(Vector2i(1, -(curr_height + 1)), variant, Vector2i(1, 2))
	
	# clear old trees
	for y in range(curr_height + 1, height):
		sprite.erase_cell(Vector2i(0, -(y + 1)))
		sprite.erase_cell(Vector2i(1, -(y + 1)))
	
	# hitbox
	$'hitbox'.position.y = -(curr_height * 8.0 / 2.0)
	$'hitbox/shape'.shape.size.y = (curr_height * 8.0)

func update_layer_damage(layer_id: int) -> void:
	var threshold := layer_hp[layer_id].get_hp_percent()
	var sprite: TileMapLayer = $'sprite'
	
	if is_equal_approx(threshold, 1.0):
		return
	elif threshold < 0.25:
		sprite.set_cell(Vector2i(0, -(layer_id + 1)), variant, Vector2i(4, 3))
		sprite.set_cell(Vector2i(1, -(layer_id + 1)), variant, Vector2i(5, 3))
	elif threshold < 0.50:
		sprite.set_cell(Vector2i(0, -(layer_id + 1)), variant, Vector2i(4, 2))
		sprite.set_cell(Vector2i(1, -(layer_id + 1)), variant, Vector2i(5, 2))
	elif threshold < 0.75:
		sprite.set_cell(Vector2i(0, -(layer_id + 1)), variant, Vector2i(4, 1))
		sprite.set_cell(Vector2i(1, -(layer_id + 1)), variant, Vector2i(5, 1))
	else:
		sprite.set_cell(Vector2i(0, -(layer_id + 1)), variant, Vector2i(4, 0))
		sprite.set_cell(Vector2i(1, -(layer_id + 1)), variant, Vector2i(5, 0))

#endregion

#region Interaction
func break_place(tile_pos: Vector2i) -> bool:
	var layer = abs(tile_pos.y - tile_position.y) - 1
	
	# only damage layers inside current height
	if layer < 0 or layer > curr_height:
		return true
	
	# TODO: Deal damage based on axe/tool
	damage_layer(layer, 25)
	
	# TODO: Only return true if atempting to break with an axe
	return true

#endregion
## check hovered hitbox


#region Damage
func damage_layer(layer_id: int, dmg: int) -> void:
	var layer := layer_hp[layer_id]
	layer.take_damage(dmg, DamageSource.DamageSourceType.PLAYER)
	
	# update sprite
	update_layer_damage(layer_id)

func _on_layer_death(pool_id: int) -> void:
	# destroy tree when last layer is broken
	if pool_id == 0:
		kill()
		
		if multiplayer.is_server():
			EntityManager.clear_entity_data(self)
	
	# server spawns items
	if multiplayer and multiplayer.is_server():
		var rng := RandomNumberGenerator.new()
		rng.seed = branch_seed
		
		var base_position = TileManager.world_to_tile(floori(position.x), floori(position.y))
		var apple_positions: Array[Vector2] = []
		var apple_data: Array[Dictionary] = []
		
		var positions: Array[Vector2] = []
		var spawn_data: Array[Dictionary] = []
		positions.resize(curr_height - pool_id)
		spawn_data.resize(curr_height - pool_id)
		
		# create items for each layer
		for y in range(curr_height - pool_id):
			positions[y] = base_position + Vector2i(rng.randi_range(0, 1), -(y + pool_id + 2))
			# convert from tile position to world position
			positions[y] = TileManager.tile_to_world(
				floori(positions[y].x),
				floori(positions[y].y)
			)
			spawn_data[y] = {
				&'item_id': 0,
				&'quantity': rng.randi_range(1, 2)
			}
			
			ItemDropEntity.spawn(positions[y], 0, rng.randi_range(1, 2))
			
			#consistent with seed
			
			if rng.randf() < APPLE_DROP_ODDS:
				apple_positions.append(base_position + Vector2i(rng.randi_range(0, 1), -(y + pool_id + 2)))
				# convert from tile position to world position
				apple_positions[-1] = TileManager.tile_to_world(
					floori(apple_positions[-1].x),
					floori(apple_positions[-1].y)
				)
				apple_data.append({
					&'item_id': 1, #references apple item id
					&'quantity': 1 #drops 1 apple
				})
				#rng.randi_range(0, 1) determines left or right side of the tree
				#-(y + pool_id + 2)) determines what y value
		
		
		#EntityManager.create_entities(
			## item drop
			#0,
			#positions,
			#spawn_data
		#)
		#
		#EntityManager.create_entities(
			## item drop
			#0, #points to item drop entity
			#apple_positions,
			#apple_data
		#)
	
	curr_height = pool_id
	
	if curr_height > 0:
		resize_tree()

#endregion

#region Multiplayer
func send_hp_update() -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.resize(2 + height)
	
	# entity id
	buffer.put_u32(id)
	
	# timestamp
	buffer.put_float(NetworkTime.time)
	
	# action id
	buffer.put_u16(HP_UPDATE_ACTION)
	
	# pack hp
	for i in range(height):
		buffer.put_u8(layer_hp[i].curr_hp)
	
	for player_id in interested_players.keys():
		Globals.entity_sync.queue_action.rpc_id(player_id, buffer.data_array)
	
	# update cached data
	EntityManager.update_entity_data(self)

func handle_action(action_info: PackedByteArray) -> void:
	super(action_info)
	
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = action_info
	
	var action_id := buffer.get_u16()
	
	match action_id:
		HP_UPDATE_ACTION:
			for i in range(height):
				# set hp
				layer_hp[i].set_hp(buffer.get_u8())
				if layer_hp[i].curr_hp == 0:
					curr_height = min(curr_height, i)
				
				# update layer sprite
				update_layer_damage(i)
			
			if curr_height != height:
				resize_tree()

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
	
	# height
	buffer.put_u8(height)
	
	# layer hp
	for i in range(height):
		if i >= len(layer_hp):
			buffer.put_u8(100)
		else:
			buffer.put_u8(layer_hp[i].curr_hp)
	
	return buffer.data_array

func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	id = buffer.get_u32()
	
	# process base snapshot
	super(buffer)
	
	# variant
	variant = buffer.get_u16() as TreeVariant
	
	# branch seed
	branch_seed = buffer.get_u32()
	
	# height
	height = buffer.get_u8()
	
	setup_entity()
	
	# layer hp
	for i in range(height):
		layer_hp[i].set_hp(buffer.get_u8())
		
		if layer_hp[i].curr_hp == 0:
			curr_height = min(curr_height, i)
		
		# update layer sprite
		update_layer_damage(i)
	
	if curr_height != height:
		resize_tree()

#endregion

#region Spawning
@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
static func create(position: Vector2i, variant: TreeVariant):
	# create new tree entity
	var entity_scene: PackedScene = EntityManager.tile_entity_registry.get(0).entity_scene
	if not entity_scene:
		return
	
	var entity: TreeEntity = entity_scene.instantiate()
	
	# setup default parameters
	entity.tile_position = position
	entity.global_position = TileManager.tile_to_world(position.x, position.y)
	entity.variant = variant
	
	entity.branch_seed = randi()
	
	entity.setup_height()
	
	EntityManager.store_tile_entity(0, entity)

#endregion
