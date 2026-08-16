extends Node

@export_category("Wave Settings")
@export var enemy_scenes: Array[PackedScene]
@export var base_enemies_per_wave: int = 5
@export var time_between_spawns: float = 1.5
@export var min_spawn_distance_from_player: float = 20.0 

var current_wave: int = 0
var enemies_to_spawn: int = 0
var enemies_alive: int = 0
var spawn_timer: float = 0.0
var is_intermission: bool = false
var intermission_timer: float = 0.0

@onready var player: CharacterBody3D = get_tree().get_nodes_in_group("player")[0]
func start_intermission(duration: float) -> void:
	is_intermission = true
	intermission_timer = duration
func _ready() -> void:
	start_intermission(3.0)

func start_next_wave() -> void:
	current_wave += 1
	

	enemies_to_spawn = current_wave * base_enemies_per_wave
	enemies_alive = enemies_to_spawn
	
	get_tree().call_group("hud", "update_wave_text", current_wave)
	
	spawn_timer = time_between_spawns

func _process(delta: float) -> void:
	if is_intermission:
		intermission_timer -= delta

		get_tree().call_group("hud", "update_countdown_text", ceili(intermission_timer))
		
		if intermission_timer <= 0.0:
			is_intermission = false
			start_next_wave()
		return
		
	if enemies_to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_random_enemy()
			spawn_timer = time_between_spawns
			enemies_to_spawn -= 1

func spawn_random_enemy() -> void:
	if enemy_scenes.is_empty(): return
	
	var enemy_scene = enemy_scenes.pick_random()
	var enemy_instance = enemy_scene.instantiate()
	
	get_tree().current_scene.add_child(enemy_instance)
	
	enemy_instance.global_position = get_safe_spawn_point() + Vector3(0, 1.5, 0)
	
	enemy_instance.tree_exited.connect(_on_enemy_died)

func get_safe_spawn_point() -> Vector3:
	var map = player.get_world_3d().navigation_map
	
	for i in range(15):
		var random_x = randf_range(-40.0, 60.0) 
		var random_z = randf_range(-30.0, 70.0)
		var test_point = Vector3(random_x, 0.0, random_z)
		
		var safe_point = NavigationServer3D.map_get_closest_point(map, test_point)
		
		if safe_point.distance_to(player.global_position) > min_spawn_distance_from_player:
			return safe_point
			
	return NavigationServer3D.map_get_closest_point(map, Vector3.ZERO)

func _on_enemy_died() -> void:
	if not is_inside_tree():
		return
		
	enemies_alive -= 1
	if enemies_to_spawn <= 0 and enemies_alive <= 3 and enemies_alive > 0:
		get_tree().call_group("enemy", "reveal")
	if enemies_alive <= 0 and enemies_to_spawn <= 0:
		start_intermission(4.0)
