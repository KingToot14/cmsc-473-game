class_name TileEntity
extends Entity

# --- Variables --- #
var tile_position: Vector2i

# --- Functions --- #
func _ready() -> void:
	current_chunk = TileManager.world_to_chunk(floori(position.x), floori(position.y))

#region Interest
func check_interest() -> void:
	# reset interest count
	interest_count = 0
	for player in interested_players:
		if interested_players[player]:
			interest_count += 1
	
	interest_changed.emit(interest_count)
	
	# check if no players are loading TODO: Change this to immedietly free tile entities
	if interest_count == 0:
		lost_all_interest.emit()
		_despawn_timer = despawn_time
		
		# send signal to client entities
		send_action_basic(PAUSE_ACTION)
	else:
		send_action_basic(RESUME_ACTION)

#endregion
