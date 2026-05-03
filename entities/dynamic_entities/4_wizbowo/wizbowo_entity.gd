class_name WizbowoEntity
extends Entity

# --- Variables --- #
@export var float_time := 2.0
@export var float_delay := 2.0
@export var float_range := 40.0
var float_tween: Tween
var float_pos: Vector2

@export var idle_time := 0.50
@export var idle_range := 2.0
var idle_tween: Tween
var idle_pos: Vector2

var origin_pos: Vector2

# --- Functions --- #
func _ready() -> void:
	super()
	
	hp.hp_modified.connect(_on_hp_modified)
	
	if multiplayer.is_server():
		hp.died.connect(_on_death)
		
		do_idle()
		do_float()

func _physics_process(_delta: float) -> void:
	global_position = float_pos + idle_pos

func do_idle() -> void:
	idle_tween = create_tween()
	
	var target_pos := Vector2(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
	).normalized() * idle_range
	
	idle_tween.tween_property(
		self, ^'idle_pos', target_pos,
		target_pos.distance_to(idle_pos) / idle_range * idle_time
	)
	
	await idle_tween.finished
	
	do_idle()

func do_float() -> void:
	float_tween = create_tween()
	
	var target_pos := origin_pos + Vector2(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
	).normalized() * float_range
	
	float_tween.tween_property(
		self, ^'float_pos', target_pos,
		target_pos.distance_to(float_pos) / float_range * float_time
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# wait for tween to finish
	await float_tween.finished
	
	# play action
	#spawn_normal_projectiles()
	spawn_homing_projectiles()
	
	# wait for delay
	await get_tree().create_timer(float_delay).timeout
	
	do_float()

#region Attacks
func spawn_normal_projectiles() -> void:
	# get projectile count
	var projectiles := 5
	var iterations := 1
	
	if hp.get_hp_percent() <= 0.25:
		iterations = 3
	elif hp.get_hp_percent() <= 0.50:
		iterations = 2
	
	# get random offset
	var base_angle := randf_range(0, 2 * PI)
	
	for j in range(iterations):
		for i in range(projectiles):
			var angle := base_angle + (1.0 * i / projectiles) * 2 * PI
			
			ProjectileEntity.spawn_wizbowo(global_position, Vector2(cos(angle), sin(angle)))
		
		if j < iterations - 1:
			await get_tree().create_timer(0.10).timeout

func spawn_homing_projectiles() -> void:
	# get projectile count
	var projectiles := len(ServerManager.connected_players)
	var iterations := 1
	
	if hp.get_hp_percent() <= 0.25:
		iterations = 3
	elif hp.get_hp_percent() <= 0.50:
		iterations = 2
	
	# get random offset
	var base_angle := randf_range(0, 2 * PI)
	
	for j in range(iterations):
		var i := 0
		for player_id in ServerManager.connected_players.keys():
			var angle := base_angle + (1.0 * i / projectiles) * 2 * PI
			
			ProjectileEntity.spawn_wizbowo_homing(global_position, Vector2(cos(angle), sin(angle)), player_id)
			
			i += 1
		
		if j < iterations - 1:
			await get_tree().create_timer(0.10).timeout

#endregion

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
		queue_free()
		#$'animator'.play(&'death')

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
	entity.float_pos = pos
	
	# sync to players
	EntityManager.add_entity(4, entity)

#endregion
