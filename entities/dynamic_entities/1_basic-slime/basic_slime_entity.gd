class_name BasicSlimeEntity
extends Entity

# --- Enums --- #
enum SlimeVariant {
	GREEN, BLUE, RED, PURPLE,
	CLOUD, STONE, TUNNEL
}

# --- Variables --- #
const JUMP_ACTION := 16
const LAND_ACTION := 17

const JUMP_POWER_TINY := 0.35
const JUMP_POWER_SMALL := 0.50
const JUMP_POWER_LARGE := 1.50
const JUMP_MODIFIER_ODDS := 0.10

@export_group("Jumps", "jump_")
@export var jump_per_direction_base := 6
@export var jump_per_direction_variance := 4

@export var jump_power_base := 300.0
@export var jump_power_variance := 100.0

@export var jump_wait_base := 2.0
@export var jump_wait_variance := 3.0

@export_group("Movement", "move_")
@export var move_power_base := 100.0
@export var move_power_variance := 50.0

@export var gravity := 980.0
@export var terminal_velocity := 380.0

@export_group("Variants", "variant_")
var variant := SlimeVariant.GREEN

@export var variant_green_texture: Texture2D
@export var variant_blue_texture: Texture2D
@export var variant_red_texture: Texture2D
@export var variant_purple_texture: Texture2D
@export var variant_cloud_texture: Texture2D
@export var variant_stone_texture: Texture2D
@export var variant_tunnel_texture: Texture2D

var target_player: PlayerController

var travel_direction := -1
var jump_remaining := 0
var jump_timer := 0.0
var jump_velocity: Vector2
var airborne := false

var rng: RandomNumberGenerator

# --- Functions --- #
func _ready() -> void:
	super()
	
	hp.hp_modified.connect(_on_hp_modified)
	hp.received_damage.connect(_on_receive_damage)
	
	if multiplayer.is_server():
		hp.died.connect(_on_death)

func _physics_process(delta: float) -> void:
	get_travel_direction()
	try_jump(delta)
	
	# gravity
	if not is_on_floor():
		velocity.x = jump_velocity.x
	
	velocity.y = clampf(velocity.y + gravity * delta, -terminal_velocity, terminal_velocity)
	
	# movement
	move_and_slide()
	
	# snap to floor
	if is_on_floor():
		if airborne:
			send_action_basic(LAND_ACTION)
		
		airborne = false
		velocity.x = 0.0

#region Physics
func get_travel_direction() -> void:
	if not multiplayer.is_server():
		return
	
	# jump towards target player
	if is_instance_valid(target_player):
		var distance: Vector2 = target_player.center_point - global_position
		travel_direction = sign(distance.x)
	# if no target, jump randomly
	elif jump_remaining <= 0:
		travel_direction = -travel_direction
		jump_remaining = jump_per_direction_base + randi_range(0, jump_per_direction_variance)

func try_jump(delta: float) -> void:
	# try to jump
	if is_on_floor():
		jump_timer -= delta
		
		if jump_timer <= 0:
			jump_timer = jump_wait_base + randf_range(0, jump_wait_variance)
			jump_remaining -= 1
			
			# set velocity
			jump_velocity.x =  (move_power_base + randf_range(0, move_power_variance)) * travel_direction
			jump_velocity.y = -(jump_power_base + randf_range(0, jump_power_variance))
			
			if is_instance_valid(target_player):
				var distance = global_position.distance_squared_to(target_player.global_position)
				
				if distance < (4 * TileManager.TILE_SIZE)**2:
					jump_velocity.y *= JUMP_POWER_TINY
				elif distance < (12 * TileManager.TILE_SIZE)**2:
					jump_velocity.y *= JUMP_POWER_SMALL
				if distance > (20 * TileManager.TILE_SIZE)**2:
					jump_velocity.y *= JUMP_POWER_LARGE
			else:
				var roll: float = randf()
				
				# random chance to perform a small jump
				if roll < JUMP_MODIFIER_ODDS:
					jump_velocity.y *= JUMP_POWER_SMALL
				# random chance to perform a large jump (if not a small jump)
				elif randf() < JUMP_MODIFIER_ODDS * 2.0:
					jump_velocity.y *= JUMP_POWER_LARGE
			
			$'animator'.play(&'jump')
			send_action_basic(JUMP_ACTION)

func apply_jump() -> void:
	velocity = jump_velocity
	#airborne = true

func client_apply_jump() -> void:
	airborne = true

#endregion

#region Damage
func _on_receive_damage(
		_damage: int, _source_type: DamageSource.DamageSourceType, knockback: Vector2, player_id: int
	) -> void:
	
	# set jump velocity to opposite of damage
	if knockback.x != 0.0 and not is_on_floor() and sign(knockback.x) != sign(jump_velocity.x):
		jump_velocity.x = sign(knockback.x)
	
	# set target if not already set
	if multiplayer.is_server():
		if not is_instance_valid(target_player):
			target_player = ServerManager.connected_players.get(player_id)

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
		
		# spawn item
		ItemDropEntity.spawn(global_position, 2, randi_range(1, 3))
	else:
		$'animator'.play(&'death')

#endregion

#region Multiplayer
func setup_variant() -> void:
	# variants
	match variant:
		SlimeVariant.GREEN:
			$'sprite'.texture = variant_green_texture
			
			# stats
			hp.set_max_hp(96, true)
		SlimeVariant.BLUE:
			$'sprite'.texture = variant_blue_texture
			
			# stats
			hp.set_max_hp(138, true)
		SlimeVariant.RED:
			$'sprite'.texture = variant_red_texture
			
			# stats
			hp.set_max_hp(224, true)
		SlimeVariant.PURPLE:
			$'sprite'.texture = variant_purple_texture
			
			# stats
			hp.set_max_hp(296, true)
		SlimeVariant.CLOUD:
			$'sprite'.texture = variant_cloud_texture
			
			# stats
			hp.set_max_hp(158, true)
			
			gravity *= 0.65
			jump_power_base *= 1.10
			jump_power_variance *= 1.10
			move_power_base *= 1.10
			move_power_variance *= 1.10
		SlimeVariant.STONE:
			$'sprite'.texture = variant_stone_texture
			
			# stats
			hp.set_max_hp(362, true)
			
			gravity *= 1.50
			jump_power_base *= 1.20
			jump_power_variance *= 1.20
			move_power_base *= 1.20
			move_power_variance *= 1.20
		SlimeVariant.TUNNEL:
			$'sprite'.texture = variant_tunnel_texture
			
			# stats
			hp.set_max_hp(172, true)
			
			jump_power_base *= 0.60
			jump_power_variance *= 0.60
			move_power_base *= 1.60
			move_power_variance *= 1.60
	
	# set initial direction
	travel_direction = 1 if randf() < 0.50 else -1
	jump_remaining = jump_per_direction_base + randi_range(0, jump_per_direction_variance)
	jump_timer = jump_wait_base + randf_range(0, jump_wait_variance)

func handle_action(action_info: PackedByteArray) -> void:
	super(action_info)
	
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = action_info
	
	var action_id := buffer.get_u16()
	
	# don't process if dead (just playing death animatino)
	if is_dead:
		return
	
	match action_id:
		JUMP_ACTION:
			$'animator'.play(&'jump')
			$'animator'.advance(0.0)
			$'animator'.queue(&'airborne')
		LAND_ACTION:
			$'animator'.play(&'land')
			$'animator'.advance(0.0)
			$'animator'.queue(&'idle')

#endregion

#region Sereialization
func serialize_spawn_data() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = super()
	
	# snap to end of current buffer
	var cursor := len(buffer.data_array)
	buffer.resize(len(buffer.data_array) + 2)	# base + uint16 (2)
	buffer.seek(cursor)
	
	# variant
	buffer.put_u16(variant)
	
	return buffer.data_array

func deserialize_spawn_data(buffer: StreamPeerBuffer) -> void:
	id = buffer.get_u32()
	
	# process base snapshot
	super(buffer)
	
	# variant
	variant = buffer.get_u16() as SlimeVariant
	
	setup_variant()

#endregion

#region Spawning
@warning_ignore("shadowed_variable")
static func spawn(pos: Vector2, variant: SlimeVariant) -> void:
	# create new item drop entity
	var entity_scene: PackedScene = EntityManager.enemy_registry.get(1).entity_scene
	if not entity_scene:
		return
	
	var entity: BasicSlimeEntity = entity_scene.instantiate()
	entity.global_position = pos
	
	entity.variant = variant
	
	# start entity logic
	entity.setup_variant()
	
	# sync to players
	EntityManager.add_entity(1, entity)

#endregion
