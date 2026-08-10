extends CharacterBody3D

@export_category("Sniper Stats")
@export var max_health: float = 30.0 
@export var move_speed: float = 6.0
@export var min_distance: float = 20.0 
@export var max_distance: float = 40.0 
@export var fire_rate: float = 3.5
@export var projectile_scene: PackedScene 

@onready var muzzle: Marker3D = $Muzzle
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var current_health: float
var player: Node3D
var attack_cooldown: float = 0.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	current_health = max_health
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func has_line_of_sight() -> bool:
	if not player or not muzzle:
		return false
		
	var space_state = get_world_3d().direct_space_state
	
	# FIX 1: Removed the +1.0 Y offset so it perfectly tracks your center mass even while dashing
	var query = PhysicsRayQueryParameters3D.create(muzzle.global_position, player.global_position)
	query.exclude = [self.get_rid()]
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == player:
		return true
		
	return false

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	if not player:
		move_and_slide()
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	var can_see_player = has_line_of_sight()
	
	# --- 1. AIMING ---
	var look_pos = player.global_position
	look_pos.y = global_position.y 
	
	if global_position.distance_squared_to(look_pos) > 0.01:
		look_at(look_pos, Vector3.UP)

# --- 2. STATE MACHINE ---
	
	if not can_see_player or distance_to_player > max_distance:
		# STATE: Chase 
		nav_agent.target_position = player.global_position
		var next_path_position = nav_agent.get_next_path_position()
		
		# THE FIX: Create perfectly flat 2D coordinates BEFORE doing math
		var flat_global = Vector3(global_position.x, 0.0, global_position.z)
		var flat_next = Vector3(next_path_position.x, 0.0, next_path_position.z)
		var flat_player = Vector3(player.global_position.x, 0.0, player.global_position.z)
		
		# Now the direction is purely horizontal
		var direction = flat_global.direction_to(flat_next)
		
		# Fallback: If the NavMesh fails and tells the sniper to go nowhere, chase directly
		if flat_global.distance_squared_to(flat_next) < 0.1:
			direction = flat_global.direction_to(flat_player)
			
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		
		attack_cooldown = min(attack_cooldown, 0.5)
		
	elif distance_to_player < min_distance and can_see_player:
		# STATE: Flee 
		var flee_dir = -global_position.direction_to(player.global_position)
		flee_dir.y = 0
		flee_dir = flee_dir.normalized()
		
		velocity.x = flee_dir.x * move_speed
		velocity.z = flee_dir.z * move_speed
		
		attack_cooldown = min(attack_cooldown, 0.5)
		
	else:
		# STATE: Shoot (Locked in the Goldilocks zone)
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		
		# FIX 2: Cooldown ONLY ticks down when actively planted and aiming
		attack_cooldown -= delta
		
		if attack_cooldown <= 0.0:
			shoot_at_player()
			attack_cooldown = fire_rate
			
	move_and_slide()

func shoot_at_player() -> void:
	if not projectile_scene or not muzzle:
		return
		
	var proj = projectile_scene.instantiate()
	get_tree().root.add_child(proj)
	proj.global_position = muzzle.global_position
	
	# Extra safety math to prevent glitchy bullet rotations if you are directly below them
	var aim_dir = (player.global_position - muzzle.global_position).normalized()
	if abs(aim_dir.y) > 0.99:
		proj.look_at(player.global_position, Vector3.RIGHT)
	else:
		proj.look_at(player.global_position, Vector3.UP)

func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0:
		die()

func die() -> void:
	queue_free()
