extends Node3D

signal arena_shift_completed

@export var block_scene: PackedScene
@export var nav_region: NavigationRegion3D

@export_category("Grid Settings")
@export var block_size: float = 4.0
@export var grid_width: int = 20
@export var center_exclusion_radius: float = 12.0
@export var max_arena_radius: float = 36.0

const BASE_Y_OFFSET: float = -5.0

var active_blocks: Array[Node3D] = []
var height_noise: FastNoiseLite = FastNoiseLite.new()
var shift_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	if not nav_region:
		nav_region = get_parent() as NavigationRegion3D
	
	height_noise.seed = randi()
	height_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	height_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	height_noise.cellular_jitter = 0.4
	height_noise.frequency = 0.035
	
	_spawn_initial_grid()
	shift_arena(true)

func _spawn_initial_grid() -> void:
	var half_grid = grid_width / 2.0
	for x in range(grid_width):
		for z in range(grid_width):
			var pos_x = (x - half_grid) * block_size
			var pos_z = (z - half_grid) * block_size
			var dist = Vector2(pos_x, pos_z).length()
			
			if dist < center_exclusion_radius or dist > max_arena_radius:
				continue
				
			var block = block_scene.instantiate()
			add_child(block)
			block.global_position = Vector3(pos_x, BASE_Y_OFFSET - 15.0, pos_z)
			active_blocks.append(block)

func shift_arena(instant: bool = false) -> void:
	shift_offset += Vector2(randf_range(100.0, 500.0), randf_range(100.0, 500.0))
	
	var tween: Tween
	if not instant:
		tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	for block in active_blocks:
		var noise_val = height_noise.get_noise_2d(
			block.global_position.x + shift_offset.x,
			block.global_position.z + shift_offset.y
		)
		
		var target_elevation: float = 0.0
		if noise_val > 0.45:
			target_elevation = 8.0
		elif noise_val > 0.15:
			target_elevation = 5.0
		elif noise_val > -0.15:
			target_elevation = 2.5
		else:
			target_elevation = 0.0
		
		var final_y = BASE_Y_OFFSET + target_elevation
		
		if instant:
			block.position.y = final_y
		else:
			tween.tween_property(block, "position:y", final_y, 1.5)
		
	if instant:
		_on_shift_finished()
	else:
		tween.chain().tween_callback(_on_shift_finished)

func _on_shift_finished() -> void:
	if nav_region:
		nav_region.bake_navigation_mesh()
	arena_shift_completed.emit()

func get_random_spawn_position() -> Vector3:
	if active_blocks.is_empty():
		return Vector3(15.0, 5.0, 15.0)
	
	# Exclusively pick from the outer active blocks
	var block = active_blocks.pick_random()
	
	# Block top is at block.global_position.y + 5.0
	# Adding + 2.5 gives clearance so enemies spawn in the air and drop down cleanly
	var spawn_y = block.global_position.y + 5.0 + 2.5
	return Vector3(block.global_position.x, spawn_y, block.global_position.z)
