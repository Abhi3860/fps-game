extends Area3D

@export var heal_amount: float = 50.0
@export var rotation_speed: float = 2.0 

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	rotate_y(rotation_speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		
		if body.has_method("heal"):
			
			body.heal(heal_amount)
			queue_free()
