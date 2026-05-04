class_name Inventory
extends Node

# --- Signals --- #
signal inventory_updated

# --- Variables --- #
const INVENTORY_SLOTS := 50

var items: Array[ItemStack] = []
var hotbar_slot := 0
var held_item := ItemStack.new(-1, 0)
var _is_first_load := true
var _can_play_sounds := false
var owner_id := 0
#Crafting Stuff
var recipes: Array[Recipe] = []
var _is_crafting := false

#Armor Stuff
signal armor_updated(slot_index: int) # 0: Head, 1: Body, 2: Legs
var armor_items: Array[ItemStack] = [ItemStack.new(-1, 0), ItemStack.new(-1, 0), ItemStack.new(-1, 0)] # holds head, body, and legs respectively

# --- Functions --- #
func _init():
	for i in range(INVENTORY_SLOTS):
		items.append(ItemStack.new(-1, 0))
	_load_recipes()


func _ready() -> void:
	_can_play_sounds = false
	_is_first_load = true
	
	# Wait longer for the initial server burst AND inventory loading
	await get_tree().create_timer(10.0).timeout
	
	_can_play_sounds = true
	_is_first_load = false  # NOW we're done with the initial load
	print("Inventory warm-up complete. Sounds enabled.")

#region Inventory Management

func add_item(item_id: int, amount: int) -> int:
	if amount <= 0:
		return 0
	
	var item: Item = ItemDatabase.get_item(item_id)
	if not item:
		return amount
	var original_amount = amount 

	# attempt to add to existing stacks
	for stack in items:
		if not stack.is_empty() and stack.item_id == item_id:
			var space = item.max_stack - stack.count
			var adding = min(space, amount)
			stack.count += adding
			amount -= adding
			if amount <= 0: 
				inventory_updated.emit()
				if multiplayer.is_server():
					send_inventory()
				else:
					send_add_item.rpc_id(Globals.SERVER_ID, item_id, original_amount) 
				return 0
	
	# add to first empty stack
	for stack in items:
		if stack.is_empty():
			stack.item_id = item_id
			stack.count = amount
			inventory_updated.emit()
			if multiplayer.is_server():
				send_inventory()
			else:
				send_add_item.rpc_id(Globals.SERVER_ID, item_id, original_amount) 
			return 0
	
	if multiplayer.is_server():
		send_inventory()
	else:
		send_add_item.rpc_id(Globals.SERVER_ID, item_id, original_amount) 
	
	return amount # return leftovers if full

func remove_item(item_id: int, count: int) -> void:
	if count <= 0:
		return
	
	var item: Item = ItemDatabase.get_item(item_id)
	if not item:
		return
		
	var original_count = count
	
	for stack in items:
		if count <= 0:
			break
		
		# if this stack contains the item, remove as much as we can
		if not stack.is_empty() and stack.item_id == item_id:
			var diff = stack.count - count
			stack.count = max(stack.count - count, 0)
			
			if diff <= 0:
				stack.item_id = -1
				count = abs(diff)
			else:
				count = 0
	
	if multiplayer.is_server():
		send_inventory()
	else:
		send_remove_item.rpc_id(Globals.SERVER_ID, item_id, original_count)
	
	inventory_updated.emit()

# Logic to handle picking up/swapping items at a specific slot
func interact_with_slot(index: int) -> void:
	var slot_item = items[index]
	
	# if both are empty, do nothing
	if held_item.is_empty() and slot_item.is_empty():
		return
		
	# pick up (mouse empty, slot full)
	if held_item.is_empty() and not slot_item.is_empty():
		held_item.item_id = slot_item.item_id
		held_item.count = slot_item.count
		
		slot_item.item_id = -1
		slot_item.count = 0
		
	# place (mouse full, slot empty)
	elif not held_item.is_empty() and slot_item.is_empty():
		slot_item.item_id = held_item.item_id
		slot_item.count = held_item.count
		
		held_item.item_id = -1
		held_item.count = 0
		
	# merge (both full, same item ID)
	elif not held_item.is_empty() and not slot_item.is_empty() and held_item.item_id == slot_item.item_id:
		var item_data: Item = ItemDatabase.get_item(slot_item.item_id)
		var max_stack = item_data.max_stack
		var space_left = max_stack - slot_item.count
		# if there is room in the slot, pour items in from the held stack
		if space_left > 0:
			var amount_to_move = min(space_left, held_item.count)
			slot_item.count += amount_to_move
			held_item.count -= amount_to_move
			
			# if we emptied the held stack, clear it
			if held_item.count <= 0:
				held_item.item_id = -1
				held_item.count = 0
				
	# swap (both full, different item IDs)
	elif not held_item.is_empty() and not slot_item.is_empty() and held_item.item_id != slot_item.item_id:
		var temp_id = slot_item.item_id
		var temp_count = slot_item.count
		
		slot_item.item_id = held_item.item_id
		slot_item.count = held_item.count
		
		held_item.item_id = temp_id
		held_item.count = temp_count
	
	# send to server
	if multiplayer.is_server():
		send_inventory()
	else:
		send_mouse_input.rpc_id(Globals.SERVER_ID, index)
	
	# update the UI
	inventory_updated.emit()
	

#armor interaction
func interact_with_armor_slot(index: int) -> void:
	var slot_item = armor_items[index]
	
	if not held_item.is_empty():
		var item_data = ItemDatabase.get_item(held_item.item_id)
		
		if not item_data is ArmorItem:
			return 
			
		if item_data.armor_type != index:
			return 

	# handles place, pickup, and swap
	var temp_id = slot_item.item_id
	var temp_count = slot_item.count
	
	slot_item.item_id = held_item.item_id
	slot_item.count = held_item.count
	
	held_item.item_id = temp_id
	held_item.count = temp_count
	
	if multiplayer.is_server():
		send_inventory()
	else:
		send_armor_input.rpc_id(Globals.SERVER_ID, index)
	
	# Play armor equip sound on the client side
	if not multiplayer.is_server() and _can_play_sounds and not _is_first_load:
		if Globals.music:
			Globals.music.play_armor_equip_sound()
	
	armor_updated.emit(index)
	inventory_updated.emit()
## Drops the currently held item at the specified world position.
## Inside inventory.gd
func drop_held_item(drop_position: Vector2) -> void:
	if held_item.is_empty():
		return

	if multiplayer.is_server():
		var player = ServerManager.connected_players[multiplayer.get_remote_sender_id()]
		
		# get throw direction
		var spawn_behavior := ItemDropEntity.SpawnBehavior.THROW_LEFT
		if drop_position.x > player.center_point.x:
			spawn_behavior = ItemDropEntity.SpawnBehavior.THROW_RIGHT
		
		ItemDropEntity.spawn_restricted(
			player.center_point,
			held_item.item_id,
			held_item.count,
			owner_id,
			1.0,
			spawn_behavior
		)
		held_item.item_id = -1
		held_item.count = 0
		send_inventory()
	else:
		send_drop_item.rpc_id(1, drop_position) 
	
	inventory_updated.emit()

@rpc('any_peer', 'call_remote', 'reliable')
func send_drop_item(drop_position: Vector2) -> void:
	#ensure the drop position is within a reasonable distance of the player
	var player = ServerManager.connected_players[multiplayer.get_remote_sender_id()]
	
	if is_instance_valid(player) and drop_position.distance_to(player.global_position) < 500:
		drop_held_item(drop_position)

func remove_item_at(item_id: int, count: int, slot: int) -> void:
	var item: Item = ItemDatabase.get_item(item_id)
	
	if not item:
		return
	
	var stack := items[slot]
	
	# if this stack contains the item, remove as much as we can
	if not stack.is_empty() and stack.item_id == item_id:
		var diff = stack.count - count
		stack.count = max(stack.count - count, 0)
		
		if diff <= 0:
			stack.item_id = -1
	
	# send to server
	if multiplayer.is_server():
		send_inventory()
	else:
		send_remove_item_at.rpc_id(Globals.SERVER_ID, item_id, count, slot)
	
	inventory_updated.emit()

func load_inventory(db_id: int) -> void:
	if not multiplayer.is_server():
		return

	var data = DatabaseManager.load_inventory(db_id)

	# 1. Clear current inventory to ensure it's empty
	for stack in items:
		stack.item_id = -1
		stack.count = 0
	for stack in armor_items:
		stack.item_id = -1
		stack.count = 0
	held_item.item_id = -1
	held_item.count = 0

	# 2. Check if this is a brand new player (inventory is totally empty)
	if data["main_inventory"].is_empty() and data["armor_inventory"].is_empty() and data["held_item"] == null:
		# Directly assign the starter items to the first 4 slots
		items[0].item_id = 6   # wooden sword
		items[0].count = 1
		items[1].item_id = 7   # wooden pickaxe
		items[1].count = 1
		items[2].item_id = 10  # wooden axe
		items[2].count = 1
		items[3].item_id = 9   # wooden hammer
		items[3].count = 1
	else:
		# 3. Populate Main Inventory from Database
		for item_data in data["main_inventory"]:
			var index = item_data["index"]
			if index >= 0 and index < items.size():
				items[index].item_id = item_data["id"]
				items[index].count = item_data["qty"]

		# 4. Populate Armor Inventory from Database
		if data.has("armor_inventory"):
			for item_data in data["armor_inventory"]:
				var index = item_data["index"]
				if index >= 0 and index < armor_items.size():
					armor_items[index].item_id = item_data["id"]
					armor_items[index].count = item_data["qty"]

		# 5. Populate Held Item from Database
		if data.has("held_item") and data["held_item"] != null:
			held_item.item_id = data["held_item"]["id"]
			held_item.count = data["held_item"]["qty"]

	# 6. Send updated inventory payload to the connected client
	send_inventory()

#func load_inventory() -> void:
	## TODO: fetch inventory from database
	## if database entry not available, setup standard inventory
	#add_item(3, 30)		# dirt blocks
	#add_item(24, 4)		# chests
	#add_item(28, 20)	# torches
	#add_item(89, 30)	# oak platforms
	#add_item(46, 1)		# wooden helmet
	#add_item(48, 1)		# wooden chestplate
	#add_item(47, 1)		# wooden leggings
	#add_item(99, 1)		# furnace
	#
	#add_item(16, 10)	# copper ore
	#
	#add_item(100, 1)	# crafting station
	#
	#add_item(0, 9999)	# oak wood
	#add_item(54, 9999)	# spruce wood
	#add_item(56, 9999)	# palm wood
	#add_item(95, 9999)	# copper bar
	#add_item(96, 9999)	# iron bar
	#add_item(97, 9999)	# silver bar
	#add_item(98, 9999)	# gold bar

#endregion

#region Synchronization
@rpc('any_peer', 'call_remote', 'reliable')
func send_add_item(item_id: int, amount: int) -> void:
	if multiplayer.get_remote_sender_id() != owner_id:
		return
	add_item(item_id, amount)

@rpc('any_peer', 'call_remote', 'reliable')
func send_remove_item(item_id: int, amount: int) -> void:
	if multiplayer.get_remote_sender_id() != owner_id:
		return
	remove_item(item_id, amount)

@rpc('any_peer', 'call_remote', 'reliable')
func send_remove_item_at(item_id: int, amount: int, slot: int) -> void:
	if multiplayer.get_remote_sender_id() != owner_id:
		return
	remove_item_at(item_id, amount, slot)

@rpc('any_peer', 'call_remote', 'reliable')
func send_mouse_input(index: int) -> void:
	if multiplayer.get_remote_sender_id() != owner_id:
		return
	interact_with_slot(index)

func serialize_inventory() -> PackedByteArray:
	# buffer: (int16 for item_id, int16 for quantity) for every slot + held_item + armor_items
	var buffer := StreamPeerBuffer.new()
	# held item (4) + main items (len * 4) + armor items (3 * 4)
	buffer.resize(len(items) * 4 + 4 + len(armor_items) * 4)
	
	# held item
	buffer.put_16(held_item.item_id)
	buffer.put_16(held_item.count)
	
	# main inventory
	for i in range(len(items)):
		buffer.put_16(items[i].item_id)
		buffer.put_16(items[i].count)
		
	# armor inventory
	for i in range(len(armor_items)):
		buffer.put_16(armor_items[i].item_id)
		buffer.put_16(armor_items[i].count)
	
	return buffer.data_array

func send_inventory() -> void:
	if _is_crafting: 
		return #don't send while crafting to avoid overloading network
	receive_inventory.rpc_id(owner_id, serialize_inventory())

@rpc('authority', 'call_remote', 'reliable')
func receive_inventory(inventory_data: PackedByteArray) -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = inventory_data
	
	# Capture old armor state BEFORE reading new data
	var old_armor_ids = []
	for slot in armor_items:
		old_armor_ids.append(slot.item_id)
	
	# Capture old count
	var old_count: int = 0
	for stack in items: 
		old_count += stack.count
	
	# --- SYNC DATA ---
	held_item.item_id = buffer.get_16()
	held_item.count = buffer.get_16()
	
	var new_count: int = 0
	for i in range(len(items)):
		items[i].item_id = buffer.get_16()
		items[i].count = buffer.get_16()
		new_count += items[i].count
	
	# Read armor data and detect changes
	var armor_changed = false
	for i in range(len(armor_items)):
		var new_id = buffer.get_16()
		var new_qty = buffer.get_16()
		
		armor_items[i].item_id = new_id
		armor_items[i].count = new_qty
		
		# Check if this slot changed
		if new_id != old_armor_ids[i]:
			armor_changed = true
			print("[Inventory] Armor slot ", i, " changed from ", old_armor_ids[i], " to ", new_id)

	# --- THE MUZZLE ---
	var audio_is_suppressed = _is_first_load or not _can_play_sounds or Engine.get_frames_drawn() < 30

	# SOUND LOGIC - Play sounds ONLY if not suppressed
	if not multiplayer.is_server() and not audio_is_suppressed:
		if armor_changed:
			print("[Inventory] Playing armor equip sound")
			if Globals.music:
				Globals.music.play_armor_equip_sound()
		elif new_count > old_count:
			if Globals.music:
				Globals.music.play_item_pickup_sound()
	else:
		if audio_is_suppressed:
			print("[Inventory] Sounds suppressed - _is_first_load: ", _is_first_load, " _can_play_sounds: ", _can_play_sounds, " frames: ", Engine.get_frames_drawn())

	# Mark initial load as done (after checking sounds)
	if _is_first_load:
		_is_first_load = false

	_trigger_ui_updates()

func _trigger_ui_updates():
	inventory_updated.emit()
	for i in range(3):
		armor_updated.emit(i)

func _load_recipes() -> void:
	recipes.clear()
	var path = "res://entities/player/recipes"
	var dir = DirAccess.open(path)
	
	if dir:
		var file_names: Array[String] = []
		dir.list_dir_begin()
		var file_name = dir.get_next().trim_suffix(".remap")
		
		# 1. Collect all valid file names first
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				file_names.append(file_name)
			file_name = dir.get_next()
		
		# 2. Sort the array alphabetically so indexes match everywhere!
		file_names.sort()
		
		# 3. Load the resources
		for f in file_names:
			var recipe = load(path + "/" + f) as Recipe
			if recipe:
				recipes.append(recipe)

# requests the server to craft a specific recipe
func request_craft(recipe_index: int) -> void:
	if multiplayer.is_server():
		if recipe_index >= 0 and recipe_index < recipes.size():
			var recipe = recipes[recipe_index]
			if CraftingManager.can_craft(recipe, self):
				_is_crafting = true # Pause networking
				CraftingManager.craft_item(recipe, self) 
				_is_crafting = false # Resume networking
				send_inventory() # Send ONE single final update
	else:
		send_craft_request.rpc_id(Globals.SERVER_ID, recipe_index)


@rpc('any_peer', 'call_remote', 'reliable')
func send_craft_request(recipe_index: int) -> void:
	if multiplayer.get_remote_sender_id() != owner_id:
		return 
		
	request_craft(recipe_index)

#Armor sync
@rpc('any_peer', 'call_remote', 'reliable')
func send_armor_input(index: int) -> void:
	if multiplayer.get_remote_sender_id() != owner_id:
		return 
	interact_with_armor_slot(index)


#endregion

#region Selected Item
func get_selected_item() -> ItemStack:
	# TODO: Check item held by mouse
	if held_item.item_id != -1:
		return held_item
	
	# if no item held in mouse, return current hotbar item
	return items[hotbar_slot]

func has_item(item_id: int, count := 1) -> bool:
	for stack in items:
		# If this stack contains the item, remove as much as we can
		if not stack.is_empty() and stack.item_id == item_id:
			var diff = stack.count - count
			
			if diff < 0:
				count = abs(diff)
			else:
				return true
	
	return false

#endregion

#region Database Saving

func get_save_data() -> Dictionary:
	var data = {
		"main_inventory": [],
		"held_item": null,
		"armor_inventory": []
	}
	
	# include the main inventory items, storing their index so they stay in place
	for i in range(len(items)):
		var stack = items[i]
		if not stack.is_empty():
			data["main_inventory"].append({"index": i, "id": stack.item_id, "qty": stack.count})
	
	if not held_item.is_empty():
		data["held_item"] = {"id": held_item.item_id, "qty": held_item.count}
		
	# include armor items
	for i in range(len(armor_items)):
		var stack = armor_items[i]
		if not stack.is_empty():
			data["armor_inventory"].append({"index": i, "id": stack.item_id, "qty": stack.count})
		
	return data

#endregion Database Saving

#region External Interaction
func interact_with_external_slot(index: int, player_inv: Inventory) -> void:
	var slot_item = items[index]
	var player_held = player_inv.held_item
	
	# if both are empty, do nothing
	if player_held.is_empty() and slot_item.is_empty():
		return
		
	# pick up (mouse empty, slot full)
	if player_held.is_empty() and not slot_item.is_empty():
		player_held.item_id = slot_item.item_id
		player_held.count = slot_item.count
		slot_item.item_id = -1
		slot_item.count = 0
		
	# place (mouse full, slot empty)
	elif not player_held.is_empty() and slot_item.is_empty():
		slot_item.item_id = player_held.item_id
		slot_item.count = player_held.count
		player_held.item_id = -1
		player_held.count = 0
		
	# merge (both full, same item ID)
	elif not player_held.is_empty() and not slot_item.is_empty() and player_held.item_id == slot_item.item_id:
		var item_data: Item = ItemDatabase.get_item(slot_item.item_id)
		var space_left = item_data.max_stack - slot_item.count
		
		if space_left > 0:
			var amount_to_move = min(space_left, player_held.count)
			slot_item.count += amount_to_move
			player_held.count -= amount_to_move
			
			if player_held.count <= 0:
				player_held.item_id = -1
				player_held.count = 0
				
	# swap (both full, different item IDs)
	elif not player_held.is_empty() and not slot_item.is_empty() and player_held.item_id != slot_item.item_id:
		var temp_id = slot_item.item_id
		var temp_count = slot_item.count
		slot_item.item_id = player_held.item_id
		slot_item.count = player_held.count
		player_held.item_id = temp_id
		player_held.count = temp_count
	
	# send to server for syncing
	if multiplayer.is_server():
		send_inventory()
		player_inv.send_inventory()
	else:
		send_external_mouse_input.rpc_id(Globals.SERVER_ID, index, player_inv.owner_id)
	
	# update both UIs
	inventory_updated.emit()
	player_inv.inventory_updated.emit()

@rpc('any_peer', 'call_remote', 'reliable')
func send_external_mouse_input(index: int, player_id: int) -> void:
	var player = ServerManager.connected_players.get(player_id)
	if player:
		interact_with_external_slot(index, player.my_inventory)
#endregion



# --- Classes --- #
class ItemStack:
	var item_id: int = -1
	var count: int = 0 #quantity of a specific stack
	
	func _init(p_item: int = -1, p_count: int = 0):
		item_id = p_item
		count = p_count

	func is_empty() -> bool:
		return item_id < 0 or count <= 0
