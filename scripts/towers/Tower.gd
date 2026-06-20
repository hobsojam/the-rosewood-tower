extends Node2D

const PROJECTILE_SCENE := preload("res://scenes/projectiles/Projectile.tscn")
const RAIL_BEAM_SCRIPT := preload("res://scripts/effects/RailBeam.gd")
const TARGETING_MODES := ["nearest", "first", "last", "strongest", "weakest"]
const TARGETING_LABELS := {
	"nearest": "Nearest",
	"first": "First",
	"last": "Last",
	"strongest": "Strongest",
	"weakest": "Weakest"
}

var tower_id := "basic"
var display_name := "Tower"
var damage := 10.0
var attack_range := 120.0
var fire_rate := 0.5
var splash_radius := 0.0
var slow := 0.0
var pierce_width := 0.0
var damage_tags: Array[String] = []
var body_color := Color("#f5c542")
var cooldown := 0.0
var cost := 0
var slot_index := -1
var upgrade_level := 1
var selected := false
var aim_angle := 0.0
var targeting_mode := "nearest"

func _ready() -> void:
	queue_redraw()

func configure(id: String, data: Dictionary) -> void:
	tower_id = id
	display_name = data["name"]
	damage = float(data["damage"])
	attack_range = float(data["range"])
	fire_rate = float(data["fire_rate"])
	splash_radius = float(data["splash_radius"])
	slow = float(data["slow"])
	pierce_width = float(data.get("pierce_width", 0.0))
	damage_tags = _to_string_array(data.get("tags", []))
	body_color = Color.html(str(data["color"]))
	cost = int(data["cost"])

func _to_string_array(values: Array) -> Array[String]:
	var strings: Array[String] = []
	for value in values:
		strings.append(str(value))
	return strings

func _process(delta: float) -> void:
	cooldown -= delta
	var target: Node2D = _find_target()
	if target != null:
		aim_angle = global_position.angle_to_point(target.global_position)
		queue_redraw()

	if cooldown > 0.0:
		return

	if target != null:
		_fire_at(target)
		cooldown = fire_rate

func _find_target() -> Node2D:
	var best_target: Node2D = null
	var best_score := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if not _can_target_enemy(enemy_node):
			continue
		var distance := global_position.distance_to(enemy_node.global_position)
		if distance > attack_range:
			continue
		var score := _get_target_score(enemy_node, distance)
		if score < best_score:
			best_score = score
			best_target = enemy_node
	return best_target

func _can_target_enemy(enemy: Node2D) -> bool:
	var is_air := _enemy_has_trait(enemy, "air")
	if damage_tags.has("anti_air"):
		return is_air
	if is_air and (damage_tags.has("blast") or damage_tags.has("slow")):
		return false
	return true

func _get_target_score(enemy: Node2D, distance: float) -> float:
	match targeting_mode:
		"first":
			return -_get_enemy_path_progress(enemy)
		"last":
			return _get_enemy_path_progress(enemy)
		"strongest":
			return -_get_enemy_health(enemy)
		"weakest":
			return _get_enemy_health(enemy)
		_:
			return distance

func _get_enemy_path_progress(enemy: Node2D) -> float:
	if enemy.has_method("get_path_progress"):
		return float(enemy.get_path_progress())
	return 0.0

func _get_enemy_health(enemy: Node2D) -> float:
	return float(enemy.get("health"))

func _enemy_has_trait(enemy: Node2D, enemy_trait: String) -> bool:
	var enemy_traits: Array = enemy.get("traits")
	return enemy_traits.has(enemy_trait)

func cycle_targeting_mode() -> void:
	var current_index := TARGETING_MODES.find(targeting_mode)
	targeting_mode = TARGETING_MODES[wrapi(current_index + 1, 0, TARGETING_MODES.size())]

func get_targeting_label() -> String:
	return str(TARGETING_LABELS.get(targeting_mode, "Nearest"))

func get_upgrade_cost() -> int:
	return int(round(cost * (0.75 + (upgrade_level - 1) * 0.35)))

func get_sell_value() -> int:
	return int(round(cost * 0.6))

func upgrade(path_id: String) -> void:
	var paid_cost := get_upgrade_cost()
	upgrade_level += 1
	_apply_upgrade_path(path_id)
	cost += paid_cost
	queue_redraw()

func apply_match_bonus(effect: Dictionary) -> void:
	damage *= float(effect.get("damage_multiplier", 1.0))
	attack_range += float(effect.get("range_bonus", 0.0))
	fire_rate = max(fire_rate * float(effect.get("fire_rate_multiplier", 1.0)), 0.12)
	splash_radius += float(effect.get("splash_bonus", 0.0))
	slow = min(slow + float(effect.get("slow_bonus", 0.0)), 0.82)
	pierce_width += float(effect.get("pierce_bonus", 0.0))
	queue_redraw()

func get_upgrade_options() -> Array:
	match tower_id:
		"aaa":
			return [
				{"id": "a", "name": "Tracking", "description": "Faster flak tracking."},
				{"id": "b", "name": "Ceiling", "description": "Longer anti-air range."}
			]
		"railgun":
			return [
				{"id": "a", "name": "Capacitor", "description": "More rail damage."},
				{"id": "b", "name": "Bore", "description": "Wider piercing beam."}
			]
		"slow":
			return [
				{"id": "a", "name": "Sticky", "description": "Stronger slow compound."},
				{"id": "b", "name": "Wide", "description": "Longer foam spray range."}
			]
		"splash":
			return [
				{"id": "a", "name": "Heavy", "description": "Higher shell damage."},
				{"id": "b", "name": "Blast", "description": "Larger explosion radius."}
			]
		_:
			return [
				{"id": "a", "name": "Rapid", "description": "Faster rivet feed."},
				{"id": "b", "name": "Sharp", "description": "Higher rivet damage."}
			]

func get_stats_summary() -> String:
	match tower_id:
		"railgun":
			return "Damage %.0f | Beam %.0f | Range %.0f" % [damage, pierce_width, attack_range]
		"aaa":
			return "Damage %.0f | Rate %.2fs | Range %.0f" % [damage, fire_rate, attack_range]
		"slow":
			return "Damage %.0f | Slow %.0f%% | Range %.0f" % [damage, slow * 100.0, attack_range]
		"splash":
			return "Damage %.0f | Blast %.0f | Range %.0f" % [damage, splash_radius, attack_range]
		_:
			return "Damage %.0f | Rate %.2fs | Range %.0f" % [damage, fire_rate, attack_range]

func _apply_upgrade_path(path_id: String) -> void:
	match tower_id:
		"aaa":
			_apply_aaa_upgrade(path_id)
		"railgun":
			_apply_railgun_upgrade(path_id)
		"slow":
			_apply_foam_upgrade(path_id)
		"splash":
			_apply_mortar_upgrade(path_id)
		_:
			_apply_rivet_upgrade(path_id)

func _apply_rivet_upgrade(path_id: String) -> void:
	if path_id == "a":
		fire_rate = max(fire_rate * 0.82, 0.18)
		damage *= 1.05
	else:
		damage *= 1.24
		attack_range += 4.0

func _apply_foam_upgrade(path_id: String) -> void:
	if path_id == "a":
		slow = min(slow + 0.12, 0.78)
		damage *= 1.08
	else:
		attack_range += 26.0
		fire_rate = max(fire_rate * 0.9, 0.26)

func _apply_mortar_upgrade(path_id: String) -> void:
	if path_id == "a":
		damage *= 1.48
		fire_rate = max(fire_rate * 0.98, 0.75)
	else:
		splash_radius += 28.0
		damage *= 1.12
	attack_range += 8.0

func _apply_railgun_upgrade(path_id: String) -> void:
	if path_id == "a":
		damage *= 1.42
		fire_rate = max(fire_rate * 0.96, 1.0)
	else:
		pierce_width += 7.0
		attack_range += 18.0
		damage *= 1.12

func _apply_aaa_upgrade(path_id: String) -> void:
	if path_id == "a":
		fire_rate = max(fire_rate * 0.72, 0.18)
		damage *= 1.08
	else:
		attack_range += 28.0
		damage *= 1.16

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func _fire_at(target) -> void:
	if tower_id == "railgun":
		_fire_railgun_at(target)
		return

	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.configure(target, damage, splash_radius, slow, body_color, damage_tags)
	projectile.global_position = global_position
	get_tree().current_scene.add_child(projectile)
	var audio_manager := get_tree().current_scene.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("play"):
		audio_manager.play("tower_fire")

func _fire_railgun_at(target: Node2D) -> void:
	var direction: Vector2 = target.global_position - global_position
	if direction.is_zero_approx():
		return

	var beam_start := global_position
	var beam_end := global_position + direction.normalized() * attack_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if global_position.distance_to(enemy_node.global_position) > attack_range + pierce_width:
			continue
		if _distance_to_segment(enemy_node.global_position, beam_start, beam_end) <= pierce_width:
			if enemy_node.has_method("take_damage"):
				enemy_node.take_damage(damage, slow, 1.2, damage_tags)

	_show_rail_beam(beam_end)
	var audio_manager := get_tree().current_scene.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("play"):
		audio_manager.play("tower_fire")

func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment: Vector2 = segment_end - segment_start
	var segment_length_squared: float = segment.length_squared()
	if is_zero_approx(segment_length_squared):
		return point.distance_to(segment_start)

	var offset: Vector2 = point - segment_start
	var t: float = clamp(offset.dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest: Vector2 = segment_start + segment * t
	return point.distance_to(closest)

func _show_rail_beam(beam_end: Vector2) -> void:
	var beam := Node2D.new()
	beam.set_script(RAIL_BEAM_SCRIPT)
	beam.global_position = global_position
	beam.beam_end = beam_end - global_position
	beam.beam_color = body_color
	get_tree().current_scene.add_child(beam)

func _draw() -> void:
	if selected:
		draw_circle(Vector2.ZERO, attack_range, Color(1.0, 1.0, 1.0, 0.08))
		draw_circle(Vector2.ZERO, 24.0, Color("#f8fafc"), false, 3.0)
	match tower_id:
		"aaa":
			_draw_aaa_tower()
		"railgun":
			_draw_railgun_tower()
		"slow":
			_draw_foam_tower()
		"splash":
			_draw_mortar_tower()
		_:
			_draw_rivet_tower()
	draw_string(ThemeDB.fallback_font, Vector2(-5, 6), str(upgrade_level), HORIZONTAL_ALIGNMENT_CENTER, 10, 12, Color("#111827"))

func _draw_rivet_tower() -> void:
	draw_circle(Vector2.ZERO, 19.0, body_color)
	draw_circle(Vector2.ZERO, 19.0, Color("#111827"), false, 3.0)
	draw_set_transform(Vector2.ZERO, aim_angle, Vector2.ONE)
	draw_rect(Rect2(Vector2(4, -5), Vector2(28, 10)), Color("#111827"))
	draw_rect(Rect2(Vector2(6, -3), Vector2(23, 6)), Color("#9ca3af"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 8.0, Color("#f8fafc"))

func _draw_foam_tower() -> void:
	draw_rect(Rect2(Vector2(-18, -16), Vector2(36, 32)), body_color)
	draw_rect(Rect2(Vector2(-18, -16), Vector2(36, 32)), Color("#111827"), false, 3.0)
	draw_circle(Vector2(-7, 0), 6.0, Color("#ecfeff"))
	draw_circle(Vector2(7, 0), 6.0, Color("#ecfeff"))
	draw_set_transform(Vector2.ZERO, aim_angle, Vector2.ONE)
	draw_rect(Rect2(Vector2(8, -4), Vector2(24, 8)), Color("#164e63"))
	draw_circle(Vector2(34, 0), 5.0, Color("#67e8f9"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_mortar_tower() -> void:
	draw_circle(Vector2.ZERO, 20.0, body_color)
	draw_circle(Vector2.ZERO, 20.0, Color("#111827"), false, 3.0)
	draw_rect(Rect2(Vector2(-13, 8), Vector2(26, 8)), Color("#111827"))
	draw_set_transform(Vector2.ZERO, aim_angle - 0.45, Vector2.ONE)
	draw_rect(Rect2(Vector2(0, -8), Vector2(30, 16)), Color("#111827"))
	draw_rect(Rect2(Vector2(3, -5), Vector2(24, 10)), Color("#9ca3af"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 7.0, Color("#fecdd3"))

func _draw_railgun_tower() -> void:
	draw_rect(Rect2(Vector2(-17, -17), Vector2(34, 34)), Color("#111827"))
	draw_rect(Rect2(Vector2(-14, -14), Vector2(28, 28)), body_color)
	draw_circle(Vector2.ZERO, 8.0, Color("#f8fafc"))
	draw_set_transform(Vector2.ZERO, aim_angle, Vector2.ONE)
	draw_rect(Rect2(Vector2(0, -5), Vector2(34, 10)), Color("#111827"))
	draw_rect(Rect2(Vector2(4, -3), Vector2(27, 6)), Color("#c4b5fd"))
	draw_line(Vector2(8, -8), Vector2(28, -8), Color("#f8fafc"), 2.0)
	draw_line(Vector2(8, 8), Vector2(28, 8), Color("#f8fafc"), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_aaa_tower() -> void:
	draw_circle(Vector2.ZERO, 19.0, body_color)
	draw_circle(Vector2.ZERO, 19.0, Color("#111827"), false, 3.0)
	draw_rect(Rect2(Vector2(-15, 9), Vector2(30, 8)), Color("#111827"))
	draw_set_transform(Vector2.ZERO, aim_angle, Vector2.ONE)
	draw_rect(Rect2(Vector2(4, -8), Vector2(30, 6)), Color("#111827"))
	draw_rect(Rect2(Vector2(4, 2), Vector2(30, 6)), Color("#111827"))
	draw_circle(Vector2(36, -5), 3.5, Color("#dcfce7"))
	draw_circle(Vector2(36, 5), 3.5, Color("#dcfce7"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 7.0, Color("#f0fdf4"))
