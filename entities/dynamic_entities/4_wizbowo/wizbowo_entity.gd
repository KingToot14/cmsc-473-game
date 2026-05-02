class_name WizbowoEntity
extends Entity

# --- Variables --- #
@export var float_time := 2.0
@export var float_range := 4.0
var idle_tween: Tween

var origin_pos: Vector2

# --- Functions --- #
func _ready() -> void:
	super()
	
	hp.hp_modified.connect(_on_hp_modified)
	
	if multiplayer.is_server():
		hp.died.connect(_on_death)
		
		do_idle()

func _physics_process(delta: float) -> void:
	pass

func do_idle() -> void:
	idle_tween = create_tween()
	
	var target_pos := origin_pos + Vector2(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
	).normalized() * float_range
	
	idle_tween.tween_property(
		self, ^'global_position', target_pos,
		target_pos.distance_to(origin_pos) / float_range * float_time
	)
	
	await idle_tween.finished
	
	do_idle()

#region Damage
func _on_death() -> void:
	if is_dead:
		return
	
	kill()

func _on_hp_modified(delta: int) -> void:
	if delta >= 0:
		return
	
	# play damage effects
	do_flash()
	$'sfx'.play_sfx(&'hit')

func do_death() -> void:
	if multiplayer.is_server():
		should_free = true
		
		# spawn items
		#ItemDropEntity.spawn(global_position, 2, randi_range(1, 3))
	else:
		$'animator'.play(&'death')

#endregion

#region Multiplayer
func handle_action(action_info: PackedByteArray) -> void:
	super(action_info)
	
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = action_info
	
	var action_id := buffer.get_u16()
	
	# don't process if dead (just playing death animatino)
	if is_dead:
		return
	
	#match action_id:

#endregion

#region Sereialization
func serialize_spawn_data() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = super()
	
	# snap to end of current buffer
	var cursor := len(buffer.data_array)
	buffer.resize(len(buffer.data_array) + 2)	# base + uint16 (2)
	buffer.seek(cursor)
	
	return buffer.data_array

func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	id = buffer.get_u32()
	
	# process base snapshot
	super(buffer)

#endregion

#region Spawning
@warning_ignore("shadowed_variable")
static func spawn(pos: Vector2) -> void:
	# create new item drop entity
	var entity_scene: PackedScene = EntityManager.enemy_registry.get(4).entity_scene
	if not entity_scene:
		return
	
	# check is this entity already exists
	if EntityManager.enemy_count.get(4, 0) > 0:
		return
	
	var entity: WizbowoEntity = entity_scene.instantiate()
	entity.global_position = pos
	entity.origin_pos = pos
	
	# sync to players
	EntityManager.add_entity(4, entity)

#endregion
