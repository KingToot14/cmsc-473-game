class_name ProjectileEntity
extends Entity

# --- Enums --- #
enum ProjectileType {
	WIZBOWO,
	WIZBOWO_HOMING
}

# --- Variables --- #
@export var projectile_sprites: Dictionary[ProjectileType, Texture2D] = {}
@export var trail_sprites: Dictionary[ProjectileType, Texture2D] = {}

var type: ProjectileType
var direction: Vector2
var size := Vector2(8, 8)
var fly_speed: float

var target_id: int
var homing_speed := 4

# --- Functions --- #
func _ready() -> void:
	super()
	
	hp.hp_modified.connect(_on_hp_modified)
	
	if multiplayer.is_server():
		hp.died.connect(_on_death)
		
		$'damage_source'.dealt_damage.connect(kill)

func _physics_process(delta: float) -> void:
	# if homing, chase target
	if target_id > 0:
		look_at_target(delta)
	
	# move collision
	move_and_slide()
	
	# check for tiles
	if check_block(Vector2(global_position.x - size.x / 2, global_position.y - size.y / 2)):
		return
	if check_block(Vector2(global_position.x + size.x / 2, global_position.y - size.y / 2)):
		return
	if check_block(Vector2(global_position.x - size.x / 2, global_position.y + size.y / 2)):
		return
	if check_block(Vector2(global_position.x + size.x / 2, global_position.y + size.y / 2)):
		return

func look_at_target(delta: float) -> void:
	if not is_instance_valid(ServerManager.connected_players.get(target_id)):
		target_id = 0
		return
	
	var player: PlayerController = ServerManager.connected_players.get(target_id)
	
	var curr_dir := velocity.normalized()
	var target_dir := (player.center_point - global_position).normalized()
	
	var new_dir := curr_dir.lerp(target_dir, delta * homing_speed)
	
	velocity = new_dir.normalized() * fly_speed

func check_block(pos: Vector2) -> bool:
	var tile_pos := TileManager.world_to_tile(floori(pos.x), floori(pos.y))
	
	if BlockDatabase.is_solid[TileManager.get_block(tile_pos.x, tile_pos.y)]:
		kill()
		return true
	
	return false

func setup_type() -> void:
	$'sprite'.texture = projectile_sprites[type]
	$'trail'.texture = trail_sprites[type]
	
	match type:
		ProjectileType.WIZBOWO:
			fly_speed = 200
			velocity = direction
		ProjectileType.WIZBOWO_HOMING:
			fly_speed = 100
			velocity = direction

#region Damage
func _on_death() -> void:
	if is_dead:
		return
	
	kill()

func _on_hp_modified(delta: int) -> void:
	if delta >= 0:
		return
	
	# play damage effects
	$'sfx'.play_sfx(&'hit')

#func do_death() -> void:
	#if multiplayer.is_server():
		#should_free = true
	#else:
		#$'animator'.play(&'death')

#endregion

#region Sereialization
func serialize_spawn_data() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = super()
	
	# snap to end of current buffer
	var cursor := len(buffer.data_array)
	buffer.resize(len(buffer.data_array) + 2)	# base + uint16 (2)
	buffer.seek(cursor)
	
	# type
	buffer.put_u16(type)
	
	return buffer.data_array

func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	id = buffer.get_u32()
	
	# process base snapshot
	super(buffer)
	
	# type
	type = buffer.get_u16() as ProjectileType
	
	setup_type()

#endregion

#region Spawning
@warning_ignore("shadowed_variable")
static func spawn_wizbowo(pos: Vector2, dir: Vector2) -> void:
	# create new item drop entity
	var entity_scene: PackedScene = EntityManager.enemy_registry.get(5).entity_scene
	if not entity_scene:
		return
	
	var entity: ProjectileEntity = entity_scene.instantiate()
	entity.global_position = pos
	entity.direction = dir
	
	entity.type = ProjectileType.WIZBOWO
	
	# start entity logic
	entity.setup_type()
	
	# sync to players
	EntityManager.add_entity(5, entity)

static func spawn_wizbowo_homing(pos: Vector2, dir: Vector2, target: int) -> void:
	# create new item drop entity
	var entity_scene: PackedScene = EntityManager.enemy_registry.get(5).entity_scene
	if not entity_scene:
		return
	
	var entity: ProjectileEntity = entity_scene.instantiate()
	entity.global_position = pos
	entity.direction = dir
	
	entity.type = ProjectileType.WIZBOWO_HOMING
	entity.target_id = target
	
	# start entity logic
	entity.setup_type()
	
	# sync to players
	EntityManager.add_entity(5, entity)

#endregion
