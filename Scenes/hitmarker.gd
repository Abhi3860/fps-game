extends Control

func _ready() -> void:

	modulate.a = 0.0

func _draw() -> void:
	var center = Vector2.ZERO
	var length = 10.0
	var thickness = 2.0
	var offset = 6.0
	var color = Color(1.0, 1.0, 1.0, 1.0) 

	draw_line(center + Vector2(offset, offset), center + Vector2(offset + length, offset + length), color, thickness)
	draw_line(center + Vector2(-offset, -offset), center + Vector2(-offset - length, -offset - length), color, thickness)
	draw_line(center + Vector2(-offset, offset), center + Vector2(-offset - length, offset + length), color, thickness)
	draw_line(center + Vector2(offset, -offset), center + Vector2(offset + length, -offset - length), color, thickness)

func flash() -> void:

	var tween = create_tween()
	

	scale = Vector2(1.5, 1.5)
	modulate.a = 1.0
	

	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.05)
