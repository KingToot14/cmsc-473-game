extends Node

var db := SQLite.new()

func _ready():
	# Use user:// so the game can write to it
	db.open("user://game.db")
	create_tables()
func create_tables():
	db.query("""
        CREATE TABLE IF NOT EXISTS player (
            id INTEGER PRIMARY KEY,
            health INTEGER,
            pos_x REAL,
            pos_y REAL,
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
func save_player(player_id, position, health):
	db.query("""
        INSERT OR REPLACE INTO player (id, health, pos_x, pos_y)
        VALUES (%d, %d, %f, %f, %f);
	""" % [player_id, health, position.x, position.y, position.z])
func save_inventory(player_id, inventory):
	db.query("DELETE FROM inventory WHERE player_id = %d;" % player_id)

	for item in inventory:
		db.query("""
            INSERT INTO inventory (player_id, item_name, quantity)
            VALUES (%d, '%s', %d);
		""" % [player_id, item["name"], item["qty"]])
func load_player(player_id):
	db.query("SELECT * FROM player WHERE id = %d;" % player_id)

	if db.next_row():
		return {
			"health": db.get_column("health"),
			"pos_x": db.get_column("pos_x"),
			"pos_y": db.get_column("pos_y"),
		}

	return null
func load_inventory(player_id):
	db.query("SELECT * FROM inventory WHERE player_id = %d;" % player_id)

	var items = []
	while db.next_row():
		items.append({
			"name": db.get_column("item_name"),
			"qty": db.get_column("quantity")
		})

	return items
