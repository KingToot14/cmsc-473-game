class_name TreeEntity
extends TileEntity

# --- Variables --- #
var height := 0
var branch_seed := 0

# --- Functions --- #
func setup_entity() -> void:
	# create deterministic rng
	var rng := RandomNumberGenerator.new()
	branch_seed = data.get(&'branch_seed', 0)
	rng.seed = branch_seed
	
	# create visuals
	var sprite: TileMapLayer = $'visuals/sprite'
	var variant: int = data.get(&'variant', 0)
	
	# trunk
	sprite.set_cell(Vector2i(0, 1), variant, Vector2i(0, 1))
	sprite.set_cell(Vector2i(1, 1), variant, Vector2i(1, 1))
	sprite.set_cell(Vector2i(0, 0), variant, Vector2i(0, 0))
	sprite.set_cell(Vector2i(1, 0), variant, Vector2i(1, 0))
	
	# main body
	height = rng.randi_range(15, 21)
	hp_pool.resize(height)
	
	for i in range(height):
		var hp := EntityHp.new()
		hp.name = "HP_%s" % i
		
		hp.entity = self
		hp.set_max_hp(100)
		
		hp_pool[i] = hp
		hp_pool[i].died.connect(_on_death.bind(i))
		
		add_child(hp)
	
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
		sprite.set_cell(Vector2i(0, -y - 1), variant, Vector2i(2, branch))
		
		# right
		branch = 0
		if y > 0 and y < height - 1 and  rng.randf() < 0.5:
			branch = rng.randi_range(1, 3)
			if branch == last_branch_r or branch == last_branch_l:
				branch = 0
			last_branch_r = branch
		sprite.set_cell(Vector2i(1, -y - 1), variant, Vector2i(3, branch))
	
	# tree top
	var tree_top := $'tree_top'
	
	tree_top.position.y = -(height + 1) * 8.0
	tree_top.show()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&'test_input'):
		return
	
	# only break hovered tree
	if $'hitbox' != Globals.hovered_hitbox:
		return
	
	hp_pool[4].take_damage({
		&'damage': 25,
		&'player_id': multiplayer.get_unique_id()
	})

func _on_death(from_server: bool, pool_id: int) -> void:
	hide()
	
	# server spawns items
	if multiplayer.is_server():
		# calculate number of layers destroyed
		
		var rng := RandomNumberGenerator.new()
		rng.seed = branch_seed
		var base_position := TileManager.world_to_tile(floori(position.x), floori(position.y))
		var positions: Array[Vector2i] = []
		positions.resize(height)
		
		for y in range(height):
			positions[y] = base_position + Vector2i(rng.randi_range(0, 1), -height - 1)
		
		EntityManager.create_entities(
			# item drop
			0,
			positions,
			{ 
				'item_id': 0,
				'quantity': randi_range(1, 2)
			}
		)
	
	if from_server:
		standard_death()
