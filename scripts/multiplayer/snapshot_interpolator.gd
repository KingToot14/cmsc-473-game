class_name SnapshotInterpolator
extends Node

# --- Variables --- #
const SNAPSHOT_RATE := 20.0
const PHYSICS_TICKS := 30.0
const SNAPSHOT_INTERVAL := roundi(PHYSICS_TICKS / SNAPSHOT_RATE)
const BUFFER_SEC := 0.10
const BUFFER_SIZE := PHYSICS_TICKS * BUFFER_SEC

@export var root: Node2D
@export var visual_root: Node2D
@export var update_root := true
@export var auto_start := true

@export var update_all := false
var interested_players: Array[int] = []

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

func _physics_process(_delta: float) -> void:
	# only run on server
	if not enabled:
		return
	
	if is_multiplayer_authority():
		if NetworkTime.tick % SNAPSHOT_INTERVAL == 0:
			# send snapshot
			if update_all:
				interested_players = ServerManager.connected_players.keys()
			
			for player_id in interested_players:
				send_snapshot.rpc_id(player_id, root.global_position, root.velocity, NetworkTime.tick)
	else:
		interpolate_snapshots()

func interpolate_snapshots() -> void:
	# only run on clients
	if not enabled or is_multiplayer_authority():
		return
	
	# delayed tick
	var buffered_tick := NetworkTime.tick - BUFFER_SIZE
	
	# check for actions
	var actions: Array = queued_actions.keys()
	actions.sort()
	
	for tick in actions:
		if buffered_tick >= tick:
			var action = queued_actions[tick]
			var item_id = action[&'item_id']
			var action_type = action[&'action_type']
			
			# apply action
			match action_type:
				&'interact_mouse':
					var item := ItemDatabase.get_item(item_id)
					
					item.simulate_interact_mouse(root, action[&'mouse_position'])
			
			# remove action from queue
			queued_actions.erase(tick)
			break
	
	# only interpolate with multiple snapshots
	if len(snapshots) < 2:
		return
	
	# prune old snapshots
	while len(snapshots) > 2:
		# if the second oldest snapshot still contains the buffered tick, remove the oldest snapshot
		if snapshots[1]['tick'] <= buffered_tick:
			snapshots.remove_at(0)
		else:
			break
	
	# interpolate position and velocity to match server
	var snapshot_start = snapshots[0]
	var snapshot_end = snapshots[1]
	var progression = clampf((
		(buffered_tick - snapshot_start['tick']) /
		(snapshot_end['tick'] - snapshot_start['tick'])
	), 0.0, 1.0)
	
	visual_root.global_position = snapshot_start['position'].lerp(snapshot_end['position'], progression)
	visual_root.velocity = snapshot_start['velocity'].lerp(snapshot_end['velocity'], progression)

@rpc('authority', 'call_remote', 'reliable')
func send_snapshot(net_position: Vector2, net_velocity: Vector2, tick: int) -> void:
	if not enabled:
		return
	
	snapshots.append({
		'position': net_position,
		'velocity': net_velocity,
		'tick': tick
	})
	
	if update_root:
		root.global_position = net_position
		root.velocity = net_velocity

@rpc('any_peer', 'call_remote', 'reliable')
func queue_action(action_info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	
	send_action.rpc(action_info)

@rpc('any_peer', 'call_remote', 'reliable')
func send_action(action_info: Dictionary) -> void:
	if multiplayer.is_server():
		return
	
	# add to queued actions
	queued_actions[action_info[&'tick']] = action_info
