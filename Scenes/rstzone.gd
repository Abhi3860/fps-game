extends Area3D

@export var respawn_point: Marker3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if respawn_point:
			body.reset_position(respawn_point.global_position)
		else:
			push_error("OutOfBoundsZone: No Respawn Point assigned!")
