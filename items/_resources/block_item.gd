class_name BlockItem
extends SwingItem

# --- Enums --- #
enum TileType {
	BLOCK,
	WALL,
	TILE
}

# --- Variables --- #
## The tile type this item represents. Changes how [member tile_id] is interpreted:
## [br] - [enum TileType.BLOCK]: [member tile_id] represents [code]block_id[/code]
## [br] - [enum TileType.WALL]: [member tile_id] represents [code]wall_id[/code]
## [br] - [enum TileType.TILE]: [member tile_id] represents [code]tile_entity_id[/code]
@export var tile_type := TileType.BLOCK
## The tile_id that this item points to. Changes based on [member tile_type]
@export var tile_id := 0

# --- Functions --- #
#region Interaction
func handle_process(player: PlayerController, mouse_position: Vector2) -> void:
	# set placement preview
	match tile_type:
		TileType.BLOCK:
			pass
		TileType.WALL:
			pass
		TileType.TILE:
			var entity_info: TileEntityInfo = EntityManager.tile_entity_registry[tile_id]
			
			entity_info.setup_placement_preview(mouse_position)
	
	# only autoswing when enabled
	if not autoswing:
		return
	
	# only autoswing when mouse is held and player is not acting
	if not (mouse_pressed and player.can_act()):
		return
	
	# check range
	if not is_point_in_range(player, mouse_position):
		return
	
	place_block(player, mouse_position)

func handle_interact_mouse_press(player: PlayerController, mouse_position: Vector2) -> void:
	# check range
	if not is_point_in_range(player, mouse_position):
		return
	
	mouse_pressed = true
	player.interpolator.queue_mouse_press(NetworkTime.time, item_id, mouse_position)
	
	place_block(player, mouse_position)

func handle_selected_start() -> void:
	Globals.mouse.placement_preview.show()

func handle_selected_end() -> void:
	Globals.mouse.placement_preview.hide()

#endregion

#region Simulation
func simulate_process(player: PlayerController, mouse_position: Vector2) -> void:
	# only autoswing when enabled
	if not autoswing:
		return
	
	# only autoswing when mouse is held and player is not acting
	if not (mouse_pressed and player.can_act()):
		return
	
	# create dummy object
	var object = preload('res://items/_resources/item_tool.tscn').instantiate()
	object.get_node(^'sprite').texture = texture
	
	if object is ItemToolObject:
		object.set_to_simulate()
	
	do_swing(player, mouse_position, object)

func simulate_interact_mouse_press(player: PlayerController, mouse_position: Vector2) -> void:
	mouse_pressed = true
	
	# create swing object
	var object = preload('res://items/_resources/item_tool.tscn').instantiate()
	object.get_node(^'sprite').texture = texture
	
	if object is ItemToolObject:
		object.set_to_simulate()
	
	do_swing(player, mouse_position, object)

#endregion

func place_block(player: PlayerController, mouse_position: Vector2) -> void:
	# get tile range
	var tile_position: Vector2i = TileManager.world_to_tile(  
		floori(mouse_position.x),
		floori(mouse_position.y)
	)
	
	# create swing object
	var item_object = preload('res://items/_resources/item_tool.tscn').instantiate()
	item_object.get_node(^'sprite').texture = texture
	
	do_swing(player, mouse_position, item_object)
	
	# attempt to place block
	match tile_type:
		TileType.BLOCK:
			if TileManager.place_block(tile_position.x, tile_position.y, item_id):
				# decrement item TODO: check held item first
				var hotbar_slot: int = player.my_inventory.hotbar_slot
				
				player.my_inventory.remove_item_at(item_id, 1, hotbar_slot)
		TileType.WALL:
			if TileManager.place_wall(tile_position.x, tile_position.y, item_id):
				# decrement item TODO: check held item first
				var hotbar_slot: int = player.my_inventory.hotbar_slot
				
				player.my_inventory.remove_item_at(item_id, 1, hotbar_slot)
		TileType.TILE:
			var entity_info: EntityInfo = EntityManager.tile_entity_registry.get(tile_id)
			
			if entity_info and entity_info.entity_script.create(tile_position):
				# decrement item TODO: check held item first
				var hotbar_slot: int = player.my_inventory.hotbar_slot
				
				player.my_inventory.remove_item_at(item_id, 1, hotbar_slot)
