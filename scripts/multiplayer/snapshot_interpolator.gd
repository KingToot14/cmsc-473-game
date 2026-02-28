class_name SnapshotInterpolator
extends Node

# --- Variables --- #
const BUFFER_TIME := 0.15

@export var root: CharacterBody2D
@export var auto_start := true

var owner_id := 0:
	set(id):
		if owner_id == multiplayer.get_unique_id():
			set_process(false)
			set_physics_process(false)
		owner_id = id
		
var snapshots: Array[Dictionary] = []
var queued_actions: Dictionary = {}
var enabled := false

# --- Functions --- #
func _ready() -> void:
	await get_tree().process_frame
	
	if auto_start:
		enabled = true

func _process(_delta: float) -> void:
	# only run on server
	if not enabled:
		return
	
	interpolate_snapshots()

func interpolate_snapshots() -> void:
	# only run on clients
	if not enabled or is_multiplayer_authority():
		return
	
	# delayed time
	var buffered_time := NetworkTime.time - BUFFER_TIME
	
	# check for actions
	var actions: Array = queued_actions.keys()
	actions.sort()
	
	for time in actions:
		if buffered_time >= time:
			perform_action(queued_actions[time])
			#var item_id = action[&'item_id']
			#var action_type = action[&'action_type']
			#
			## apply action
			#match action_type:
				#&'interact_mouse':
					#var item := ItemDatabase.get_item(item_id)
					#
					#item.simulate_interact_mouse(root, action[&'mouse_position'])
			#
			## remove action from queue
			queued_actions.erase(time)
			
			break
	
	# only interpolate with multiple snapshots
	if len(snapshots) < 2:
		return
	
	# prune old snapshots
	while len(snapshots) > 2:
		# if the second oldest snapshot still contains the buffered time, remove the oldest snapshot
		if snapshots[1]['time'] <= buffered_time:
			snapshots.remove_at(0)
		else:
			break
	
	# interpolate position and velocity to match server
	var snapshot_start = snapshots[0]
	var snapshot_end = snapshots[1]
	var progression = clampf((
		float(buffered_time - snapshot_start['time']) /
		float(snapshot_end['time'] - snapshot_start['time'])
	), -0.0, 1.0)
	
	apply_snapshot(snapshot_start, snapshot_end, progression)

#region Applying Snapshots
func apply_snapshot(start: Dictionary, end: Dictionary, progression: float) -> void:
	root.global_position = start['position'].lerp(end['position'], progression)

func perform_action(_action_info: PackedByteArray) -> void:
	return

#endregion

#region Networking
@rpc('any_peer', 'call_remote', 'reliable')
func queue_snapshot(time: float, snapshot: Dictionary) -> void:
	if not (enabled and multiplayer.is_server()):
		return
	
	send_snapshot.rpc(time, snapshot)

@rpc('authority', 'call_remote', 'reliable')
func send_snapshot(time: float, snapshot: Dictionary) -> void:
	if not enabled or multiplayer.is_server():
		return
	
	snapshot[&'time'] = time
	
	snapshots.append(snapshot)

@rpc('any_peer', 'call_remote', 'reliable')
func queue_action(time: float, action_info: PackedByteArray) -> void:
	if not (enabled and multiplayer.is_server()):
		return
	
	send_action.rpc(time, action_info)

@rpc('authority', 'call_remote', 'reliable')
func send_action(time: float, action_info: PackedByteArray) -> void:
	if not enabled or multiplayer.is_server():
		return
	
	# add to queued actions
	queued_actions[time] = action_info

#endregion
