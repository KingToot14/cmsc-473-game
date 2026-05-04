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

	# USE THIS INSTEAD OF query_result!
	if success:
		new_id = db.last_insert_rowid

	# If it failed (e.g. username taken), abort
	if new_id == -1:
		create_account_result.rpc_id(multiplayer.get_remote_sender_id(), -1)
		return

	# Send result back to the client who requested it
	var peer_id = multiplayer.get_remote_sender_id()
	print("[Wizbowo's Conquest] Creating account for player_id:", new_id)
	ServerManager.add_player_info(new_id, peer_id, username)
	
	ServerManager.create_player(peer_id, new_id)
	
	create_account_result.rpc_id(peer_id, new_id)

@rpc("authority", "call_remote", "reliable")
func create_account_result(_player_id: int) -> void:
	Globals.join_ui.set_active_panel("panel_join")

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
	
	# Send result back to the client who requested login
	var peer_id = multiplayer.get_remote_sender_id()
	
	print("[Wizbowo's Conquest] Logging in player_id:", player_id)
	ServerManager.add_player_info(player_id, peer_id, username)
	
	ServerManager.create_player(peer_id, player_id)
	Globals.join_ui.set_active_panel("panel_join")
	
	login_result.rpc_id(peer_id, player_id)

@rpc("authority", "call_remote", "reliable")
func login_result(_player_id: int) -> void:
	# The client overrides this in join_ui.gd
	Globals.join_ui.set_active_panel("panel_join")

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

	# Clear old entries using the built-in delete function to prevent duplicates
	db.delete_rows("inventory", "player_id = " + str(player_id))

	# Save Main Inventory using dictionary inserts
	for item in inventory_data["main_inventory"]:
		var row_data = {
			"player_id": player_id,
			"item_id": item["id"],
			"quantity": item["qty"],
			"slot_index": item["index"],
			"slot_type": "main"
		}
		db.insert_row("inventory", row_data)
		
	# Save Armor Inventory
	for item in inventory_data["armor_inventory"]:
		var row_data = {
			"player_id": player_id,
			"item_id": item["id"],
			"quantity": item["qty"],
			"slot_index": item["index"],
			"slot_type": "armor"
		}
		db.insert_row("inventory", row_data)
		
	# Save Held Item
	if inventory_data["held_item"] != null:
		var h_item = inventory_data["held_item"]
		var row_data = {
			"player_id": player_id,
			"item_id": h_item["id"],
			"quantity": h_item["qty"],
			"slot_index": -1,
			"slot_type": "held"
		}
		db.insert_row("inventory", row_data)

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
	
	# Loop through the query_result array
	for row in db.query_result:
		var s_type = row["slot_type"]
		var item_dict = {
			"index": row["slot_index"],
			"id": row["item_id"],
			"qty": row["quantity"]
		}
		
		if s_type == "main":
			data["main_inventory"].append(item_dict)
		elif s_type == "armor":
			data["armor_inventory"].append(item_dict)
		elif s_type == "held":
			data["held_item"] = item_dict

	return data


#endregion
