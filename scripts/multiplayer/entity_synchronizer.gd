class_name EntitySynchronizer
extends Node

# --- Variables --- #
const SNAPSHOT_RATE := 20.0
const PHYSICS_TICKS := 30.0
const SNAPSHOT_INTERVAL := 1.0 / SNAPSHOT_RATE

var snapshot_timer := 0.0

# --- Functions --- #
func _ready() -> void:
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
		
		bundles[player_id] = PackedByteArray()
		bundle_counts[player_id] = 0
	
	# gather bundles for all loaded entities
	for entity_id: int in EntityManager.loaded_entities:
		if not (EntityManager.loaded_entities.get(entity_id)):
			continue
		if EntityManager.loaded_entities[entity_id] is not Entity:
			continue
		
		var entity: Entity = EntityManager.loaded_entities[entity_id]
		
		var entity_data := entity.serialize()
		
		for player_id: int in entity.interested_players:
			if not is_instance_valid(ServerManager.connected_players.get(player_id)):
				continue
			
			# add data to bundle
			bundles[player_id].append_array(entity_data)
			bundle_counts[player_id] += 1
	
	# send bundles
	for player_id: int in ServerManager.connected_players:
		if not is_instance_valid(ServerManager.connected_players.get(player_id)):
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
	var offset := 0
	
	# parse header
	var server_time: float = snapshots.decode_float(offset)
	offset += 4
	var entity_count: int = snapshots.decode_u16(offset)
	offset += 2
	
	# parse entity data
	for i in range(entity_count):
		# parse entity id
		var entity_id := snapshots.decode_u32(offset)
		offset += 4
		
		if not is_instance_valid(EntityManager.loaded_entities.get(entity_id)):
			continue
		
		var entity: Entity = EntityManager.loaded_entities.get(entity_id)
		
		offset = entity.deserialize(snapshots, offset, server_time)
