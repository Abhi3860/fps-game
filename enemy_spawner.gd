extends Marker3D

@export_category("Spawner Settings")
@export var enemy_types: Array[PackedScene]
@export var spawn_interval: float = 5.0
@export var max_enemies_in_arena: int = 15

var timer: float = 0.0

func _ready() -> void:
	timer = randf_range(0.0, spawn_interval)

func _process(delta: float) -> void:
	timer += delta
	
	if timer >= spawn_interval:
		timer = 0.0
		attempt_spawn()

func attempt_spawn() -> void:
	if enemy_types.is_empty():
		return
		
	var current_enemies = get_tree().get_nodes_in_group("enemy").size()
	if current_enemies >= max_enemies_in_arena:
		return
		
	var enemy_scene = enemy_types.pick_random()
	if not enemy_scene:
		return
		
	var enemy_instance = enemy_scene.instantiate()
	
	get_tree().current_scene.add_child(enemy_instance)
	
	var random_offset = Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	enemy_instance.global_position = global_position + random_offset
