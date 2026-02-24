extends Node

var db := SQLite.new()

func _ready():
	db.open("user://game.db")
	create_tables()

# TABLE CREATION
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

	db.query("""
        CREATE TABLE IF NOT EXISTS inventory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id INTEGER,
            item_name TEXT,
            quantity INTEGER
        );
	""")

# PASSWORD HASHING
func hash_password(password: String) -> String:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(password.to_utf8_buffer())
	return ctx.finish().hex_encode()

# ACCOUNT CREATION
func create_account(username: String, password: String) -> bool:
	var hashed = hash_password(password)
	return db.query("""
        INSERT INTO users (username, password_hash)
        VALUES ('%s', '%s');
	""" % [username, hashed])

# LOGIN
func login(username: String, password: String) -> int:
	var hashed = hash_password(password)

	db.query("""
        SELECT id FROM users
        WHERE username = '%s' AND password_hash = '%s';
	""" % [username, hashed])

	if db.next_row():
		return db.get_column("id")

	return -1

# REMEMBER PLAYER ID
func remember_player_id(player_id: int):
	var cfg = ConfigFile.new()
	cfg.set_value("login", "player_id", player_id)
	cfg.save("user://login.cfg")

func load_remembered_player_id() -> int:
	var cfg = ConfigFile.new()
	if cfg.load("user://login.cfg") == OK:
		return int(cfg.get_value("login", "player_id", -1))
	return -1

# SAVE PLAYER DATA
func save_player(player_id: int, position: Vector3, health: int):
	db.query("""
        INSERT OR REPLACE INTO player (id, health, pos_x, pos_y, pos_z)
        VALUES (%d, %d, %f, %f, %f);
	""" % [player_id, health, position.x, position.y, position.z])

# LOAD PLAYER DATA
func load_player(player_id: int) -> Dictionary:
	db.query("SELECT * FROM player WHERE id = %d;" % player_id)

	if db.next_row():
		return {
			"health": db.get_column("health"),
			"pos_x": db.get_column("pos_x"),
			"pos_y": db.get_column("pos_y"),
			"pos_z": db.get_column("pos_z")
		}

	return {}

# SAVE INVENTORY
func save_inventory(player_id: int, items: Array):
	db.query("DELETE FROM inventory WHERE player_id = %d;" % player_id)

	for item in items:
		db.query("""
            INSERT INTO inventory (player_id, item_name, quantity)
            VALUES (%d, '%s', %d);
		""" % [player_id, item["name"], item["qty"]])

# LOAD INVENTORY 
func load_inventory(player_id: int) -> Array:
	db.query("SELECT * FROM inventory WHERE player_id = %d;" % player_id)

	var items = []
	while db.next_row():
		items.append({
			"name": db.get_column("item_name"),
			"qty": db.get_column("quantity")
		})

	return items
