extends CharacterBody3D

@export_category("Enemy Stats")
@export var max_health: float = 200.0
@export var move_speed: float = 8.0
@export var attack_range: float = 15.0
@export var fire_rate: float = 1.5
@export var projectile_scene: PackedScene # Drag your EnemyBullet.tscn here!
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

@onready var muzzle: Marker3D = $Muzzle

var current_health: float
var player: Node3D
var attack_cooldown: float = 0.0

# Get global gravity
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	current_health = max_health
	
	# Find the player in the scene dynamically
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	if not player:
		move_and_slide()
		return

	attack_cooldown -= delta
	
	var distance_to_player = global_position.distance_to(player.global_position)
	var can_see_player = has_line_of_sight()
	
	# --- 1. AIMING ---
	var look_pos = player.global_position
	look_pos.y = global_position.y 
	
	if global_position.distance_squared_to(look_pos) > 0.01:
		look_at(look_pos, Vector3.UP)

	# --- 2. STATE MACHINE (PATHFINDING OR SHOOT) ---
	
	# If we are too far OR we are blocked by a wall, keep moving!
	if distance_to_player > attack_range or not can_see_player:
		
		# Tell the brain where we want to go
		nav_agent.target_position = player.global_position
		
		# The brain calculates the next immediate step to get around the wall
		var next_path_position = nav_agent.get_next_path_position()
		
		# Move toward that specific step, not directly at the player
		var direction = global_position.direction_to(next_path_position)
		direction.y = 0 
		direction = direction.normalized()
		
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		
	else:
		# We are in range AND we have a clear shot. Stop and fire!
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		
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
	proj.look_at(player.global_position, Vector3.UP)

func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0:
		die()

func die() -> void:
	queue_free()
func has_line_of_sight() -> bool:
	if not player or not muzzle:
		return false
		
	var space_state = get_world_3d().direct_space_state
	
	# Raycast from the enemy's muzzle to the player's center mass
	var target_pos = player.global_position + Vector3(0, 1.0, 0)
	var query = PhysicsRayQueryParameters3D.create(muzzle.global_position, target_pos)
	query.exclude = [self.get_rid()]
	
	var result = space_state.intersect_ray(query)
	
	# If the ray hit something, check if it was actually the player
	if result and result.collider == player:
		return true
		
	# If it hit a wall (or nothing), return false
	return false
