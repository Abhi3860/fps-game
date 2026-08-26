extends Node

@export_category("Wave Settings")
@export var enemy_scenes: Array[PackedScene]
@export var base_enemies_per_wave: int = 5
@export var time_between_spawns: float = 1.5
@export var min_spawn_distance_from_player: float = 20.0 

@export_category("Arena Connectivity")
@export var arena_generator: Node3D

var current_wave: int = 0
var enemies_to_spawn: int = 0
var enemies_alive: int = 0
var spawn_timer: float = 0.0
var is_intermission: bool = false
var intermission_timer: float = 0.0

# Prevent enemies from spawning while the ground is moving
var is_shifting: bool = false

@onready var player: CharacterBody3D = get_tree().get_nodes_in_group("player")[0]

func start_intermission(duration: float) -> void:
	is_intermission = true
	intermission_timer = duration

func _ready() -> void:
	if NetworkManager.is_multiplayer:
		queue_free()
		return
	start_intermission(3.0)

func start_next_wave() -> void:
	current_wave += 1
	enemies_to_spawn = current_wave * base_enemies_per_wave
	enemies_alive = enemies_to_spawn
	
	get_tree().call_group("hud", "update_wave_text", current_wave)
	
	# THE FIX: Tell the arena to shift, and wait until it's completely done before spawning enemies
	if arena_generator and arena_generator.has_method("shift_arena"):
		is_shifting = true
		arena_generator.shift_arena()
		await arena_generator.arena_shift_completed
		is_shifting = false
		
	spawn_timer = time_between_spawns

func _process(delta: float) -> void:
	if is_intermission:
		intermission_timer -= delta
		get_tree().call_group("hud", "update_countdown_text", ceili(intermission_timer))
		
		if intermission_timer <= 0.0:
			is_intermission = false
			start_next_wave()
		return
		
	# THE FIX: Do not tick down the spawn timer if the ground is still animating
	if is_shifting:
		return
		
	if enemies_to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_random_enemy()
			spawn_timer = time_between_spawns
			enemies_to_spawn -= 1

func spawn_random_enemy() -> void:
	if enemy_scenes.is_empty(): 
		return
	
	var enemy_scene = enemy_scenes.pick_random()
	var enemy_instance = enemy_scene.instantiate()
	
	get_tree().current_scene.add_child(enemy_instance)
	
	# Spawn at safe position with proper height
	enemy_instance.global_position = get_safe_spawn_point()
	enemy_instance.tree_exited.connect(_on_enemy_died)

func get_safe_spawn_point() -> Vector3:
	if arena_generator and arena_generator.has_method("get_random_spawn_position"):
		for i in range(25):
			var test_point: Vector3 = arena_generator.get_random_spawn_position()
			if player and test_point.distance_to(player.global_position) >= min_spawn_distance_from_player:
				return test_point
		return arena_generator.get_random_spawn_position()
		
	return Vector3(15.0, 4.0, 15.0)

func _on_enemy_died() -> void:
	if not is_inside_tree():
		return
		
	enemies_alive -= 1
	if enemies_to_spawn <= 0 and enemies_alive <= 3 and enemies_alive > 0:
		get_tree().call_group("enemy", "reveal")
	if enemies_alive <= 0 and enemies_to_spawn <= 0:
		start_intermission(4.0)
