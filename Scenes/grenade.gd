extends RigidBody3D

@export var damage: float = 280.0
@export var fuse_time: float = 2.0

@export_category("Grenade Jump Settings")
@export var player_damage_multiplier: float = 0.010 
@export var player_knockback: float = 35.0 

@onready var explosion_area: Area3D = $ExplosionArea
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var particles: GPUParticles3D = $GPUParticles3D

func _ready() -> void:

	get_tree().create_timer(fuse_time).timeout.connect(explode)

func explode() -> void:
	mesh.hide()
	particles.emitting = true
	
	for body in explosion_area.get_overlapping_bodies():
		
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(damage * player_damage_multiplier)
			
			var push_dir = global_position.direction_to(body.global_position).normalized()
			push_dir.y += 0.5 
			
			body.velocity += push_dir.normalized() * player_knockback
			
		elif body.is_in_group("enemy"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
				get_tree().call_group("hud", "show_hitmarker")
	
	await get_tree().create_timer(particles.lifetime).timeout
	queue_free()
