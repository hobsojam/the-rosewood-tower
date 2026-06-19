extends Node2D

var pop_color := Color("#f8fafc")
var lifetime := 0.26
var age := 0.0

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress: float = clamp(age / lifetime, 0.0, 1.0)
	var color := pop_color
	color.a = 0.8 * (1.0 - progress)
	draw_circle(Vector2.ZERO, 12.0 + progress * 18.0, color, false, 3.0)
	draw_circle(Vector2.ZERO, 4.0 + progress * 8.0, Color(1.0, 1.0, 1.0, color.a))
