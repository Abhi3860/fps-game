extends CharacterBody3D

@export_category("Melee Stats")
@export var max_health: float = 120.0 
@export var move_speed: float = 9.0   
@export var jump_force: float = 12.0
@export var dash_speed: float = 35.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 3.0
@export var attack_range: float = 3.0
@export var attack_damage: float = 25.0
@export var attack_windup: float = 0.35 
@export var attack_cooldown: float = 1.5

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var current_health: float
var player: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- THE STATE MACHINE ---
enum State { CHASE, DASH, WINDUP, RECOVER }
var current_state: State = State.CHASE

var state_timer: float = 0.0
var dash_timer: float = 0.0
var attack_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	current_health = max_health
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func has_line_of_sight() -> bool:
	if not player:
		return false
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1, 0), player.global_position + Vector3(0, 1, 0))
	query.exclude = [self.get_rid()]
	var result = space_state.intersect_ray(query)
	return result and result.collider == player

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if not player:
		move_and_slide()
		return

	dash_timer -= delta
	attack_timer -= delta

	var distance_to_player = global_position.distance_to(player.global_position)
	var flat_player_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)

	match current_state:
		State.CHASE:
			if global_position.distance_squared_to(flat_player_pos) > 0.01:
				look_at(flat_player_pos, Vector3.UP)

			# 1. Dash Transition
			if distance_to_player < 15.0 and distance_to_player > 6.0 and dash_timer <= 0.0 and has_line_of_sight() and is_on_floor():
				current_state = State.DASH
				state_timer = dash_duration
				dash_timer = dash_cooldown
				dash_direction = global_position.direction_to(flat_player_pos).normalized()
				velocity.y = 4.0 
				return 

			# 2. Attack Transition
			if distance_to_player <= attack_range and attack_timer <= 0.0 and is_on_floor():
				current_state = State.WINDUP
				state_timer = attack_windup
				velocity.x = 0
				velocity.z = 0
				return

			# 3. Pathfinding Navigation
			nav_agent.target_position = player.global_position
			var next_path_pos = nav_agent.get_next_path_position()

			var flat_global = Vector3(global_position.x, 0.0, global_position.z)
			var flat_next = Vector3(next_path_pos.x, 0.0, next_path_pos.z)
			var flat_player = Vector3(player.global_position.x, 0.0, player.global_position.z)

			var direction = flat_global.direction_to(flat_next)
			var is_reachable = nav_agent.is_target_reachable()

			if flat_global.distance_squared_to(flat_next) < 0.1:
				if is_reachable:
					direction = flat_global.direction_to(flat_player)
				else:
					# THE FIX: If you are unreachable (no NavigationLinks), stop moving instead of glitching!
					direction = Vector3.ZERO 

			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed

			# 4. Advanced Platforming Logic
			if is_on_floor():
				var height_difference = next_path_pos.y - global_position.y
				
				# The Physics Probe: Check mathematically for gaps 1.5 meters ahead
				var is_gap_ahead = false
				if direction.length_squared() > 0.01:
					var space_state = get_world_3d().direct_space_state
					var probe_start = global_position + (direction * 1.5) + Vector3(0, 0.5, 0)
					var probe_end = probe_start + Vector3(0, -3.0, 0)
					var query = PhysicsRayQueryParameters3D.create(probe_start, probe_end)
					query.exclude = [self.get_rid()]
					var result = space_state.intersect_ray(query)
					if not result:
						is_gap_ahead = true # No floor detected, gap imminent!

				# Jump Logic: Capped at 4.5 meters so it doesn't try to scale skyscrapers
				if height_difference > 0.5 and height_difference < 4.5:
					velocity.y = jump_force # Jump up ledges
				elif is_gap_ahead and is_reachable:
					velocity.y = jump_force # Leap across chasms
				elif is_on_wall() and is_reachable and height_difference < 4.5:
					velocity.y = jump_force # Vault obstacles

		State.DASH:
			velocity.x = dash_direction.x * dash_speed
			velocity.z = dash_direction.z * dash_speed
			
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.CHASE

		State.WINDUP:
			if global_position.distance_squared_to(flat_player_pos) > 0.01:
				look_at(flat_player_pos, Vector3.UP)
				
			state_timer -= delta
			if state_timer <= 0.0:
				perform_attack()
				current_state = State.RECOVER
				state_timer = 0.5 

		State.RECOVER:
			velocity.x = 0
			velocity.z = 0
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.CHASE

	move_and_slide()

func perform_attack() -> void:
	attack_timer = attack_cooldown
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= attack_range + 1.0:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)

func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0:
		die()

func die() -> void:
	queue_free()
