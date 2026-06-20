extends Area2D

var target
var damage := 10.0
var splash_radius := 0.0
var slow := 0.0
var speed := 520.0
var projectile_color := Color("#f8fafc")
var impact_ring_time := 0.0
var damage_tags: Array[String] = []

func configure(target_enemy, amount: float, splash: float, slow_amount: float, color: Color, tags: Array[String]) -> void:
	target = target_enemy
	damage = amount
	splash_radius = splash
	slow = slow_amount
	projectile_color = color
	damage_tags = tags.duplicate()

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	var direction: Vector2 = target.global_position - global_position
	var distance: float = direction.length()
	var step := speed * delta

	if step >= distance:
		global_position = target.global_position
		_impact()
	else:
		global_position += direction.normalized() * step

func _impact() -> void:
	if splash_radius > 0.0:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= splash_radius:
				enemy.take_damage(damage, slow, 1.2, damage_tags)
		_show_impact_ring()
	else:
		if is_instance_valid(target):
			target.take_damage(damage, slow, 1.2, damage_tags)

	queue_free()

func _show_impact_ring() -> void:
	var ring := Node2D.new()
	ring.set_script(preload("res://scripts/projectiles/SplashRing.gd"))
	ring.global_position = global_position
	ring.radius = splash_radius
	ring.ring_color = projectile_color
	get_tree().current_scene.add_child(ring)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, projectile_color)
