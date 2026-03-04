class_name PlayerInterpolator
extends SnapshotInterpolator

# --- Enums --- #
## The type of player interaction to queue. Used for action serialization
enum ActionType {
	MOUSE_PRESS,
	MOUSE_RELEASE,
}

# --- Variables --- #
## How many times per second this interpolator should take player snapshots
const SNAPSHOT_RATE := 30.0
## How often this interpolator should send a snapshot (in seconds)
const SNAPSHOT_INTERVAL := 1.0 / SNAPSHOT_RATE

## A timer to store the current time of the snapshot system. Should not be set
## externally.
var snapshot_timer := 0.0

## The current mouse_position from the server
var mouse_position: Vector2
## The current item being interacted with
var current_item: Item

# --- Functions --- #
func _ready() -> void:
	super()
	
	# connect signal to automatically reset interested players
	ServerManager.players_changed.connect(_on_players_changed)

func _process(delta: float) -> void:
	if not enabled:
		return
	
	if multiplayer.is_server():
		snapshot_timer -= delta
		try_send_snapshots()
	
	# process current item
	if current_item:
		current_item.simulate_process(root, mouse_position)
	
	# check for other snapshots
	super(delta)

func _on_players_changed() -> void:
	interested_players = ServerManager.connected_players.keys()

## Sends a snapshot to other interpolators if [member snapshot_timer] is less
## than or equal to 0.0. This methods sends a snapshot with the [member root]'s
## [member Node2D.global_position] and [member CharacterBody2D.velocity]
func try_send_snapshots() -> void:
	# auto add snapshots
	if snapshot_timer <= 0.0:
		snapshot_timer += SNAPSHOT_INTERVAL
		
		# send update
		queue_snapshot(NetworkTime.time, {
			&'position': root.global_position,
			&'velocity': root.velocity,
			&'mouse_pos': root.get_global_mouse_position()
		})

#region Snapshots Handling
func apply_snapshot(start: Dictionary, end: Dictionary, progression: float) -> void:
	root.global_position = start['position'].lerp(end['position'], progression)
	root.velocity = start['velocity'].lerp(end['velocity'], progression)
	mouse_position = start['mouse_pos'].lerp(end['mouse_pos'], progression)

func perform_action(action_info: PackedByteArray) -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = action_info
	
	var action_id: ActionType = buffer.get_u16() as ActionType
	
	match action_id:
		ActionType.MOUSE_PRESS:
			var item_id := buffer.get_u32()
			
			# get mouse position
			var mouse_pos: Vector2
			mouse_pos.x = buffer.get_float()
			mouse_pos.y = buffer.get_float()
			
			# simulate input
			current_item = ItemDatabase.get_item(item_id)
			current_item.simulate_interact_mouse_press(root, mouse_pos)
		ActionType.MOUSE_RELEASE:
			var item_id := buffer.get_u32()
			
			# get mouse position
			var mouse_pos: Vector2
			mouse_pos.x = buffer.get_float()
			mouse_pos.y = buffer.get_float()
			
			# simulate input
			current_item = ItemDatabase.get_item(item_id)
			current_item.simulate_interact_mouse_release(root, mouse_pos)
			
			# clear item
			current_item = null

#endregion

#region Actions
## Queues a mouse press interaction into the action queue (see [method queue_action]).
## [br][br]Sends an action to replicate a mouse press input on the given [param item_id]
## at [param mouse_position].
func queue_mouse_press(time: float, item_id: int, mouse_pos: Vector2) -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.resize(2 + 4 + (2 * 4))	# uint16 + uint32 + vector2
	
	# action id
	buffer.put_u16(ActionType.MOUSE_PRESS)
	
	# item id
	buffer.put_u32(item_id)
	
	# mouse_pos
	buffer.put_float(mouse_pos.x)
	buffer.put_float(mouse_pos.y)
	
	# queue action
	queue_action.rpc_id(Globals.SERVER_ID, time, buffer.data_array)

func queue_mouse_release(time: float, item_id: int, mouse_pos: Vector2) -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.resize(2 + 4 + (2 * 4))	# uint16 + uint32 + vector2
	
	# action id
	buffer.put_u16(ActionType.MOUSE_RELEASE)
	
	# item id
	buffer.put_u32(item_id)
	
	# mouse_pos
	buffer.put_float(mouse_pos.x)
	buffer.put_float(mouse_pos.y)
	
	# queue action
	queue_action.rpc_id(Globals.SERVER_ID, time, buffer.data_array)

#endregion
