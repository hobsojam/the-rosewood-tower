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
		var splash_hits: Array[Dictionary] = []
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var enemy_node := enemy as Node2D
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			if global_position.distance_to(enemy_node.global_position) > splash_radius:
				continue
			var shield_reduction := 0.0
			if enemy_node.has_method("get_incoming_shield_reduction"):
				shield_reduction = float(enemy_node.get_incoming_shield_reduction())
			splash_hits.append({"enemy": enemy_node, "shield_reduction": shield_reduction})
		for splash_hit in splash_hits:
			var hit_enemy := splash_hit["enemy"] as Node2D
			if hit_enemy != null and is_instance_valid(hit_enemy):
				hit_enemy.take_damage(damage, slow, 1.2, damage_tags, float(splash_hit["shield_reduction"]))
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
