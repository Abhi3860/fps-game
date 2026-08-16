extends Area3D

@export var speed: float = 30.0 
@export var lifetime: float = 5.0
@export var damage: float = 15.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += -global_transform.basis.z * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy"):
		return
		
	if body.has_method("take_damage"):
		body.take_damage(damage)
		
	queue_free()
