class_name EntitySynchronizer
extends Node

# --- Variables --- #
const SNAPSHOT_RATE := 30.0
const SNAPSHOT_INTERVAL := 1.0 / SNAPSHOT_RATE

var snapshot_timer := 0.0

# --- Functions --- #
func _ready() -> void:
	Globals.entity_sync = self
	
	set_process(false)
	ServerManager.server_started.connect(func (): set_process(true))

func _process(delta: float) -> void:
	snapshot_timer -= delta
	if snapshot_timer <= 0.0:
		snapshot_timer += SNAPSHOT_INTERVAL
		send_snapshots()

func send_snapshots() -> void:
	# snapshot snapshots
	var bundles: Dictionary[int, PackedByteArray] = {}
	var bundle_counts: Dictionary[int, int] = {}
	
	for player_id: int in ServerManager.connected_players:
		if not is_instance_valid(ServerManager.connected_players.get(player_id)):
			continue
		
		# don't start syncing entities until player is done loading
		if not ServerManager.is_player_finalized(player_id):
			continue
		
		bundles[player_id] = PackedByteArray()
		bundle_counts[player_id] = 0
	
	# gather bundles for all loaded entities
	for entity_id: int in EntityManager.loaded_entities:
		if not (EntityManager.loaded_entities.get(entity_id)):
			continue
		
		var entity_ref := EntityManager.loaded_entities[entity_id]
		var entity := entity_ref.current_instance
		
		# don't process null entities
		if not is_instance_valid(entity):
			continue
		
		# don't process non-snapshotting entities
		if not entity.always_snapshot:
			continue
		
		var entity_data := entity.serialize()
		
		for player_id: int in entity.interested_players:
			if not is_instance_valid(ServerManager.connected_players.get(player_id)):
				continue
			
			# only process players that are ready for bundles
			if player_id not in bundles:
				continue
			
			# add data to bundle
			bundles[player_id].append_array(entity_data)
			bundle_counts[player_id] += 1
	
	# send bundles
	for player_id: int in ServerManager.connected_players:
		if not is_instance_valid(ServerManager.connected_players.get(player_id)):
			continue
		
		# don't start syncing entities until player is done loading
		if not ServerManager.is_player_finalized(player_id):
			continue
		
		if bundle_counts[player_id] == 0:
			continue
		
		# build bundle
		var entity_data: PackedByteArray = bundles[player_id]
		
		var bundle := PackedByteArray()
		# Header: uint32 (4) time, uint16 (2) entity_count
		bundle.resize(4 + 2)
		
		# add header
		bundle.encode_float(0, NetworkTime.time)
		bundle.encode_u16(4, bundle_counts[player_id])
		
		# add snapshots
		bundle.append_array(entity_data)
		
		receive_snapshots.rpc_id(player_id, bundle)

@rpc('authority', 'call_remote', 'reliable')
func receive_snapshots(snapshots: PackedByteArray) -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = snapshots
	
	# parse header
	var server_time := buffer.get_float()
	var entity_count := buffer.get_u16()
	
	# parse entity data
	for i in range(entity_count):
		# packet size
		var packet_size := buffer.get_u16()
		
		# entity id
		var entity_id := buffer.get_u32() 
		
		# extract packet
		var cursor := buffer.get_position()
		var packet := buffer.data_array.slice(cursor, cursor + packet_size - 6)
		
		buffer.seek(cursor + packet_size - 6)
		
		var entity := EntityManager.get_entity(entity_id)
		
		if not entity:
			continue
		
		var packet_stream := StreamPeerBuffer.new()
		packet_stream.data_array = packet
		
		entity.deserialize(packet_stream, server_time)

#region Actions
@rpc('authority', 'call_remote', 'reliable')
func queue_action(action_info: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = action_info
	
	# entity id
	var entity_id := buffer.get_u32()
	
	# timestamp
	var time := buffer.get_float()
	
	var entity := EntityManager.get_entity(entity_id)
	
	if not entity:
		return
	
	if time < 0.0:
		entity.interpolator.perform_action(action_info.slice(8, len(action_info)))
	else:
		entity.interpolator.send_action(time, action_info.slice(8, len(action_info)))

#endregion
