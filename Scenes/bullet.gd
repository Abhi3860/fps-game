extends Area3D

@export var speed: float = 90.0
@export var lifetime: float = 3.0
@export var damage: float = 25.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Automatically clean up the bullet after lifetime expires
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	# Move forward along the projectile's local -Z axis
	global_position += -global_transform.basis.z * speed * delta

func _on_body_entered(body: Node3D) -> void:
	# Ignore the player who shot it
	if body.is_in_group("player"):
		return
		
	# Deal damage if the target supports it
	if body.has_method("take_damage"):
		body.take_damage(damage)
		get_tree().call_group("hud", "show_hitmarker")
		
	queue_free()
