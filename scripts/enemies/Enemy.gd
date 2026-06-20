extends Area2D

const DEATH_POP_SCRIPT := preload("res://scripts/effects/DeathPop.gd")

signal died(reward: int)
signal reached_exit(breach_damage: int)

var enemy_id := "standard"
var display_name := "Enemy"
var max_health := 1.0
var health := 1.0
var base_speed := 80.0
var reward := 1
var breach_damage := 1
var traits: Array[String] = []
var shield_radius := 0.0
var shield_reduction := 0.0
var path_points := []
var path_index := 0
var slow_multiplier := 1.0
var slow_time := 0.0
var body_color := Color.WHITE
var hit_flash_time := 0.0
var shield_absorb_flash_time := 0.0
var finished := false
var facing_angle := 0.0

func _ready() -> void:
	add_to_group("enemies")
	if not path_points.is_empty():
		global_position = path_points[0]
	queue_redraw()

func configure(id: String, data: Dictionary, path: Array) -> void:
	enemy_id = id
	display_name = data["name"]
	max_health = float(data["health"])
	health = max_health
	base_speed = float(data["speed"])
	reward = int(data["reward"])
	breach_damage = int(data.get("breach_damage", 1))
	traits = _to_string_array(data.get("traits", []))
	shield_radius = float(data.get("shield_radius", 0.0))
	shield_reduction = float(data.get("shield_reduction", 0.0))
	body_color = Color.html(str(data["color"]))
	path_points = path.duplicate()

func _to_string_array(values: Array) -> Array[String]:
	var strings: Array[String] = []
	for value in values:
		strings.append(str(value))
	return strings

func _process(delta: float) -> void:
	if finished or path_points.size() < 2:
		return

	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow_multiplier = 1.0

	if hit_flash_time > 0.0:
		hit_flash_time -= delta
		queue_redraw()
	if shield_absorb_flash_time > 0.0:
		shield_absorb_flash_time -= delta
		queue_redraw()

	var target: Vector2 = path_points[path_index + 1]
	var direction: Vector2 = target - global_position
	var distance: float = direction.length()
	var step: float = base_speed * slow_multiplier * delta
	if distance > 0.0:
		facing_angle = direction.angle()

	if step >= distance:
		global_position = target
		path_index += 1
		if path_index >= path_points.size() - 1:
			finished = true
			reached_exit.emit(breach_damage)
			queue_free()
	else:
		global_position += direction.normalized() * step

func take_damage(amount: float, slow: float = 0.0, slow_duration: float = 1.0, damage_tags: Array[String] = [], shield_reduction_override: float = -1.0) -> void:
	if finished:
		return

	var effective_damage := _get_effective_damage(amount, damage_tags, shield_reduction_override)
	health -= effective_damage
	if effective_damage > 0.0:
		hit_flash_time = 0.08
	if slow > 0.0 and effective_damage > 0.0:
		slow_multiplier = clamp(1.0 - slow, 0.2, 1.0)
		slow_time = slow_duration

	if health <= 0.0:
		finished = true
		_spawn_death_pop()
		died.emit(reward)
		queue_free()
	else:
		queue_redraw()

func get_path_progress() -> float:
	if path_points.size() < 2:
		return float(path_index)

	var next_index: int = min(path_index + 1, path_points.size() - 1)
	var segment_start: Vector2 = path_points[path_index]
	var segment_end: Vector2 = path_points[next_index]
	var segment_length: float = segment_start.distance_to(segment_end)
	if is_zero_approx(segment_length):
		return float(path_index)

	var segment_progress: float = segment_start.distance_to(global_position) / segment_length
	return float(path_index) + clamp(segment_progress, 0.0, 1.0)

func _get_effective_damage(amount: float, damage_tags: Array[String], shield_reduction_override: float = -1.0) -> float:
	var strongest_reduction := shield_reduction_override if shield_reduction_override >= 0.0 else get_incoming_shield_reduction()
	return amount * _get_trait_damage_multiplier(damage_tags) * (1.0 - strongest_reduction)

func get_incoming_shield_reduction() -> float:
	var strongest_reduction := 0.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var shield_enemy := enemy as Node2D
		if shield_enemy == null or not is_instance_valid(shield_enemy):
			continue
		if not shield_enemy.has_method("get_shield_reduction"):
			continue

		var reduction: float = shield_enemy.get_shield_reduction(global_position)
		if reduction > 0.0 and shield_enemy.has_method("flash_shield_absorb"):
			shield_enemy.flash_shield_absorb()
		strongest_reduction = max(strongest_reduction, reduction)
	return strongest_reduction

func _get_trait_damage_multiplier(damage_tags: Array[String]) -> float:
	var multiplier := 1.0
	if traits.has("air") and (damage_tags.has("slow") or damage_tags.has("blast")):
		return 0.0
	if traits.has("air") and not damage_tags.has("anti_air"):
		multiplier *= 0.15
	if not traits.has("air") and damage_tags.has("anti_air"):
		multiplier *= 0.6
	if traits.has("burrowed") and not damage_tags.has("blast"):
		multiplier *= 0.45
	if traits.has("armored") and damage_tags.has("direct") and not damage_tags.has("pierce"):
		multiplier *= 0.65
	if traits.has("armored") and damage_tags.has("pierce"):
		multiplier *= 1.25
	if traits.has("heavy") and damage_tags.has("direct") and not damage_tags.has("pierce"):
		multiplier *= 0.55
	if traits.has("heavy") and damage_tags.has("blast"):
		multiplier *= 1.2
	return multiplier

func get_shield_reduction(point: Vector2) -> float:
	if finished or shield_radius <= 0.0:
		return 0.0
	if global_position.distance_to(point) > shield_radius:
		return 0.0
	return shield_reduction

func flash_shield_absorb() -> void:
	shield_absorb_flash_time = 0.18
	queue_redraw()

func _spawn_death_pop() -> void:
	var pop := Node2D.new()
	pop.set_script(DEATH_POP_SCRIPT)
	pop.global_position = global_position
	pop.pop_color = body_color
	get_tree().current_scene.add_child(pop)

func _draw() -> void:
	var color := Color.WHITE if hit_flash_time > 0.0 else body_color
	match enemy_id:
		"air":
			_draw_air_enemy(color)
		"siege":
			_draw_siege_enemy(color)
		"decoy":
			_draw_decoy_enemy(color)
		"armored":
			_draw_armored_enemy(color)
		"shield":
			_draw_shield_enemy(color)
		"fast":
			_draw_fast_enemy(color)
		_:
			_draw_standard_enemy(color)

	var health_ratio: float = clamp(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-16, -24), Vector2(32, 4)), Color("#111827"))
	draw_rect(Rect2(Vector2(-16, -24), Vector2(32 * health_ratio, 4)), Color("#22c55e"))

func _draw_standard_enemy(color: Color) -> void:
	draw_set_transform(Vector2.ZERO, facing_angle, Vector2.ONE)
	draw_rect(Rect2(Vector2(-13, -10), Vector2(26, 20)), Color("#111827"))
	draw_rect(Rect2(Vector2(-11, -8), Vector2(22, 16)), color)
	draw_circle(Vector2(-8, -10), 4.0, Color("#6b7280"))
	draw_circle(Vector2(8, -10), 4.0, Color("#6b7280"))
	draw_circle(Vector2(-8, 10), 4.0, Color("#6b7280"))
	draw_circle(Vector2(8, 10), 4.0, Color("#6b7280"))
	draw_rect(Rect2(Vector2(5, -4), Vector2(10, 8)), Color("#9ca3af"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_fast_enemy(color: Color) -> void:
	draw_set_transform(Vector2.ZERO, facing_angle, Vector2.ONE)
	var nose := PackedVector2Array([Vector2(18, 0), Vector2(-10, -12), Vector2(-5, 0), Vector2(-10, 12)])
	draw_colored_polygon(nose, color)
	draw_polyline(PackedVector2Array([Vector2(18, 0), Vector2(-10, -12), Vector2(-5, 0), Vector2(-10, 12), Vector2(18, 0)]), Color("#111827"), 2.0)
	draw_line(Vector2(-4, -8), Vector2(-18, -16), Color("#62d0ff"), 3.0)
	draw_line(Vector2(-4, 8), Vector2(-18, 16), Color("#62d0ff"), 3.0)
	draw_circle(Vector2(-7, 0), 4.0, Color("#e0f2fe"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_armored_enemy(color: Color) -> void:
	draw_set_transform(Vector2.ZERO, facing_angle, Vector2.ONE)
	draw_rect(Rect2(Vector2(-17, -12), Vector2(34, 24)), Color("#111827"))
	draw_rect(Rect2(Vector2(-15, -10), Vector2(30, 20)), color)
	draw_rect(Rect2(Vector2(-18, -14), Vector2(36, 5)), Color("#2f3a44"))
	draw_rect(Rect2(Vector2(-18, 9), Vector2(36, 5)), Color("#2f3a44"))

	for tread_x in [-12, -4, 4, 12]:
		draw_line(Vector2(tread_x, -14), Vector2(tread_x - 4, -9), Color("#6b7280"), 2.0)
		draw_line(Vector2(tread_x, 14), Vector2(tread_x - 4, 9), Color("#6b7280"), 2.0)

	draw_circle(Vector2(2, 0), 8.0, Color("#fbbf24") if hit_flash_time <= 0.0 else Color.WHITE)
	draw_circle(Vector2(2, 0), 8.0, Color("#111827"), false, 2.0)
	draw_rect(Rect2(Vector2(5, -3), Vector2(20, 6)), Color("#111827"))
	draw_rect(Rect2(Vector2(7, -2), Vector2(16, 4)), Color("#9ca3af"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_shield_enemy(color: Color) -> void:
	var bubble_fill := Color(0.22, 0.72, 0.95, 0.08)
	var bubble_outline := Color(0.56, 0.84, 1.0, 0.28)
	if shield_absorb_flash_time > 0.0:
		bubble_fill = Color(0.95, 0.1, 0.08, 0.18)
		bubble_outline = Color(1.0, 0.28, 0.18, 0.72)
	draw_circle(Vector2.ZERO, shield_radius, bubble_fill)
	draw_circle(Vector2.ZERO, shield_radius, bubble_outline, false, 2.0)
	draw_set_transform(Vector2.ZERO, facing_angle, Vector2.ONE)
	draw_rect(Rect2(Vector2(-14, -13), Vector2(28, 26)), Color("#0f172a"))
	draw_rect(Rect2(Vector2(-11, -10), Vector2(22, 20)), color)
	draw_circle(Vector2.ZERO, 9.0, Color("#e0f2fe"))
	draw_circle(Vector2.ZERO, 9.0, Color("#0f172a"), false, 2.0)
	draw_line(Vector2(0, -13), Vector2(0, 13), Color("#bae6fd"), 3.0)
	draw_line(Vector2(-13, 0), Vector2(13, 0), Color("#bae6fd"), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_siege_enemy(color: Color) -> void:
	draw_set_transform(Vector2.ZERO, facing_angle, Vector2.ONE)
	draw_rect(Rect2(Vector2(-24, -16), Vector2(48, 32)), Color("#111827"))
	draw_rect(Rect2(Vector2(-21, -13), Vector2(42, 26)), color)
	draw_rect(Rect2(Vector2(-27, -19), Vector2(54, 6)), Color("#2f3a44"))
	draw_rect(Rect2(Vector2(-27, 13), Vector2(54, 6)), Color("#2f3a44"))
	for tread_x in [-18, -9, 0, 9, 18]:
		draw_line(Vector2(tread_x, -19), Vector2(tread_x - 5, -13), Color("#94a3b8"), 2.0)
		draw_line(Vector2(tread_x, 19), Vector2(tread_x - 5, 13), Color("#94a3b8"), 2.0)
	draw_rect(Rect2(Vector2(-8, -9), Vector2(18, 18)), Color("#7f1d1d"))
	draw_rect(Rect2(Vector2(8, -4), Vector2(25, 8)), Color("#111827"))
	draw_rect(Rect2(Vector2(11, -2), Vector2(18, 4)), Color("#fecaca"))
	draw_circle(Vector2(-14, 0), 5.0, Color("#fee2e2"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_decoy_enemy(color: Color) -> void:
	draw_set_transform(Vector2.ZERO, facing_angle, Vector2.ONE)
	draw_circle(Vector2.ZERO, 18.0, Color("#111827"))
	draw_circle(Vector2.ZERO, 15.0, color)
	draw_circle(Vector2.ZERO, 8.0, Color("#fdf2f8"))
	draw_circle(Vector2.ZERO, 3.0, Color("#831843"))
	draw_line(Vector2(-22, -12), Vector2(-8, -5), Color("#f9a8d4"), 3.0)
	draw_line(Vector2(-22, 12), Vector2(-8, 5), Color("#f9a8d4"), 3.0)
	draw_line(Vector2(8, -5), Vector2(22, -12), Color("#f9a8d4"), 3.0)
	draw_line(Vector2(8, 5), Vector2(22, 12), Color("#f9a8d4"), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_air_enemy(color: Color) -> void:
	draw_circle(Vector2.ZERO, 27.0, Color(0.15, 0.23, 0.42, 0.16))
	draw_set_transform(Vector2.ZERO, facing_angle, Vector2.ONE)
	var body := PackedVector2Array([Vector2(18, 0), Vector2(8, -11), Vector2(-15, -9), Vector2(-19, 0), Vector2(-15, 9), Vector2(8, 11)])
	draw_colored_polygon(body, color)
	draw_polyline(PackedVector2Array([Vector2(18, 0), Vector2(8, -11), Vector2(-15, -9), Vector2(-19, 0), Vector2(-15, 9), Vector2(8, 11), Vector2(18, 0)]), Color("#111827"), 2.0)
	draw_line(Vector2(-28, 0), Vector2(28, 0), Color("#e0f2fe"), 4.0)
	draw_line(Vector2(0, -20), Vector2(0, 20), Color("#e0f2fe"), 4.0)
	draw_circle(Vector2.ZERO, 7.0, Color("#0f172a"))
	draw_circle(Vector2(13, 0), 4.0, Color("#dcfce7"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
