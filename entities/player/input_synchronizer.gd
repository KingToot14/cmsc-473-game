class_name InputSynchronizer
extends Node2D

# --- Variables --- #
@export var player: PlayerController
@export var input_direction: Vector2
@export var input_jump := false
@export var input_free_cam := false

# --- Functions --- #
func _ready() -> void:
	# disable processing on anything but the owner
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_process_input(false)
		set_physics_process(false)
		set_process_input(false)
		return
	
	NetworkTime.before_tick_loop.connect(_gather)

func _input(event: InputEvent) -> void:
	# calculate global mouse position
	var mouse_position := get_global_mouse_position()
	var tile_position := TileManager.world_to_tile(floori(mouse_position.x), floori(mouse_position.y))
	
	# only used for client-side interaction
	if event.is_action_pressed(&'interact'):
		if Globals.hovered_hitbox and Globals.hovered_hitbox.entity.interact_with(tile_position):
			return
	if event.is_action_pressed(&'break_place'):
		# check hovered hitbox
		if Globals.hovered_hitbox and Globals.hovered_hitbox.entity.break_place(tile_position):
			return
		
		# check blocks TODO: Add simple destroying functionality for testing
		if TileManager.destroy_block(tile_position.x, tile_position.y):
			return
		
		# check walls TODO: See above
		if TileManager.destroy_wall(tile_position.x, tile_position.y):
			return

func _gather() -> void:
	if not is_multiplayer_authority():
		return
	
	input_direction = Vector2(
		Input.get_axis(&'move_left', &'move_right'),
		Input.get_axis(&'move_up', &'move_down')
	)
	
	input_jump = Input.is_action_pressed(&'jump')
	input_free_cam = Input.is_action_pressed(&'free_cam')
