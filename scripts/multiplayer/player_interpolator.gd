class_name PlayerInterpolator
extends SnapshotInterpolator

# --- Enums --- #
## The type of player interaction to queue. Used for action serialization
enum ActionType {
	MOUSE_PRESS
}

# --- Variables --- #
## How many times per second this interpolator should take player snapshots
const SNAPSHOT_RATE := 20.0
## How often this interpolator should send a snapshot (in seconds)
const SNAPSHOT_INTERVAL := 1.0 / SNAPSHOT_RATE

## A timer to store the current time of the snapshot system. Should not be set
## externally.
var snapshot_timer := 0.0

# --- Functions --- #
func _process(delta: float) -> void:
	if not enabled:
		return
	
	if multiplayer.is_server():
		snapshot_timer -= delta
		try_send_snapshots()
	
	# check for other snapshots
	super(delta)

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
			&'velocity': root.velocity
		})

func apply_snapshot(start: Dictionary, end: Dictionary, progression: float) -> void:
	root.global_position = start['position'].lerp(end['position'], progression)
	root.velocity = start['velocity'].lerp(end['velocity'], progression)

func perform_action(action_info: PackedByteArray) -> void:
	var offset := 0
	var action_id: ActionType = action_info.decode_u16(offset) as ActionType
	offset += 2
	
	match action_id:
		ActionType.MOUSE_PRESS:
			var item_id := action_info.decode_u32(offset)
			offset += 4
			
			var mouse_position: Vector2
			mouse_position.x = action_info.decode_float(offset)
			offset += 4
			mouse_position.y = action_info.decode_float(offset)
			offset += 4
			
			var item := ItemDatabase.get_item(item_id)
			
			item.simulate_interact_mouse(root, mouse_position)

## Queues a mouse press interaction into the action queue (see [method queue_action]).
## [br][br]Sends an action to replicate a mouse press input on the given [param item_id]
## at [param mouse_position].
func queue_mouse_press(time: float, item_id: int, mouse_position: Vector2) -> void:
	var buffer := PackedByteArray()
	var offset := 0
	buffer.resize(2 + 4 + (2 * 4))	# uint16 + uint32 + vector2
	
	# action id
	buffer.encode_u16(offset, ActionType.MOUSE_PRESS)
	offset += 2
	
	# item id
	buffer.encode_u32(offset, item_id)
	offset += 4
	
	# mouse_position
	buffer.encode_float(offset, mouse_position.x)
	offset += 4
	buffer.encode_float(offset, mouse_position.y)
	offset += 4
	
	# queue action
	queue_action.rpc_id(Globals.SERVER_ID, time, buffer)
