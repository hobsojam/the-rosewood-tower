extends Node2D

var beam_end := Vector2.ZERO
var beam_color := Color("#a78bfa")
var life_time := 0.12
var age := 0.0

func _process(delta: float) -> void:
	age += delta
	if age >= life_time:
		queue_free()
		return

	queue_redraw()

func _draw() -> void:
	var alpha: float = 1.0 - (age / life_time)
	draw_line(Vector2.ZERO, beam_end, Color(beam_color, alpha * 0.95), 6.0)
	draw_line(Vector2.ZERO, beam_end, Color("#f8fafc", alpha), 2.0)
