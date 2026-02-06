class_name TreeEntity
extends TileEntity

# --- Variables --- #


# --- Functions --- #
func setup_entity() -> void:
	# setup signals
	hp.died.connect(_on_death)
	
	# create deterministic rng
	var rng := RandomNumberGenerator.new()
	rng.seed = data.get(&'branch_seed', 0)
	
	# create visuals
	var sprite: TileMapLayer = $'sprite'
	var variant: int = data.get(&'variant', 0)
	
	# trunk
	sprite.set_cell(Vector2i(0, 1), variant, Vector2i(0, 1))
	sprite.set_cell(Vector2i(1, 1), variant, Vector2i(1, 1))
	sprite.set_cell(Vector2i(0, 0), variant, Vector2i(0, 0))
	sprite.set_cell(Vector2i(1, 0), variant, Vector2i(1, 0))
	
	# main body
	var height := rng.randi_range(15, 21)
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
	
	hp.take_damage({
		&'damage': 25,
		&'player_id': multiplayer.get_unique_id()
	})

func _on_death(from_server: bool) -> void:
	hide()
	
	# server spawns items
	if multiplayer.is_server():
		EntityManager.create_entity(
			# item drop
			0,
			TileManager.world_to_tile(floori(position.x), floori(position.y)) + Vector2i(0, -10),
			{
				'item': 0,
				'quantity': randi_range(1, 2)
			}
		)
	
	if from_server:
		standard_death()
