extends CharacterBody3D

@export_category("Enemy Stats")
@export var max_health: float = 200.0
@export var move_speed: float = 8.0
@export var attack_range: float = 15.0
@export var fire_rate: float = 1.5
@export var projectile_scene: PackedScene # Drag your EnemyBullet.tscn here!

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
	# Apply gravity so they don't float off ledges
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# Do nothing if the player doesn't exist
	if not player:
		move_and_slide()
		return

	attack_cooldown -= delta
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# --- 1. AIMING ---
	# Flatten the look target so the enemy doesn't tilt upward/downward on its X/Z axes
	var look_pos = player.global_position
	look_pos.y = global_position.y 
	
	# Safety check to prevent Godot 'look_at' math crash
	if global_position.distance_squared_to(look_pos) > 0.01:
		look_at(look_pos, Vector3.UP)

	# --- 2. STATE MACHINE (CHASE OR SHOOT) ---
	if distance_to_player > attack_range:
		# Chase State
		var direction = global_position.direction_to(player.global_position)
		direction.y = 0 # Keep movement strictly horizontal
		direction = direction.normalized()
		
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		# Shoot State (Stop moving to fire)
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
