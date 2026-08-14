extends CharacterBody3D

@export_category("Enemy Stats")
@export var max_health: float = 200.0
@export var move_speed: float = 8.0
@export var attack_range: float = 15.0
@export var fire_rate: float = 1.5
@export var projectile_scene: PackedScene
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

@onready var muzzle: Marker3D = $Muzzle

var current_health: float
var player: Node3D
var attack_cooldown: float = 0.0


var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	current_health = max_health
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
		
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	if not is_instance_valid(player) or not player.is_inside_tree():
		return

	attack_cooldown -= delta
	
	var distance_to_player = global_position.distance_to(player.global_position)
	var can_see_player = has_line_of_sight()
	
	var look_pos = player.global_position
	look_pos.y = global_position.y 
	
	if global_position.distance_squared_to(look_pos) > 0.01:
		look_at(look_pos, Vector3.UP)

	if distance_to_player > attack_range or not can_see_player:
		
		nav_agent.target_position = player.global_position
		var next_path_position = nav_agent.get_next_path_position()
		
		var flat_global = Vector3(global_position.x, 0.0, global_position.z)
		var flat_next = Vector3(next_path_position.x, 0.0, next_path_position.z)
		var flat_player = Vector3(player.global_position.x, 0.0, player.global_position.z)
		
		var direction = Vector3.ZERO
		
		if not nav_agent.is_navigation_finished():
			direction = flat_global.direction_to(flat_next)
		else:
			direction = flat_global.direction_to(flat_player)
			
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		
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
	
	var target_pos = player.global_position + Vector3(0, 1.0, 0)
	var query = PhysicsRayQueryParameters3D.create(muzzle.global_position, target_pos)
	query.exclude = [self.get_rid()]
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == player:
		return true
		
	return false
