extends Marker3D

@export_category("Spawner Settings")
@export var enemy_types: Array[PackedScene] ## Add your enemy scenes here!
@export var spawn_interval: float = 5.0 ## Time in seconds between spawns
@export var max_enemies_in_arena: int = 15 ## The global cap for the whole map

var timer: float = 0.0

func _ready() -> void:
	# Add a slight random delay at the start so if you place 10 spawners, 
	# they don't all spawn an enemy on the exact same frame and cause a stutter.
	timer = randf_range(0.0, spawn_interval)

func _process(delta: float) -> void:
	timer += delta
	
	if timer >= spawn_interval:
		timer = 0.0
		attempt_spawn()

func attempt_spawn() -> void:
	if enemy_types.is_empty():
		return
		
	# Check the global population cap
	var current_enemies = get_tree().get_nodes_in_group("enemy").size()
	if current_enemies >= max_enemies_in_arena:
		return
		
	# Pick a random enemy from the array
	var enemy_scene = enemy_types.pick_random()
	if not enemy_scene:
		return
		
	var enemy_instance = enemy_scene.instantiate()
	
	# Add the enemy to the active level
	# Using get_tree().current_scene ensures it spawns in the map, not as a child of the spawner
	get_tree().current_scene.add_child(enemy_instance)
	
	# Add a slight random offset so if multiple enemies spawn near each other, 
	# they don't perfectly overlap and trigger physics glitches
	var random_offset = Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	enemy_instance.global_position = global_position + random_offset
