extends Resource
class_name WeaponData

@export var name: String = "New Weapon"
@export var projectile_scene: PackedScene
@export var damage: float = 25.0

@export_category("Firing Mechanics")
@export var fire_rate: float = 0.2
@export var projectiles_per_shot: int = 1 
@export var spread_angle: float = 0.0 
@export var self_knockback: float = 0.0

@export_category("Ammo")
@export var magazine_size: int = 10
@export var reload_time: float = 1.5
