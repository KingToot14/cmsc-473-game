extends Node

var db := SQLite.new()

func _ready():
	if multiplayer.is_server():
		db.path = "user://game.db"
		db.open_db()
		create_tables()

# TABLE CREATION (SERVER ONLY)
func create_tables():
	db.query("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE,
            password_hash TEXT
        );
	""")
	
	db.query("""
        CREATE TABLE IF NOT EXISTS player (
            id INTEGER PRIMARY KEY,
            health INTEGER,
            pos_x REAL,
            pos_y REAL,
            pos_z REAL
        );
	""")
	
	#Create table for inventory
	db.query("""
		CREATE TABLE IF NOT EXISTS inventory (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			player_id INTEGER,
			item_id INTEGER,
			quantity INTEGER,
			slot_index INTEGER,
			slot_type TEXT
		);
	""")
	

# PASSWORD HASHING
func hash_password(password: String) -> String:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(password.to_utf8_buffer())
	return ctx.finish().hex_encode()

# ACCOUNT CREATION (SERVER RPC)
@rpc("any_peer", "call_remote", "reliable")
func create_account(username: String, password: String) -> void:
	if not multiplayer.is_server():
		return

	var hashed = hash_password(password)

	var success = db.query("""
        INSERT INTO users (username, password_hash)
        VALUES ('%s', '%s');
	""" % [username, hashed])

	var new_id := -1
	var results := db.query_result

	if success and len(results) > 0:
		new_id = results[0]['id']
	
	print("[Wizbowo's Conquest] Creating account for player_id:", new_id)

	# Send result back to the client who requested it
	var peer_id = multiplayer.get_remote_sender_id()
	
	ServerManager.create_player(peer_id)
	Globals.join_ui.set_active_panel("panel_join")
	
	create_account_result.rpc_id(peer_id, new_id)

@rpc("authority", "call_remote", "reliable")
func create_account_result(player_id: int) -> void:
	pass

# LOGIN (SERVER RPC)
@rpc("any_peer", "call_remote", "reliable")
func login(username: String, password: String) -> void:
	if not multiplayer.is_server():
		return

	var hashed = hash_password(password)

	db.query("""
        SELECT id FROM users
        WHERE username = '%s' AND password_hash = '%s';
	""" % [username, hashed])

	var player_id := -1
	var results := db.query_result
	
	if len(results) > 0:
		player_id = results[0]['id']
	if player_id == -1:
		create_account(username, password)
		return
	
	print("[Wizbowo's Conquest] Logging in player_id:", player_id)
	
	# Send result back to the client who requested login
	var peer_id = multiplayer.get_remote_sender_id()
	
	ServerManager.create_player(peer_id)
	Globals.join_ui.set_active_panel("panel_join")
	
	login_result.rpc_id(peer_id, player_id)

@rpc("authority", "call_remote", "reliable")
func login_result(player_id: int) -> void:
	# The client overrides this in join_ui.gd
	pass

# REMEMBER PLAYER ID (CLIENT SIDE)
func remember_player_id(player_id: int):
	var cfg = ConfigFile.new()
	cfg.set_value("login", "player_id", player_id)
	cfg.save("user://login.cfg")

func load_remembered_player_id() -> int:
	var cfg = ConfigFile.new()
	if cfg.load("user://login.cfg") == OK:
		return int(cfg.get_value("login", "player_id", -1))
	return -1

# SAVE PLAYER DATA (SERVER ONLY)
func save_player(player_id: int, position: Vector3, health: int):
	if not multiplayer.is_server():
		return

	db.query("""
        INSERT OR REPLACE INTO player (id, health, pos_x, pos_y, pos_z)
        VALUES (%d, %d, %f, %f, %f);
	""" % [player_id, health, position.x, position.y, position.z])

# LOAD PLAYER DATA (SERVER ONLY)
func load_player(player_id: int) -> Dictionary:
	if not multiplayer.is_server():
		return {}

	db.query("SELECT * FROM player WHERE id = %d;" % player_id)

	if db.next_row():
		return {
			"health": db.get_column("health"),
			"pos_x": db.get_column("pos_x"),
			"pos_y": db.get_column("pos_y"),
			"pos_z": db.get_column("pos_z")
		}

	return {}


#region Inventory

# SAVE INVENTORY (SERVER ONLY)
func save_inventory(player_id: int, inventory_data: Dictionary):
	if not multiplayer.is_server():
		return

	# clear old entries for this player to prevent duplicates
	db.query("DELETE FROM inventory WHERE player_id = %d;" % player_id)

	# Save Main Inventory
	for item in inventory_data["main_inventory"]:
		db.query("""
			INSERT INTO inventory (player_id, item_id, quantity, slot_index, slot_type)
			VALUES (%d, %d, %d, %d, 'main');
		""" % [player_id, item["id"], item["qty"], item["index"]])
		
	# Save Armor Inventory
	for item in inventory_data["armor_inventory"]:
		db.query("""
			INSERT INTO inventory (player_id, item_id, quantity, slot_index, slot_type)
			VALUES (%d, %d, %d, %d, 'armor');
		""" % [player_id, item["id"], item["qty"], item["index"]])
		
	# Save Held Item
	if inventory_data["held_item"] != null:
		var h_item = inventory_data["held_item"]
		db.query("""
			INSERT INTO inventory (player_id, item_id, quantity, slot_index, slot_type)
			VALUES (%d, %d, %d, -1, 'held');
		""" % [player_id, h_item["id"], h_item["qty"]])

# LOAD INVENTORY (SERVER ONLY)
func load_inventory(player_id: int) -> Dictionary:
	if not multiplayer.is_server():
		return {}

	db.query("SELECT * FROM inventory WHERE player_id = %d;" % player_id)

	var data = {
		"main_inventory": [],
		"armor_inventory": [],
		"held_item": null
	}
	
	while db.next_row():
		var s_type = db.get_column("slot_type")
		var item_dict = {
			"index": db.get_column("slot_index"),
			"id": db.get_column("item_id"),
			"qty": db.get_column("quantity")
		}
		
		if s_type == "main":
			data["main_inventory"].append(item_dict)
		elif s_type == "armor":
			data["armor_inventory"].append(item_dict)
		elif s_type == "held":
			data["held_item"] = item_dict

	return data


#endregion
