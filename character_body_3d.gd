extends CharacterBody3D

signal dashes_updated(current_dashes: int, max_dashes: int)
signal ammo_updated(current: int, maximum: int)
signal weapon_reloading()
signal health_updated(current: float, maximum: float)
signal grenades_updated(current: int, maximum: int)

@export_category("Player Stats")
@export var max_health: float = 100.0
var current_health: float

@export_category("Movement Settings")
@export var base_speed: float = 14.0
@export var acceleration: float = 12.0
@export var friction: float = 15.0
@export var jump_velocity: float = 12.0
@export var gravity_multiplier: float = 2.0
@export var air_control: float = 0.4

@export_category("Wall Jump Settings")
@export var max_wall_jumps: int = 3
@export var wall_jump_up_force: float = 10.0
@export var wall_jump_push_force: float = 12.0
@export var wall_slide_gravity_multiplier: float = 0.3

@export_category("Dash Settings")
@export var dash_speed: float = 35.0
@export var dash_duration: float = 0.15
@export var max_dashes: int = 3
@export var dash_recovery_time: float = 3.5

@export_category("Camera Settings")
@export var mouse_sensitivity: float = 0.002
var target_recoil: Vector3 = Vector3.ZERO
var current_recoil: Vector3 = Vector3.ZERO

@export_category("Grenade Settings")
@export var grenade_scene: PackedScene
@export var max_grenades: int = 3
@export var grenade_recovery_time: float = 6.0

var current_grenades: int
var grenade_recovery_timer: float = 0.0
@export_category("Weapon Settings")
@export var projectile_scene: PackedScene
@export var current_weapon: WeaponData
@export var fire_rate: float = 0.2
@export var weapon_inventory: Array[WeaponData] = []
var parry_window_timer: float = 0.0

var current_weapon_index: int = 0
var current_weapon2: WeaponData 
var weapon_ammo: Array[int] = []
@onready var muzzle: Marker3D = $Head/Hand/Muzzle
@onready var parry_zone: Area3D = $ParryZone
@onready var weapon_mesh_container: Node3D = $Head/Hand/WeaponMeshContainer


var attack_cooldown_timer: float = 0.0

var current_ammo: int = 0
var is_reloading: bool = false
var reload_timer: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_wall_jumps: int = 0

var current_dashes: int = max_dashes
var dash_recovery_timer: float = 0.0
var dash_time_left: float = 0.0
var is_dashing: bool = false
var dash_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	current_health = max_health
	dashes_updated.emit(current_dashes, max_dashes)
	health_updated.emit(current_health, max_health)
	current_grenades = max_grenades
	grenades_updated.emit(current_grenades, max_grenades)
	if current_weapon:
		current_ammo = current_weapon.magazine_size
		ammo_updated.emit(current_ammo, current_weapon.magazine_size)
	for weapon in weapon_inventory:
		if weapon:
			weapon_ammo.append(weapon.magazine_size)
		else:
			weapon_ammo.append(0)
			
	if weapon_inventory.size() > 0:
		equip_weapon(0)
	current_grenades = max_grenades
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)
		
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventKey and event.pressed and not event.echo:
		
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			
			var slot_index = event.keycode - KEY_1
			equip_weapon(slot_index)

func _physics_process(delta: float) -> void:
	handle_dash_recovery(delta)
	handle_grenade_recovery(delta)
	handle_attack_cooldown(delta)
	handle_reloading(delta)
	handle_recoil(delta)
	
	if is_dashing:
		process_dash(delta)
	else:
		handle_gravity_and_wall_slide(delta)
		handle_jumping()
		handle_movement(delta)
		handle_dash_input()
		handle_manual_reload()
	
	move_and_slide()
	handle_attack_input()
	handle_parry_input()
	process_parry_window(delta)
	handle_grenade_input()
# dash

func handle_dash_input() -> void:
	if Input.is_action_just_pressed("dash") and current_dashes > 0:
		current_dashes -= 1
		dashes_updated.emit(current_dashes, max_dashes)
		is_dashing = true
		dash_time_left = dash_duration
		
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		
		if input_dir.length() > 0:
			dash_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		else:
			dash_direction = -transform.basis.z.normalized()
		
		velocity = dash_direction * dash_speed

func process_dash(delta: float) -> void:
	dash_time_left -= delta
	if dash_time_left <= 0.0:
		is_dashing = false
		velocity *= 0.5 
	else:
		velocity = dash_direction * dash_speed

func handle_dash_recovery(delta: float) -> void:
	if current_dashes < max_dashes:
		dash_recovery_timer += delta
		if dash_recovery_timer >= dash_recovery_time:
			current_dashes += 1
			dashes_updated.emit(current_dashes, max_dashes)
			dash_recovery_timer = 0.0

#move stuff

func handle_gravity_and_wall_slide(delta: float) -> void:
	if not is_on_floor():
		var current_gravity = gravity * gravity_multiplier
		
		if is_on_wall() and velocity.y < 0:
			current_gravity *= wall_slide_gravity_multiplier
			
		velocity.y -= current_gravity * delta

func handle_jumping() -> void:

	if is_on_floor():
		current_wall_jumps = 0
		
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			
		elif is_on_wall() and current_wall_jumps < max_wall_jumps:
			current_wall_jumps += 1
			var wall_normal = get_wall_normal()
			velocity.y = wall_jump_up_force
			
			velocity.x = wall_normal.x * wall_jump_push_force
			velocity.z = wall_normal.z * wall_jump_push_force

func handle_movement(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var is_moving = direction.length() > 0
	var current_accel = acceleration if is_moving else friction
	
	if not is_on_floor():
		current_accel *= air_control
		
	var target_velocity = direction * base_speed
	
	velocity.x = lerp(velocity.x, target_velocity.x, current_accel * delta)
	velocity.z = lerp(velocity.z, target_velocity.z, current_accel * delta)
	
	
func reset_position(safe_position: Vector3) -> void:
	
	global_position = safe_position
	
	velocity = Vector3.ZERO
	
	is_dashing = false
	dash_time_left = 0.0

func handle_attack_cooldown(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

#ammo

func handle_manual_reload() -> void:
	if Input.is_action_just_pressed("reload") and not is_reloading:
		
		if current_weapon and current_ammo < current_weapon.magazine_size:
			start_reload()

func start_reload() -> void:
	is_reloading = true
	reload_timer = current_weapon.reload_time
	weapon_reloading.emit()

func handle_reloading(delta: float) -> void:
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			is_reloading = false
			current_ammo = current_weapon.magazine_size
			weapon_ammo[current_weapon_index] = current_ammo
			ammo_updated.emit(current_ammo, current_weapon.magazine_size)

#attack stuff

func handle_attack_input() -> void:
	
	if not current_weapon or is_reloading:
		return
		
	if Input.is_action_pressed("attack") and attack_cooldown_timer <= 0.0:
		if current_ammo > 0:
			shoot_weapon()
			attack_cooldown_timer = current_weapon.fire_rate
			current_ammo -= 1
			weapon_ammo[current_weapon_index] = current_ammo
			ammo_updated.emit(current_ammo, current_weapon.magazine_size)
		else:
			
			start_reload()

func shoot_weapon() -> void:
	if not current_weapon or not muzzle:
		return
	var kick = current_weapon.recoil_amplitude
	target_recoil.x += kick.x # Upward pitch
	target_recoil.y += randf_range(-kick.y, kick.y) # Random side-to-side yaw
	target_recoil.z += randf_range(-kick.z, kick.z) # Random tilt/roll
	
	for i in range(current_weapon.projectiles_per_shot):
		
		var ray_origin = camera.global_position
		var ray_dir = -camera.global_transform.basis.z

		if current_weapon.spread_angle > 0.0:
			var random_pitch = deg_to_rad(randf_range(-current_weapon.spread_angle, current_weapon.spread_angle))
			var random_yaw = deg_to_rad(randf_range(-current_weapon.spread_angle, current_weapon.spread_angle))
			ray_dir = ray_dir.rotated(camera.global_transform.basis.x, random_pitch)
			ray_dir = ray_dir.rotated(camera.global_transform.basis.y, random_yaw)

		var ray_end = ray_origin + ray_dir * 1000.0

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.exclude = [self.get_rid()]
		var result = space_state.intersect_ray(query)

		if current_weapon.is_hitscan:
			#hitscan
			
			var hit_point = ray_end
			
			if result:
				hit_point = result.position
				var hit_collider = result.collider
				
				if hit_collider.has_method("take_damage"):
					hit_collider.take_damage(current_weapon.damage)
					if hit_collider.is_in_group("enemy"):
						get_tree().call_group("hud", "show_hitmarker")
						
			if current_weapon.projectile_scene:
				var tracer = current_weapon.projectile_scene.instantiate()
				get_tree().root.add_child(tracer)
				
				if tracer.has_method("init_tracer"):
					tracer.init_tracer(muzzle.global_position, hit_point)
				
		else:
			# projectile weapon
			if not current_weapon.projectile_scene:
				continue

			var target_point: Vector3 = result.position if result else ray_end
			var projectile = current_weapon.projectile_scene.instantiate()
			get_tree().root.add_child(projectile)
			
			projectile.global_position = muzzle.global_position
			projectile.look_at(target_point, Vector3.UP)
			
			if projectile.get("damage") != null:
				projectile.damage = current_weapon.damage
				
			if projectile.get("speed") != null:
				projectile.speed = current_weapon.projectile_speed

	if current_weapon.self_knockback > 0.0:
		var kickback_dir = camera.global_transform.basis.z.normalized()
		velocity += kickback_dir * current_weapon.self_knockback
func equip_weapon(index: int) -> void:

	if index < 0 or index >= weapon_inventory.size() or not weapon_inventory[index]:
		return
		
	current_weapon_index = index
	current_weapon = weapon_inventory[index]
	

	is_reloading = false
	reload_timer = 0.0
	

	current_ammo = weapon_ammo[current_weapon_index]

	ammo_updated.emit(current_ammo, current_weapon.magazine_size)
	update_weapon_model()

func update_weapon_model() -> void:
	for child in weapon_mesh_container.get_children():
		child.queue_free()
		
	if current_weapon.weapon_model:
		var new_model = current_weapon.weapon_model.instantiate()
		weapon_mesh_container.add_child(new_model)
		
		new_model.position = Vector3.ZERO
		new_model.rotation = Vector3.ZERO
func take_damage(amount: float) -> void:
	current_health -= amount
	print("player hp", current_health)
	health_updated.emit(current_health, max_health)
	
	if current_health <= 0:
		die()

func die() -> void:
	
	get_tree().change_scene_to_file("res://Scenes/deathscene.tscn")

func handle_parry_input() -> void:
	if Input.is_action_just_pressed("parry"):

		parry_window_timer = 0.2 

func process_parry_window(delta: float) -> void:
	if parry_window_timer > 0.0:
		parry_window_timer -= delta
		var parried_something = false
		
		for area in parry_zone.get_overlapping_areas():
			if area.has_method("parry") and not area.get("is_parried"):
				var parry_dir = -camera.global_transform.basis.z.normalized()
				area.parry(parry_dir)
				parried_something = true
		
		if parried_something:
			parry_window_timer = 0.0 
			trigger_parry_feedback()

func trigger_parry_feedback() -> void:

	current_dashes = max_dashes
	dashes_updated.emit(current_dashes, max_dashes)
	
	heal(max_health)
	
	target_recoil.x += 0.15 
	
	Engine.time_scale = 0.05 
	
	await get_tree().create_timer(0.03, true, false, true).timeout
	Engine.time_scale = 1.0

func handle_recoil(delta: float) -> void:
	var recovery = current_weapon.recoil_recovery_speed if current_weapon else 15.0
	
	var target_weight = min(recovery * delta, 1.0)
	var current_weight = min((recovery * 1.5) * delta, 1.0)
	
	target_recoil = target_recoil.lerp(Vector3.ZERO, target_weight)
	
	current_recoil = current_recoil.lerp(target_recoil, current_weight)
	
	camera.rotation = current_recoil

func heal(amount: float) -> void:
	current_health += amount
	
	if current_health > max_health:
		current_health = max_health
	health_updated.emit(current_health, max_health)
	
func handle_grenade_input() -> void:
	if Input.is_action_just_pressed("throw_grenade") and current_grenades > 0:
		current_grenades -= 1
		grenades_updated.emit(current_grenades, max_grenades)
		throw_grenade()

func throw_grenade() -> void:
	if not grenade_scene or not muzzle:
		return
		
	var grenade = grenade_scene.instantiate()
	
	get_tree().current_scene.add_child(grenade)
	
	grenade.global_position = muzzle.global_position
	
	var throw_dir = -camera.global_transform.basis.z.normalized()
	var throw_force = (throw_dir * 25.0) + (Vector3.UP * 5.0)
	
	if grenade is RigidBody3D:
		grenade.linear_velocity = throw_force
func handle_grenade_recovery(delta: float) -> void:
	if current_grenades < max_grenades:
		grenade_recovery_timer += delta
		if grenade_recovery_timer >= grenade_recovery_time:
			current_grenades += 1
			grenades_updated.emit(current_grenades, max_grenades)
			grenade_recovery_timer = 0.0
