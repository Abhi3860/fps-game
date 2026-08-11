extends Node3D

@onready var mesh: MeshInstance3D = $MeshInstance3D

func init_tracer(start_pos: Vector3, end_pos: Vector3) -> void:
	global_position = start_pos
	
	var aim_dir = start_pos.direction_to(end_pos)
	if abs(aim_dir.y) > 0.99:
		look_at(end_pos, Vector3.RIGHT)
	else:
		look_at(end_pos, Vector3.UP)
	
	var distance = start_pos.distance_to(end_pos)
	
	mesh.scale.z = distance
	mesh.position.z = -distance / 2.0
	
	var tween = create_tween()
	tween.tween_property(self, "scale:x", 0.0, 0.1)
	tween.tween_property(self, "scale:y", 0.0, 0.1)
	tween.tween_callback(queue_free).set_delay(0.1)
