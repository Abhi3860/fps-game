extends CharacterBody3D

@export_category("Melee Stats")
@export var max_health: float = 120.0 
@export var move_speed: float = 9.0   
@export var jump_force: float = 12.0
@export var attack_range: float = 3.0
@export var attack_damage: float = 25.0
@export var attack_windup: float = 0.35 
@export var attack_cooldown: float = 1.5

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var current_health: float
var player: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

enum State { CHASE, WINDUP, RECOVER }
var current_state: State = State.CHASE

var state_timer: float = 0.0
var attack_timer: float = 0.0
var jump_cooldown: float = 0.0 

func _ready() -> void:
	current_health = max_health
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if not player:
		move_and_slide()
		return

	attack_timer -= delta
	if jump_cooldown > 0.0:
		jump_cooldown -= delta

	var distance_to_player = global_position.distance_to(player.global_position)
	var flat_player_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)

	match current_state:
		State.CHASE:
			if global_position.distance_squared_to(flat_player_pos) > 0.01:
				look_at(flat_player_pos, Vector3.UP)

			# 1. Attack Transition
			if distance_to_player <= attack_range and attack_timer <= 0.0 and is_on_floor():
				current_state = State.WINDUP
				state_timer = attack_windup
				velocity.x = 0
				velocity.z = 0
				return

			# 2. Hybrid Navigation (NavMesh for mazes, Direct Vector for gaps/platforms)
			nav_agent.target_position = player.global_position
			
			var direction = Vector3.ZERO
			var flat_global = Vector3(global_position.x, 0.0, global_position.z)
			var flat_player = Vector3(player.global_position.x, 0.0, player.global_position.z)

			# If the NavMesh has a valid path, follow it.
			if nav_agent.is_target_reachable() and not nav_agent.is_navigation_finished():
				var next_path_pos = nav_agent.get_next_path_position()
				var flat_next = Vector3(next_path_pos.x, 0.0, next_path_pos.z)
				direction = flat_global.direction_to(flat_next)
			else:
				# NO NAVMESH PATH (e.g., target is on a disconnected floating platform).
				# Ignore the NavMesh entirely and sprint straight at the player's X/Z coordinates.
				direction = flat_global.direction_to(flat_player)

			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed

			# 3. Pure Physics Platforming Sensors
			if is_on_floor() and jump_cooldown <= 0.0:
				var is_player_higher = player.global_position.y > global_position.y + 1.0
				var is_player_below = player.global_position.y < global_position.y - 1.5

				# SENSOR A: The Wall Bumper
				# If we hit a wall and the player is above us, jump up the ledge.
				if is_on_wall() and is_player_higher:
					velocity.y = jump_force
					jump_cooldown = 0.5
				
				# SENSOR B: The Gap Whiskers
				# Cast a ray 1.5 meters ahead and 3 meters down to feel for the floor
				elif direction.length_squared() > 0.01:
					var space_state = get_world_3d().direct_space_state
					var probe_start = global_position + (direction * 1.5) + Vector3(0, 0.5, 0)
					var probe_end = probe_start + Vector3(0, -3.0, 0)
					var query = PhysicsRayQueryParameters3D.create(probe_start, probe_end)
					query.exclude = [self.get_rid()]
					var result = space_state.intersect_ray(query)

					if not result: 
						# THE FLOOR VANISHED.
						if not is_player_below:
							# If the player is across the gap or higher up, leap!
							velocity.y = jump_force
							jump_cooldown = 0.5
						# If the player IS below, do nothing. The enemy will naturally walk off the cliff to get to you.

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
		queue_free()
