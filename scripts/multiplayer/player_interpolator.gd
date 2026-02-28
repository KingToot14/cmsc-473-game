class_name PlayerInterpolator
extends SnapshotInterpolator

# --- Enums --- #
enum ActionType {
	MOUSE_PRESS
}

# --- Variables --- #
const SNAPSHOT_RATE := 20.0
const PHYSICS_TICKS := 30.0
const SNAPSHOT_INTERVAL := 1.0 / SNAPSHOT_RATE

var snapshot_timer := 0.0

# --- Functions --- #
func _process(delta: float) -> void:
	if not enabled:
		return
	
	snapshot_timer -= delta
	
	# auto add snapshots
	if snapshot_timer <= 0.0:
		snapshot_timer += SNAPSHOT_INTERVAL
		
		# send update
		queue_snapshot(NetworkTime.time, {
			&'position': root.global_position,
			&'velocity': root.velocity
		})
	
	# check for other snapshots
	super(delta)

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
