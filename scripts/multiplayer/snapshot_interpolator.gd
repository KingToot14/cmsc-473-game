class_name SnapshotInterpolator
extends Node

# --- Variables --- #
## How long the interpolator takes to apply received snapshots in seconds.
## [br][br]Assuming we update 20 times per second, this should be at least 0.10
## in order to have at least 2 snapshots to interpolate between.
const BUFFER_TIME := 0.050

## The entity that this node interpolates. By default, we only update
## [member Node2D.global_position].
@export var root: CharacterBody2D
## If [code]true[/code], the interpolator will automatically start on
## [method Node._ready], otherwise, [member enabled] will have to be manually
## set to true.
@export var auto_start := true
## If [code]true[/code], the [member root] node will be hidden by default and will
## only be visible after there are at least two snapshots present.
## [br]This option is useful for entities that typically spawn on-screen and have
## immediate movement after being created.
@export var hide_on_start := false

## The [PlayerController]'s unique multiplayer id (see [method MultiplayerAPI.get_unique_id]).
## [br]Setting this variable disables the standard and physics processes from running
## on the player that owns this node.
var owner_id := 0:
	set(id):
		if owner_id == multiplayer.get_unique_id():
			set_process(false)
			set_physics_process(false)
		owner_id = id

## A list of snapshots to be interpolated. These typically consists of a timestamp
## and a few values (often [member Node2D.global_position]).
## [br]See [method queue_snapshot].
var snapshots: Array[Dictionary] = []
## A list of queued actions to be played-back alongside the standard snapshot interpolation.
## [br]See [method queue_action].
var queued_actions: Dictionary = {}
## Whether or not this node should be running snapshot interpolation
var enabled := false

# --- Functions --- #
func _ready() -> void:
	await get_tree().process_frame
	
	if auto_start:
		enabled = true
	
	if hide_on_start and not multiplayer.is_server():
		root.hide()

func _process(_delta: float) -> void:
	if not enabled:
		return
	
	interpolate_snapshots()

## Attempts to locate 2 snapshots to interpolate between. This node uses linear
## interpolation (such as[method Vector.lerp]) in order to smooth snapshots from
## the server.
## [br][br]This works by keeping a [code]buffered_time[/code] variable that is equal to
## [member NetworkTime.time] minus [member BUFFER_TIME]. Then, we look for the
## latest snapshot that still sits before this buffered time. Then, we interpolate
## between that snapshot and the next snapshot in the queue.
## [br][br]This method requires 2 snapshots before implementing any actual movement.
## Before that point, the [member root] will appear stationary. If this behavior
## needs to be avoided (such as for entities that spawn on screen), consider setting
## [member hide_on_start] to [code]true[/code].
## [br][br]This method also handles queuing actions to the same [code]buffered_time[/code].
## [br]See [method queue_action].
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
			
			# remove action from queue
			queued_actions.erase(time)
			
			break
	
	# only interpolate with multiple snapshots
	if len(snapshots) < 2:
		return
	
	# re-enable visibility if disabled at start
	if hide_on_start and snapshots[0][&'time'] <= buffered_time and not root.visible:
		hide_on_start = false
		root.show()
	
	# prune old snapshots
	while len(snapshots) > 2:
		# if the second oldest snapshot still contains the buffered time, remove the oldest snapshot
		if snapshots[1][&'time'] <= buffered_time:
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
## Applies the interpolation between [param start] and [param end] ([Dictionary] snapshots).
## [br] Uses [param progression] as the weight for linear interpolation.
func apply_snapshot(start: Dictionary, end: Dictionary, progression: float) -> void:
	root.global_position = start['position'].lerp(end['position'], progression)

## Handles a queued action in [param action_info]. By default this method does nothing
## and should be overridden by classes that extend [SnapshotInterpolator]
@warning_ignore("unused_parameter")
func perform_action(action_info: PackedByteArray) -> void:
	return

#endregion

#region Networking
## Adds [param snapshot] to the end of the queue.
## [br][br][b]NOTE:[/b] This method will only run on the server. use
## [code]queue_snapshot.rpc_id(Globals.SERVER_ID, ...)[/code] when calling from
## a client.
@rpc('any_peer', 'call_remote', 'reliable')
func queue_snapshot(time: float, snapshot: Dictionary) -> void:
	if not (enabled and multiplayer.is_server()):
		return
	
	send_snapshot.rpc(time, snapshot)

## Receives and adds [param snapshot] to the end of the queue and inserts
## the value [code]&'time': time[/code] into [param snapshot]. This is typically
## only called from [method queue_snapshot]
@rpc('authority', 'call_remote', 'reliable')
func send_snapshot(time: float, snapshot: Dictionary) -> void:
	if not enabled or multiplayer.is_server():
		return
	
	snapshot[&'time'] = time
	
	snapshots.append(snapshot)

## Inserts [param action_info] into the action queue at [param time]
## [br][br][b]NOTE:[b] This method will only run on the server. use
## [code]queue_action.rpc_id(Globals.SERVER_ID, ...)[/code] when calling from
## a client.
@rpc('any_peer', 'call_remote', 'reliable')
func queue_action(time: float, action_info: PackedByteArray) -> void:
	if not (enabled and multiplayer.is_server()):
		return
	
	send_action.rpc(time, action_info)

## Receives and inserts [param action_info] into the action queue at [param time].
## This is typically only called from [method queue_action]
@rpc('authority', 'call_remote', 'reliable')
func send_action(time: float, action_info: PackedByteArray) -> void:
	if not enabled or multiplayer.is_server():
		return
	
	# add to queued actions
	queued_actions[time] = action_info

#endregion
