class_name TreeEntity
extends TileEntity

# --- Variables --- #
const APPLE_DROP_ODDS := 1.0

var branch_seed := 0

var height := 0
var curr_height := 0
var variant := 0

# --- Functions --- #
#region Visuals
func setup_entity() -> void:
	# create deterministic rng
	var rng := RandomNumberGenerator.new()
	branch_seed = data.get(&'branch_seed', 0)
	rng.seed = branch_seed
	
	# create visuals
	var sprite: TileMapLayer = $'sprite'
	variant = data.get(&'variant', 0)
	
	sprite.clear()
	
	# trunk
	sprite.set_cell(Vector2i(0, 1), variant, Vector2i(0, 1))
	sprite.set_cell(Vector2i(1, 1), variant, Vector2i(1, 1))
	sprite.set_cell(Vector2i(0, 0), variant, Vector2i(0, 0))
	sprite.set_cell(Vector2i(1, 0), variant, Vector2i(1, 0))
	
	# main body
	height = rng.randi_range(15, 21)
	curr_height = height
	hp_pool.resize(height)
	
	for i in range(height):
		var hp := EntityHp.new()
		hp.name = "HP_%s" % i
		hp.pool_id = i
		
		hp.entity = self
		hp.set_max_hp(100)
		
		hp_pool[i] = hp
		hp_pool[i].died.connect(_on_death.bind(i))
		
		add_child(hp)
		hp_pool[i].setup()
	
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

#endregion

#region Interaction
func break_place(tile_pos: Vector2i) -> bool:
	var layer = abs(tile_pos.y - tile_position.y) - 1
	
	# TODO: Deal damage based on axe/tool
	damage_layer(layer, 25)
	
	# TODO: Only return true if atempting to break with an axe
	return true

#endregion

#region Damage
func damage_layer(layer_id: int, damage: int) -> void:
	var hp := hp_pool[layer_id]
	
	# deal damage to pool
	hp.take_damage({
		&'damage': damage,
		&'player_id': multiplayer.get_unique_id()
	})
	
	# update sprite
	var threshold := hp.get_hp_percent()
	var sprite: TileMapLayer = $'sprite'
	
	if threshold < 0.25:
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

func _on_death(from_server: bool, pool_id: int) -> void:
	# destroy tree when last layer is broken
	if pool_id == 0:
		hide()
		
		if from_server:
			standard_death()
	
	# server spawns items
	if multiplayer and multiplayer.is_server():
		var rng := RandomNumberGenerator.new()
		rng.seed = branch_seed
		
		var base_position = TileManager.world_to_tile(floori(position.x), floori(position.y))
		var apple_positions: Array[Vector2] = []
		var positions: Array[Vector2] = []
		positions.resize(curr_height - pool_id)
		
		# create items for each layer
		for y in range(curr_height - pool_id):
			positions[y] = base_position + Vector2i(rng.randi_range(0, 1), -(y + pool_id + 2))
			# convert from tile position to world position
			positions[y] = TileManager.tile_to_world(
				floori(positions[y].x),
				floori(positions[y].y)
			)
			#consistent with seed
			
			if rng.randf() < APPLE_DROP_ODDS:
				apple_positions.append(base_position + Vector2i(rng.randi_range(0, 1), -(y + pool_id + 2)))
				# convert from tile position to world position
				apple_positions[-1] = TileManager.tile_to_world(
					floori(apple_positions[-1].x),
					floori(apple_positions[-1].y)
				)
				#rng.randi_range(0, 1) determines left or right side of the tree
				#-(y + pool_id + 2)) determines what y value
		
		EntityManager.create_entities(
			# item drop
			0,
			positions,
			{
				&'item_id': 0,
				&'quantity': randi_range(1, 2)
			}
		)
		
		EntityManager.create_entities(
			# item drop
			0, #points to item drop entity
			apple_positions,
			{
				&'item_id': 1, #references apple item id
				&'quantity': 1 #drops 1 apple
			}
		)
	
	curr_height = pool_id
	
	if curr_height > 0:
		resize_tree()

#endregion
