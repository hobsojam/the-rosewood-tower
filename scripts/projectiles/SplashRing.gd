extends Node2D

var radius := 48.0
var ring_color := Color("#fb7185")
var lifetime := 0.28
var age := 0.0

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress: float = clamp(age / lifetime, 0.0, 1.0)
	var color := ring_color
	color.a = 0.5 * (1.0 - progress)
	draw_circle(Vector2.ZERO, radius * (0.7 + progress * 0.3), color, false, 4.0)
