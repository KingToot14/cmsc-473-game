extends Node2D

# --- Variables --- #
## The width and height of each chunk in tiles
const CHUNK_SIZE := 16
## The area of each chunk in tiles
const CHUNK_AREA := CHUNK_SIZE * CHUNK_SIZE
## The widht and height of each tile in world coordinates
const TILE_SIZE := 8

## A bitmask that isolates the bottom 8 bits
const MASK_EIGHT := (1 << 8) - 1
## A bitmask that isolates the bottom 10 bits
const MASK_TEN := (1 << 10) - 1
## A bitmask that isolates the bottom 20 bits
const MASK_TWENTY := (1 << 20) - 1
## A bitmask that isolates the wall bits
const MASK_WALL  := ((1 << 10) - 1) << 10
## A bitmask that isolates the block bits
const MASK_BLOCK := ((1 << 10) - 1) << 0
## A bitmask that isolates the wall and block bits
const MASK_VISUAL := MASK_BLOCK | MASK_WALL
## a bitmask that isolates the water level
const MASK_WATER := ((1 << 8) - 1) << 20

## A flat-packed representation of the world tiles. Each integer represents
## a single tile in the following format:
## [br] - Bits 00 - 09: Block ID
## [br] - Bits 10 - 19: Wall ID
## [br] - Bits 20 - 31: Unused
var tiles: PackedInt32Array
## The width of the game world in tiles.
## [br]Read from [member Globals.world_size]
var world_width: int
## The height of the game world in tiles.
## [br]Read from [member Globals.world_size]
var world_height: int

## A reference of the water texture for rendering
var water_image: Image

# --- Functions --- #
func _ready() -> void:
	Globals.world_size_changed.connect(_update_world_size)
	_update_world_size(Globals.world_size)

func _update_world_size(size: Vector2i) -> void:
	world_width = size.x
	world_height = size.y

func _idx(x: int, y: int) -> int:
	return x + y * world_width

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&'test_input'):
		var mouse_position := Globals.player.get_global_mouse_position()
		var tile_position := world_to_tile(floori(mouse_position.x), floori(mouse_position.y))
		
		place_water(tile_position.x, tile_position.y)

#region Positions
## Converts local chunk coordinates to global tile coordinates.
## [br][param chunk_x] and [param chunk_y] represent the chunk in the chunk grid,
## while [param x] and [param y] represent the position inside the chunk.
## [br][br][param x] and [param y] should only be values between 0 and 15
func chunk_to_tile(chunk_x: int, chunk_y: int, x: int = 0, y: int = 0) -> Vector2i:
	return Vector2i(chunk_x * CHUNK_SIZE + x, chunk_y * CHUNK_SIZE + y)

## Converts global tile coordinates to a chunk in the chunk grid.
func tile_to_chunk(tile_x: int, tile_y: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(
		clampi(tile_x / CHUNK_SIZE, 0, Globals.world_chunks.x),
		clampi(tile_y / CHUNK_SIZE, 0, Globals.world_chunks.y)
	)

## Converts global tile coordinates to the game's world coordinates.
## [br]Each tile takes up [code]8.0[/code] world pixels
## (Determined by [member TileManager.TILE_SIZE])
## [br][br] If [param center] is [code]true[/code], the resulting position
## is offset by [code]TileManager.TILE_SIZE / 2.0[/code]
func tile_to_world(tile_x: int, tile_y: int, center := false) -> Vector2:
	var offset := 0.0
	if center:
		offset = TILE_SIZE / 2.0
	
	return Vector2(tile_x * TILE_SIZE + offset, tile_y * TILE_SIZE + offset)

## Converts the game's world coordinates to a tile coordinate on the grid.
func world_to_tile(world_x: int, world_y: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(
		clampi(world_x / TILE_SIZE, 0, Globals.world_size.x),
		clampi(world_y / TILE_SIZE, 0, Globals.world_size.y)
	)

## Converts the game's world coordinates to a chunk in the chunk grid.
func world_to_chunk(world_x: int, world_y) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(
		clampi(world_x / (TILE_SIZE * CHUNK_SIZE), 0, Globals.world_chunks.x),
		clampi(world_y / (TILE_SIZE * CHUNK_SIZE), 0, Globals.world_chunks.y)
	)

#endregion

#region Tile Access
## Gets the wall at the given [param x] and [param y] position.
## [br][br]NOTE: This method does not check bounds in order to improve performance.
## Use [method get_wall] if you do not know the bounds of [param x] and [param y]
func get_wall_unsafe(x: int, y: int) -> int:
	# get wall id (10 to 19)
	return (tiles[_idx(x, y)] >> 10) & MASK_TEN

## Gets the wall at the given [param x] and [param y] position.
func get_wall(x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return 0
	
	# get wall id (10 to 19)
	return (tiles[_idx(x, y)] >> 10) & MASK_TEN

## Gets the block at the given [param x] and [param y] position.
## [br][br]NOTE: This method does not check bounds in order to improve performance.
## Use [method get_block] if you do not know the bounds of [param x] and [param y]
func get_block_unsafe(x: int, y: int) -> int:
	# get block id (0 to 9)
	return (tiles[_idx(x, y)] >> 0) & MASK_TEN

## Gets the block at the given [param x] and [param y] position.
func get_block(x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return 0
	
	# get block id (0 to 9)
	return (tiles[_idx(x, y)] >> 0) & MASK_TEN

## Gets the block and wall at the given [param x] and [param y] position.
## [br]This is returned in the bit-packed format, so this should only be used internally
## [br][br]NOTE: This method does not check bounds in order to improve performance.
## Use [method get_wall] if you do not know the bounds of [param x] and [param y]
func get_visual_unsafe(x: int, y: int) -> int:
	# get wall id (10 to 19)
	return (tiles[_idx(x, y)] >> 0) & MASK_TWENTY

## Gets the block and wall at the given [param x] and [param y] position.
## [br]This is returned in the bit-packed format, so this should only be used internally
func get_visual(x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return 0
	
	# get wall id (10 to 19)
	return (tiles[_idx(x, y)] >> 0) & MASK_TWENTY

## Sets the wall at the given [param x] and [param y] position to [param wall_id].
## [br][br]NOTE: This method does not check bounds in order to improve performance.
## Use [method set_wall] if you do not know the bounds of [param x] and [param y]
func set_wall_unsafe(x: int, y: int, wall_id: int) -> void:
	# clear tile id
	var idx = _idx(x, y)
	tiles[idx] &= ~MASK_WALL
	tiles[idx] |= (wall_id << 10)

## Sets the wall at the given [param x] and [param y] position to [param wall_id].
func set_wall(x: int, y: int, wall_id: int) -> void:
	# check bounds
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return
	
	# clear tile id
	var idx = _idx(x, y)
	tiles[idx] &= ~MASK_WALL
	tiles[idx] |= (wall_id << 10)

## Sets the block at the given [param x] and [param y] position to [param block_id].
## [br][br]NOTE: This method does not check bounds in order to improve performance.
## Use [method set_block] if you do not know the bounds of [param x] and [param y]
func set_block_unsafe(x: int, y: int, block_id: int) -> void:
	# clear tile id
	var idx = _idx(x, y)
	tiles[idx] &= ~MASK_BLOCK
	tiles[idx] |= (block_id << 0)

## Sets the block at the given [param x] and [param y] position to [param block_id].
func set_block(x: int, y: int, block_id: int) -> void:
	# check bounds
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return
	
	# clear tile id
	var idx = _idx(x, y)
	tiles[idx] &= ~MASK_BLOCK
	tiles[idx] |= (block_id << 0)

## Returns the [param y]th row of blocks starting at [param start_x],
## ending at [code]start_x + width[/code]. If the row goes out of bounds in
## either direction, uses [param default] instead.
func get_block_row(start_x: int, y: int, width: int, default := 1) -> PackedInt32Array:
	var world_w := world_width
	var world_h := world_height
	
	var row := PackedInt32Array()
	row.resize(width)
	
	# return default row if out of bounds
	if y < 0 or y >= world_h:
		row.fill(default)
		return row
	
	var base_index := y * world_w
	var mask := MASK_TEN
	
	var left := maxi(start_x, 0)
	var right := mini(start_x + width, world_w)
	
	# pad left
	for i in range(0, left - start_x):
		row[i] = default
	
	# fill center
	var index := left - start_x
	for i in range(base_index + left, base_index + right):
		row[index] = (tiles[i] >> 0) & mask
		index += 1
	
	# pad right
	for i in range(index, width):
		row[i] = default
	
	return row

## Returns the [param y]th row of walls starting at [param start_x],
## ending at [code]start_x + width[/code]. If the row goes out of bounds in
## either direction, uses [param default] instead.
func get_wall_row(start_x: int, y: int, width: int, default := 1) -> PackedInt32Array:
	var world_w := world_width
	var world_h := world_height
	
	var row := PackedInt32Array()
	row.resize(width)
	
	# return default row if out of bounds
	if y < 0 or y >= world_h:
		row.fill(default)
		return row
	
	var base_index := y * world_w
	var mask := MASK_TEN
	
	var left := maxi(start_x, 0)
	var right := mini(start_x + width, world_w)
	
	# pad left
	for i in range(0, left - start_x):
		row[i] = default
	
	# fill center
	var index := left - start_x
	for i in range(base_index + left, base_index + right):
		row[index] = (tiles[i] >> 10) & mask
		index += 1
	
	# pad right
	for i in range(index, width):
		row[i] = default
	
	return row

## Returns the [param y]th row of blocks and walls starting at [param start_x],
## ending at [code]start_x + width[/code]. If the row goes out of bounds in
## either direction, uses [param default] instead.
func get_visual_row(start_x: int, y: int, width: int, default := 1) -> PackedInt32Array:
	var world_w := world_width
	var world_h := world_height
	
	var row := PackedInt32Array()
	row.resize(width)
	
	# return default row if out of bounds
	if y < 0 or y >= world_h:
		row.fill(default)
		return row
	
	var base_index := y * world_w
	var mask := MASK_TWENTY
	
	var left := maxi(start_x, 0)
	var right := mini(start_x + width, world_w)
	
	# pad left
	for i in range(0, left - start_x):
		row[i] = default
	
	# fill center
	var index := left - start_x
	for i in range(base_index + left, base_index + right):
		row[index] = tiles[i] & mask
		index += 1
	
	# pad right
	for i in range(index, width):
		row[i] = default
	
	return row

## Checks the 4 cardinal neighbors for [param target]. Returns [code]true[/code]
## if [param target] is found, and [code]false[/code] otherwise.
func has_block_neighbor(x: int, y: int, target: int) -> bool:
	if TileManager.get_block(x - 1, y) == target:
		return true
	if TileManager.get_block(x + 1, y) == target:
		return true
	if TileManager.get_block(x, y - 1) == target:
		return true
	if TileManager.get_block(x, y + 1) == target:
		return true
	
	return false

#endregion

#region Water
## Sets the water level at ([param x], [param y]). [param water_level] should
## be a value between [code]0 - 255[/code].
func set_water_level(x: int, y: int, water_level: int) -> void:
	# check bounds
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return
	
	# clear water level
	var idx = _idx(x, y)
	tiles[idx] &= ~MASK_WATER
	tiles[idx] |= (water_level << 20)

## Gets the water level at the given [param x] and [param y] position.
func get_water_level(x: int, y: int) -> int:
	# check bounds
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return 0
	
	# get water level (20 to 27)
	return (tiles[_idx(x, y)] >> 20) & MASK_EIGHT

## Builds a water texture from [member tiles]. Should only be called
## at the end of world generation, and only once. Use [method update_water_texture]
## to update individual tiles
func build_water_texture() -> void:
	water_image = Image.create_empty(world_width, world_height, false, Image.FORMAT_R8)
	water_image.fill(Color.BLACK)
	
	RenderingServer.global_shader_parameter_set(
		&"water_texture",
		ImageTexture.create_from_image(water_image)
	)

## Updates the water texture at ([param x], [param y]) using [member tiles].
func update_water_texture(x: int, y: int, update := true) -> void:
	if not water_image:
		build_water_texture()
	
	var water_level := ((tiles[_idx(x, y)] >> 20) & MASK_EIGHT) / 255.0
	
	water_image.set_pixel(
		x, y,
		Color(water_level, 0.0, 0.0)
	)
	
	if update:
		push_water_texture_update()

func push_water_texture_update() -> void:
	RenderingServer.global_shader_parameter_set(
		&"water_texture",
		ImageTexture.create_from_image(water_image)
	)

#endregion

#region Safe Interactions
## Attempts to destroy the block at the given [param x] and [param y] position.
## [br][br]Returns [code]true[/code] if the interaction should be consumed. This is
## only [code]false[/code] when there is no block at the given position.
func destroy_block(x: int, y: int) -> bool:
	# check bounds (consume interaction)
	if x < 0 or x >= world_width:
		return true
	if y < 0 or y >= world_height:
		return true
	
	# do not process if no block exists
	if not TileManager.get_block_unsafe(x, y):
		return false
	
	# check for reserved tiles using physics query
	var direct_space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = Vector2(8.0, 8.0)
	query.transform.origin = tile_to_world(x, y, true)
	query.collision_mask = 0b01000000	# Only collides with Tile layer
	
	if not direct_space.intersect_shape(query, 1).is_empty():
		return true
	
	# TODO: Check player's current tool
	
	
	# TODO: Deal gradual damage rather than instantly destroying
	
	# play sfx
	var block_id := TileManager.get_block_unsafe(x, y)
	var block := BlockDatabase.get_block(block_id)
	if block:
		play_sfx(block.break_sfx, x, y, block.break_volume)
	
	# set tile to air
	TileManager.set_block_unsafe(x, y, 0)
	Globals.world_map.update_tile(x, y)
	
	# sync to server
	send_destroy_block.rpc_id(1, x, y)
	
	return true

## Attempts to destroy the wall at the given [param x] and [param y] position.
## [br][br]Returns [code]true[/code] if the interaction should be consumed. This is
## only [code]false[/code] when there is no wall at the given position.
func destroy_wall(x: int, y: int) -> bool:
	# check bounds (consume interaction)
	if x < 0 or x >= world_width:
		return true
	if y < 0 or y >= world_height:
		return true
	
	# do not process if no wall exists
	if not TileManager.get_wall_unsafe(x, y):
		return false
	
	# TODO: Check player's current tool
	
	
	# TODO: Deal gradual damage rather than instantly destroying
	
	# play sfx
	var wall_id := TileManager.get_wall_unsafe(x, y)
	var wall := BlockDatabase.get_wall(wall_id)
	if wall:
		play_sfx(wall.break_sfx, x, y, wall.break_volume)
	
	# set tile to air
	TileManager.set_wall_unsafe(x, y, 0)
	Globals.world_map.update_tile(x, y)
	
	# sync to server
	send_destroy_wall.rpc_id(1, x, y)
	
	return true

## Attempts to place the [member BlockItem.block_id] stored in [param item_id]
## at the given [param x] and [param y] position.
## [br][br]Returns [code]true[/code] if the placement was successful.
func place_block(x: int, y: int, item_id: int) -> bool:
	# check bounds (consume interaction)
	if x < 0 or x >= world_width:
		return false
	if y < 0 or y >= world_height:
		return false
	
	# do not process if block exists
	if TileManager.get_block_unsafe(x, y):
		return false
	
	# make sure item is a BlockItem
	var item: Item = ItemDatabase.get_item(item_id)
	if item is not BlockItem:
		return false
	
	var block_id: int = item.tile_id
	
	# check player's inventory
	if not Globals.player.my_inventory.has_item(item_id):
		return false
	
	# check neighboring tiles
	if not is_block_placement_valid(x, y):
		return false
	
	# query physics
	var direct_space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = Vector2(8.0, 8.0)
	query.transform.origin = tile_to_world(x, y, true)
	query.collision_mask = 0b01001010	# Collides with players, enemies, and tiles
	
	if not direct_space.intersect_shape(query, 1).is_empty():
		return false
	
	# play sfx
	var block := BlockDatabase.get_block(block_id)
	if block:
		play_sfx(block.place_sfx, x, y, block.place_volume)
	
	# set tile to block
	TileManager.set_block_unsafe(x, y, block_id)
	Globals.world_map.update_tile(x, y)
	
	# sync to server
	send_place_block.rpc_id(1, x, y, item_id)
	
	return true

## Attempts to place [param wall_id] at the given [param x] and [param y] position.
## [br][br]Returns [code]true[/code] if the placement was successful.
func place_wall(x: int, y: int, item_id: int) -> bool:
	# check bounds (consume interaction)
	if x < 0 or x >= world_width:
		return false
	if y < 0 or y >= world_height:
		return false
	
	# do not process if block exists
	if TileManager.get_wall_unsafe(x, y):
		return false
	
	# make sure item is a BlockItem
	var item: Item = ItemDatabase.get_item(item_id)
	if item is not BlockItem:
		return false
	
	var wall_id: int = item.tile_id
	
	# check player's inventory
	if not Globals.player.my_inventory.has_item(item_id):
		return false
	
	# check neighboring tiles
	if not is_wall_placement_valid(x, y):
		return false
	
	# play sfx
	var wall := BlockDatabase.get_wall(wall_id)
	if wall:
		play_sfx(wall.place_sfx, x, y, wall.place_volume)
	
	# set tile to wall
	TileManager.set_wall_unsafe(x, y, wall_id)
	Globals.world_map.update_tile(x, y)
	
	# sync to server
	send_place_wall.rpc_id(1, x, y, item_id)
	
	return true

## Determines if the position [param x] and [param y] is valid for placing a block.
## [br] This is [code]true[/code] in two scenarios: 1) A wall is located at [param x]
## and [param y] 2) A block exists in a neighboring cardinal direction.
## [br][br]Returns [code]false[/code] if a block already exists, or if neither of the
## above cases are true.
func is_block_placement_valid(x: int, y: int) -> bool:
	# check self block
	if TileManager.get_block_unsafe(x, y):
		return false
	
	# check self wall
	if TileManager.get_wall_unsafe(x, y):
		return true
	
	# check neighbors
	if TileManager.get_block(x + 1, y):
		return true
	if TileManager.get_block(x - 1, y):
		return true
	if TileManager.get_block(x, y + 1):
		return true
	if TileManager.get_block(x, y - 1):
		return true
	
	return false

## Determines if the position [param x] and [param y] is valid for placing a wall.
## [br] This is [code]true[/code] when there is a block or wall in any cardinal direction
## [br][br]Returns [code]false[/code] if a wall already exists, or if the above
## case is false
func is_wall_placement_valid(x: int, y: int) -> bool:
	# check self block
	if TileManager.get_block_unsafe(x, y):
		return true
	
	# check neighbors (blocks or walls)
	if TileManager.get_visual(x + 1, y):
		return true
	if TileManager.get_visual(x - 1, y):
		return true
	if TileManager.get_visual(x, y + 1):
		return true
	if TileManager.get_visual(x, y - 1):
		return true
	
	return false

func place_water(x: int, y: int) -> bool:
	# check bounds (consume interaction)
	if x < 0 or x >= world_width:
		return false
	if y < 0 or y >= world_height:
		return false
	
	# do not process if block exists
	if get_block_unsafe(x, y):
		return false
	
	# set water level
	set_water_level(x, y, 255)
	update_water_texture(x, y)
	
	# sync to server
	send_place_water.rpc_id(1, x, y)
	
	return true

## Attempts to destroy the block at the given [param x] and [param y] position.
@rpc('any_peer', 'call_remote', 'reliable')
func send_destroy_block(x: int, y: int) -> void:
	# check bounds (consume interaction)
	if x < 0 or x >= world_width:
		return
	if y < 0 or y >= world_height:
		return
	
	# do not process if no block exists
	if not TileManager.get_block_unsafe(x, y):
		return
	
	# check for reserved tiles using physics query
	var direct_space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = Vector2(8.0, 8.0)
	query.transform.origin = tile_to_world(x, y, true)
	query.collision_mask = 0b01000000	# Only collides with Tile layer
	
	if not direct_space.intersect_shape(query, 1).is_empty():
		return
	
	# TODO: Check player's current tool and radius
	
	
	# TODO: Deal gradual damage rather than instantly destroying
	var player_id := multiplayer.get_remote_sender_id()
	
	var block_id = get_block(x, y) #should grab the block id 
	if block_id == 1 or block_id == 2: #if the block is dirt or grass
		if multiplayer.is_server(): 
			var drop_position = tile_to_world(x,y) #grabs position for tile 
			ItemDropEntity.spawn_preferred(drop_position, 3, 1, player_id)
				
	if block_id == 3: #if the block is stone.
		if multiplayer.is_server(): 
			var drop_position = tile_to_world(x,y) #grabs position for tile 
			ItemDropEntity.spawn_preferred(drop_position, 4, 1, player_id)
	
	set_block_unsafe(x, y, 0)
	
	# sync to clients
	send_tile_update(x, y)

## Attempts to destroy the wall at the given [param x] and [param y] position.
@rpc('any_peer', 'call_remote', 'reliable')
func send_destroy_wall(x: int, y: int) -> void:
	# check bounds (consume interaction)
	if x < 0 or x >= world_width:
		return
	if y < 0 or y >= world_height:
		return
	
	# do not process if no wall exists
	if not get_wall_unsafe(x, y):
		return
	
	# TODO: Check player's current tool
	
	
	# TODO: Deal gradual damage rather than instantly destroying
	var wall_id = get_wall(x,y)
	if wall_id == 1: #if the wall is dirt wall
		if multiplayer.is_server(): 
			var drop_position = tile_to_world(x,y) #grabs position for wall 
			ItemDropEntity.spawn(drop_position, 5, 1)
	
	# set tile to air
	set_wall_unsafe(x, y, 0)
	
	# sync to clients
	send_tile_update(x, y)

## Attempts to place [param block_id] at the given [param x] and [param y] position.
@rpc('any_peer', 'call_remote', 'reliable')
func send_place_block(x: int, y: int, item_id: int) -> void:
	# check bounds
	if x < 0 or x >= world_width:
		return
	if y < 0 or y >= world_height:
		return
	
	# do not process if block exists
	if TileManager.get_block_unsafe(x, y):
		return
	
	# make sure item is a BlockItem
	var item: Item = ItemDatabase.get_item(item_id)
	if item is not BlockItem:
		return
	
	var block_id: int = item.tile_id
	
	# check player's inventory
	if not is_instance_valid(ServerManager.connected_players[multiplayer.get_remote_sender_id()]):
		return
	
	var remote_player := ServerManager.connected_players[multiplayer.get_remote_sender_id()]
	if not remote_player.my_inventory.has_item(item_id):
		return
	
	# check neighboring tiles
	if not is_block_placement_valid(x, y):
		return
	
	# query physics
	var direct_space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = Vector2(8.0, 8.0)
	query.transform.origin = tile_to_world(x, y, true)
	query.collision_mask = 0b01001010	# Collides with players, enemies, and tiles
	
	if not direct_space.intersect_shape(query, 1).is_empty():
		return
	
	# set tile to block
	TileManager.set_block_unsafe(x, y, block_id)
	
	# sync to clients
	send_tile_update(x, y)

## Attempts to place [param wall_id] at the given [param x] and [param y] position.
@rpc('any_peer', 'call_remote', 'reliable')
func send_place_wall(x: int, y: int, item_id: int) -> void:
	# check bounds
	if x < 0 or x >= world_width:
		return
	if y < 0 or y >= world_height:
		return
	
	# do not process if block exists
	if TileManager.get_wall_unsafe(x, y):
		return
	
	# make sure item is a BlockItem
	var item: Item = ItemDatabase.get_item(item_id)
	if item is not BlockItem:
		return
	
	var wall_id: int = item.tile_id
	
	# check player's inventory
	if not is_instance_valid(ServerManager.connected_players[multiplayer.get_remote_sender_id()]):
		return
	
	var remote_player := ServerManager.connected_players[multiplayer.get_remote_sender_id()]
	if not remote_player.my_inventory.has_item(item_id):
		return
	
	# check neighboring tiles
	if not is_wall_placement_valid(x, y):
		return
	
	# set tile to wall
	TileManager.set_wall_unsafe(x, y, wall_id)
	
	# sync to clients
	send_tile_update(x, y)

@rpc('any_peer', 'call_remote', 'reliable')
func send_place_water(x: int, y: int) -> void:
	# check bounds
	if x < 0 or x >= world_width:
		return
	if y < 0 or y >= world_height:
		return
	
	# do not process if block exists
	if get_block_unsafe(x, y):
		return
	
	# set water level
	set_water_level(x, y, 255)
	
	# add to update queue
	Globals.water_updater.add_to_queue(Vector2i(x, y))
	
	# sync to clients
	send_tile_update(x, y)

## Receives a tile update from the server. Used for various tile interactions
@rpc('authority', 'call_remote', 'reliable')
func receive_tile_state(x: int, y: int, tile: int) -> void:
	# don't update unchanged tiles
	if TileManager.tiles[_idx(x, y)] == tile:
		return
	
	# update tile info
	TileManager.tiles[_idx(x, y)] = tile
	Globals.world_map.update_tile(x, y)
	
	# update water texture
	update_water_texture(x, y)

func send_tile_update(x: int, y: int) -> void:
	# add neighbors to update queue
	Globals.block_updater.add_to_queue(Vector2i(x, y))
	Globals.block_updater.add_to_queue(Vector2i(x - 1, y))
	Globals.block_updater.add_to_queue(Vector2i(x + 1, y))
	Globals.block_updater.add_to_queue(Vector2i(x, y - 1))
	Globals.block_updater.add_to_queue(Vector2i(x, y + 1))
	
	# update server map
	Globals.server_map.update_tile(x, y)
	
	# sync to clients
	for player in ServerManager.connected_players.keys():
		receive_tile_state.rpc_id(player, x, y, tiles[_idx(x, y)])

#endregion

#region Chunk Access
## Loads the initial tile array to match the world size using
## [member world_width] and [member world_height]
func load_chunks() -> void:
	tiles = []
	tiles.resize(world_width * world_height)

#endregion

#region Sound Effects
func play_sfx(stream: AudioStream, x: int, y: int, volume := 0.0) -> void:
	var player := AudioStreamPlayer2D.new()
	player.global_position = tile_to_world(x, y, true)
	
	player.max_distance = 832
	player.attenuation = 3.0
	
	player.bus = &'Tiles'
	player.stream = stream
	player.volume_db = volume
	
	player.finished.connect(player.queue_free)
	
	add_child(player)
	player.play()

#endregion

#region Multiplayer
## Packs a range of chunks into a ZSTD-compressed binary format for network sending.
## [br]NOTE: This is a wrapper around [method pack_region] to use chunk coordinates
## instead of tile coordinates
func pack_chunks(start_x: int, start_y: int, width: int, height: int) -> PackedByteArray:
	return pack_region(
		start_x * TileManager.CHUNK_SIZE,
		start_y * TileManager.CHUNK_SIZE,
		width   * TileManager.CHUNK_SIZE,
		height  * TileManager.CHUNK_SIZE
	)


## Packs a range of tiles into a ZSTD-compressed binary format for network sending.
func pack_region(start_x: int, start_y: int, width: int, height: int) -> PackedByteArray:
	var packed = PackedByteArray()
	#var offset := 0
	
	for y in range(height):
		var x = start_x + (start_y + y) * world_width
		
		packed.append_array(tiles.slice(x, x + width).to_byte_array())
	
	return packed.compress(FileAccess.COMPRESSION_ZSTD)

## Updates the tiles from [param start_x] and [param start_y] to [code]start_x + width[/code]
## and [code]start_y + height[/code].
## [br]Uses a dirty update system to only update changed regions.
func load_region(data: PackedInt32Array, start_x: int, start_y: int, width: int, height: int) -> void:
	var processed := 0
	
	var dirty_x := start_x + width
	var dirty_y := start_y + height
	var dirty_width := 0
	var dirty_height := 0
	
	for y in range(height):
		for x in range(width):
			var tile := data[x + y * width]
			var idx := (start_x + x) + (start_y + y) * world_width
			
			# only update tiles 
			if tiles[idx] != tile:
				# update tile
				tiles[idx] = tile
				
				# shrink update region
				dirty_x = min(dirty_x, start_x + x)
				dirty_y = min(dirty_y, start_y + y)
				dirty_width = max(dirty_width, start_x + x - dirty_x + 1)
				dirty_height = start_y + y - dirty_y + 1
				
				# set chunk as dirty
				@warning_ignore('integer_division')
				Globals.world_map.chunk_states[Vector2i(
					(start_x + x) / CHUNK_SIZE,
					(start_y + y) / CHUNK_SIZE
				)] = WorldTileMap.UpdateState.DIRTY
				
				# update water texture
				update_water_texture(start_x + x, start_y + y, false)
				
				processed += 1
			
			if processed >= 128:
				processed = 0
				await get_tree().process_frame
	
	# push water update all at once
	push_water_texture_update()
	
	# only change updated tiles
	if dirty_width != 0 and dirty_height != 0:
		Globals.world_map.load_region(dirty_x, dirty_y, dirty_width, dirty_height)

#endregion
