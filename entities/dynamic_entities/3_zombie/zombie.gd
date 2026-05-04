class_name ZombieEntity
extends Entity

# --- Enums --- #
enum ZombieVariant {
	NORMAL
}

# --- Variables --- #
const JUMP_ACTION := 16
const LAND_ACTION := 17

const JUMP_POWER_TINY := 0.35
const JUMP_POWER_SMALL := 0.50
const JUMP_POWER_LARGE := 3.0
const JUMP_MODIFIER_ODDS := 0.10

@export_group("Jumps", "jump_")
@export var jump_per_direction_base := 6
@export var jump_per_direction_variance := 4

@export var jump_power_base := 300.0
@export var jump_power_variance := 100.0


@export_group("Movement", "move_")
@export var move_power_base := 100.0
@export var move_power_variance := 50.0
@export var move_float_base := 80.0

@export var gravity := 980.0
@export var buoyancy := 0
@export var terminal_velocity := 380.0

@export_group("Variants", "variant_")
var variant := ZombieVariant.NORMAL

@export var variant_normal_texture: Texture2D


var target_player: PlayerController


var travel_direction := -1.0
var jump_remaining := 0

var jump_velocity: Vector2
var airborne := false

var rng: RandomNumberGenerator

var in_water := false

# --- Functions --- #
func _ready() -> void:
	super()
	
	hp.hp_modified.connect(_on_hp_modified)
	hp.received_damage.connect(_on_receive_damage)
	
	if multiplayer.is_server():
		hp.died.connect(_on_death)
		
	# set target if not already set


func _physics_process(delta: float) -> void:
	# check water
	var tile_pos := TileManager.world_to_tile(
		floori(global_position.x - 0.5),
		floori(global_position.y - 0.5)
	)
	
	in_water = (
		TileManager.get_liquid_type(tile_pos.x, tile_pos.y) > 0 or
		TileManager.get_liquid_type(tile_pos.x + 1, tile_pos.y) > 0
	) and (
		TileManager.get_liquid_level(tile_pos.x, tile_pos.y) > WaterUpdater.MAX_WATER_LEVEL * 0.50 or
		TileManager.get_liquid_level(tile_pos.x + 1, tile_pos.y) > WaterUpdater.MAX_WATER_LEVEL * 0.50
	)
	
	# check for lava
	var in_lava := (
		TileManager.get_liquid_type(tile_pos.x, tile_pos.y) == WaterUpdater.LAVA_TYPE or
		TileManager.get_liquid_type(tile_pos.x + 1, tile_pos.y) == WaterUpdater.LAVA_TYPE
	) and (
		TileManager.get_liquid_level(tile_pos.x, tile_pos.y) > 16 or
		TileManager.get_liquid_level(tile_pos.x + 1, tile_pos.y) > 16
	)
	
	if in_lava:
		hp.take_damage(1, DamageSource.DamageSourceType.WORLD)
	
	get_travel_direction(delta)
	# walk towards player
	if is_on_floor():
		velocity.x = move_power_base * travel_direction
		if is_on_wall():
			try_jump(delta)
	
	# gravity
	velocity.y += gravity * delta
	velocity.y = clampf(velocity.y, -terminal_velocity, terminal_velocity)
	
	move_and_slide()
	
	# gravity
	if not is_on_floor():
		velocity.x = jump_velocity.x
	
	# buoyancy
	if in_water:
		velocity.y -= buoyancy * delta

	
	# snap to floor
	if is_on_floor():
		
		if airborne:
			send_action_basic(LAND_ACTION)
		
		airborne = false
		velocity.x = 0.0

#region Physics
func get_travel_direction(delta: float) -> void:
	if not multiplayer.is_server():
		return
	
	#tries to find nearest player if no target
	if not is_instance_valid(target_player):
		var nearest_distance := INF
		#nearest distance is set to infinity at first.
		for player in ServerManager.connected_players.values():
			#searches through all the players and  finds the closest one.
			var distance := global_position.distance_squared_to(player.global_position)
			#grabs position of player in for loop
			if distance < nearest_distance:
				#if the player is closer than the 'nearest distance'
				nearest_distance = distance
				target_player = player
				#target player becomes this player as they are closer.
	
	# jump towards target player
	if is_instance_valid(target_player):
		var distance: Vector2 = target_player.center_point - global_position
		
		travel_direction += delta * signf(distance.x)
		travel_direction = clampf(travel_direction, -1.0, 1.0)
	# if no target, move randomly
	elif jump_remaining <= 0:
		travel_direction = -travel_direction
		jump_remaining = jump_per_direction_base + randi_range(0, jump_per_direction_variance)

func try_jump(delta: float) -> void:
	# special water logic
	if in_water:
		jump_velocity.x = move_float_base * travel_direction
		return
	
	# try to jump
	if is_on_floor():
		
		jump_remaining -= 1
			
		# set velocity
		jump_velocity.x =  (move_power_base + randf_range(0, move_power_variance)) * travel_direction
		jump_velocity.y = -(jump_power_base + randf_range(0, jump_power_variance))
			
		if is_instance_valid(target_player):
			#var distance = global_position.distance_squared_to(target_player.global_position)
			#unneeded distance code
			jump_velocity.y *= JUMP_POWER_LARGE
		else:
			var roll: float = randf()
			#randf() returns a value between 0 and 1.0
				
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
		jump_velocity.x = jump_velocity.x * sign(knockback.x)
	
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
		print("the undead was slain")
		# spawn item
		ItemDropEntity.spawn(global_position, 2, randi_range(1, 3))
	else:
		$'animator'.play(&'death')

#endregion

#region Multiplayer
func setup_variant() -> void:
	# variants
	match variant:
		ZombieVariant.NORMAL:
			$'sprite'.texture = variant_normal_texture
			
			# stats
			hp.set_max_hp(96, true)
	
	# set initial direction
	travel_direction = 1 if randf() < 0.50 else -1

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
	variant = buffer.get_u16() as ZombieVariant
	print("deserialize called, variant: ", variant)
	
	setup_variant()

#endregion

#region Spawning
@warning_ignore("shadowed_variable")
static func spawn(pos: Vector2, variant: ZombieVariant) -> void:
	# create new item drop entity
	var entity_scene: PackedScene = EntityManager.enemy_registry.get(3).entity_scene
	if not entity_scene:
		return
	print("Creating the undead.")
	var entity: ZombieEntity = entity_scene.instantiate()
	entity.global_position = pos
	
	entity.variant = variant
	
	# start entity logic
	entity.setup_variant()
	
	# sync to players
	EntityManager.add_entity(3, entity)
	#make sure this and the var entity scene line have the same entity spawning.

#endregion
