extends Area3D

@export var speed: float = 30.0 
@export var lifetime: float = 5.0
@export var damage: float = 15.0

var is_parried: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += -global_transform.basis.z * speed * delta

func parry(new_direction: Vector3) -> void:
	is_parried = true
	speed *= 2.5
	print("parry")
	look_at(global_position + new_direction, Vector3.UP)

func _on_body_entered(body: Node3D) -> void:
	if not is_parried and body.is_in_group("enemy"):
		return
		
	if is_parried and body.is_in_group("player"):
		return
		
	if body.has_method("take_damage"):
		var final_damage = damage * 2.0 if is_parried else damage
		body.take_damage(final_damage)
		if is_parried and body.is_in_group("enemy"):
			get_tree().call_group("hud", "show_hitmarker")
		
	queue_free()
