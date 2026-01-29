class_name SnapshopInterpolator
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

var owner_id := 0:
	set(id):
		if owner_id == multiplayer.get_unique_id():
			set_process(false)
			set_physics_process(false)
		owner_id = id
		
var snapshots := []
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
			send_snapshot.rpc(root.global_position, NetworkTime.tick)
	else:
		interpolate_snapshots()

func interpolate_snapshots() -> void:
	# only run on clients
	if not enabled or is_multiplayer_authority():
		return
	
	# only interpolate with multiple snapshots
	if len(snapshots) < 2:
		return
	
	# delayed tick
	var buffered_tick := NetworkTime.tick - BUFFER_SIZE
	
	# prune old snapshots
	while len(snapshots) > 2:
		# if the second oldest snapshot still contains the buffered tick, remove the oldest snapshot
		if snapshots[1]['tick'] <= buffered_tick:
			snapshots.remove_at(0)
		else:
			break
	
	var snapshot_start = snapshots[0]
	var snapshot_end = snapshots[1]
	var progression = clampf((
		(buffered_tick - snapshot_start['tick']) /
		(snapshot_end['tick'] - snapshot_start['tick'])
	), 0.0, 1.0)
	
	visual_root.global_position = snapshot_start['position'].lerp(snapshot_end['position'], progression)

@rpc('authority', 'call_remote', 'reliable')
func send_snapshot(net_position: Vector2, tick: int) -> void:
	if not enabled:
		return
	
	snapshots.append({
		'position': net_position,
		'tick': tick
	})
	
	if update_root:
		root.global_position = net_position
