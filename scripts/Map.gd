extends Node2D

const SLOT_SIZE := Vector2(56, 56)
const PLAYFIELD_WIDTH := 960.0
const MAPS_PATH := "res://data/maps.json"

var maps := []
var current_map_index := 0
var current_map_name := "Map"
var path_points := []
var build_slots := []
var props := []
var hovered_slot_index := -1
var preview_range := 0.0
var preview_valid := true

func _ready() -> void:
	if maps.is_empty():
		load_map_index(current_map_index)
	queue_redraw()

func load_map_index(index: int) -> void:
	_load_maps()
	if maps.is_empty():
		return

	current_map_index = wrapi(index, 0, maps.size())
	var map_data: Dictionary = maps[current_map_index]
	current_map_name = str(map_data.get("name", "Map"))
	path_points = _points_from_arrays(map_data.get("path", []))
	props = map_data.get("props", [])
	_build_slots(_points_from_arrays(map_data.get("pads", [])))
	hovered_slot_index = -1
	preview_range = 0.0
	queue_redraw()

func get_map_count() -> int:
	_load_maps()
	return maps.size()

func get_map_name(index: int = current_map_index) -> String:
	_load_maps()
	if maps.is_empty():
		return "Map"
	var safe_index := wrapi(index, 0, maps.size())
	return str(maps[safe_index].get("name", "Map"))

func _load_maps() -> void:
	if not maps.is_empty():
		return

	var file := FileAccess.open(MAPS_PATH, FileAccess.READ)
	if file == null:
		return
	maps = JSON.parse_string(file.get_as_text())

func _points_from_arrays(points: Array) -> Array:
	var result := []
	for point in points:
		result.append(Vector2(float(point[0]), float(point[1])))
	return result

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("#263238"))
	draw_rect(Rect2(Vector2(960, 0), Vector2(320, 720)), Color("#1b242b"))
	draw_line(Vector2(960, 0), Vector2(960, 720), Color("#111827"), 4.0)

	for x in range(0, 1280, 80):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color("#31424a"), 1.0)
	for y in range(0, 720, 80):
		draw_line(Vector2(0, y), Vector2(1280, y), Color("#31424a"), 1.0)

	_draw_industrial_props()

	for i in range(path_points.size() - 1):
		draw_line(path_points[i], path_points[i + 1], Color("#4b5563"), 72.0)
		draw_line(path_points[i], path_points[i + 1], Color("#2f3a44"), 48.0)
		draw_line(path_points[i], path_points[i + 1], Color("#f5c542"), 2.0)
		_draw_road_ticks(path_points[i], path_points[i + 1])

	for slot in build_slots:
		var color := Color("#3f6b4f") if not slot["occupied"] else Color("#6b7280")
		var width := 2.0
		if slot["index"] == hovered_slot_index and not slot["occupied"]:
			color = Color("#8bd36b")
			width = 4.0
		draw_rect(Rect2(slot["center"] - SLOT_SIZE * 0.5, SLOT_SIZE), color, false, width)
		draw_rect(Rect2(slot["center"] - Vector2(18, 18), Vector2(36, 36)), Color("#1f2933"), false, 1.0)

	if hovered_slot_index >= 0 and preview_range > 0.0:
		var center := _get_slot_center(hovered_slot_index)
		var preview_color := Color(0.45, 0.82, 0.43, 0.16) if preview_valid else Color(1.0, 0.25, 0.25, 0.16)
		var outline_color := Color(0.55, 0.93, 0.45, 0.55) if preview_valid else Color(1.0, 0.3, 0.3, 0.55)
		draw_circle(center, preview_range, preview_color)
		draw_circle(center, preview_range, outline_color, false, 2.0)

	_draw_gate(path_points[0] + Vector2(80, 0), "IN", Color("#38bdf8"))
	_draw_gate(path_points[path_points.size() - 1] - Vector2(80, 0), "OUT", Color("#ef4444"))

func _build_slots(centers: Array) -> void:
	build_slots.clear()
	for i in centers.size():
		build_slots.append({"index": i, "center": centers[i], "occupied": false})

func get_slot_at(global_pos: Vector2) -> Dictionary:
	for slot in build_slots:
		var rect := Rect2(slot["center"] - SLOT_SIZE * 0.5, SLOT_SIZE)
		if rect.has_point(global_pos) and not slot["occupied"]:
			return slot
	return {}

func set_hovered_slot(global_pos: Vector2) -> void:
	var next_hover := -1
	for slot in build_slots:
		var rect := Rect2(slot["center"] - SLOT_SIZE * 0.5, SLOT_SIZE)
		if rect.has_point(global_pos) and not slot["occupied"]:
			next_hover = int(slot["index"])
			break

	if hovered_slot_index != next_hover:
		hovered_slot_index = next_hover
		queue_redraw()

func set_placement_preview(range_value: float, is_valid: bool) -> void:
	if preview_range != range_value or preview_valid != is_valid:
		preview_range = range_value
		preview_valid = is_valid
		queue_redraw()

func occupy_slot(index: int) -> void:
	for slot in build_slots:
		if slot["index"] == index:
			slot["occupied"] = true
			queue_redraw()
			return

func free_slot(index: int) -> void:
	for slot in build_slots:
		if slot["index"] == index:
			slot["occupied"] = false
			queue_redraw()
			return

func _get_slot_center(index: int) -> Vector2:
	for slot in build_slots:
		if slot["index"] == index:
			return slot["center"]
	return Vector2.ZERO

func _draw_industrial_props() -> void:
	for prop in props:
		match str(prop.get("type", "")):
			"warehouse":
				_draw_warehouse(
					Rect2(Vector2(float(prop["x"]), float(prop["y"])), Vector2(float(prop["w"]), float(prop["h"]))),
					Color(str(prop.get("color", "#4b5563")))
				)
			"tank":
				_draw_tank(Vector2(float(prop["x"]), float(prop["y"])), float(prop["r"]), Color(str(prop.get("color", "#77838d"))))
			"pipe":
				_draw_pipe_run(_points_from_arrays(prop.get("points", [])))
			"barrier":
				_draw_barrier(Vector2(float(prop["x"]), float(prop["y"])))

func _draw_warehouse(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)
	draw_rect(rect, Color("#172026"), false, 3.0)
	for x in range(int(rect.position.x + 18), int(rect.end.x - 12), 28):
		draw_line(Vector2(x, rect.position.y + 8), Vector2(x + 14, rect.end.y - 8), Color("#64727e"), 2.0)
	var door := Rect2(Vector2(rect.position.x + rect.size.x - 46, rect.end.y - 34), Vector2(30, 26))
	draw_rect(door, Color("#27343c"))
	draw_rect(door, Color("#111827"), false, 2.0)

func _draw_tank(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, color)
	draw_circle(center, radius, Color("#172026"), false, 3.0)
	draw_circle(center, radius * 0.55, Color("#596672"), false, 2.0)
	draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), Color("#4b5563"), 2.0)

func _draw_pipe_run(points: Array) -> void:
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], Color("#111827"), 12.0)
		draw_line(points[i], points[i + 1], Color("#8b9aa5"), 7.0)
		draw_line(points[i], points[i + 1], Color("#cbd5e1"), 2.0)

func _draw_barrier(pos: Vector2) -> void:
	var rect := Rect2(pos - Vector2(18, 8), Vector2(36, 16))
	draw_rect(rect, Color("#f5c542"))
	draw_rect(rect, Color("#111827"), false, 2.0)
	draw_line(rect.position + Vector2(4, 13), rect.position + Vector2(14, 3), Color("#111827"), 3.0)
	draw_line(rect.position + Vector2(20, 13), rect.position + Vector2(30, 3), Color("#111827"), 3.0)

func _draw_road_ticks(start: Vector2, end: Vector2) -> void:
	var segment := end - start
	var length := segment.length()
	if length <= 0.0:
		return
	var direction := segment.normalized()
	var normal := Vector2(-direction.y, direction.x)
	for distance in range(42, int(length), 72):
		var center := start + direction * float(distance)
		draw_line(center - normal * 10.0, center + normal * 10.0, Color("#f8fafc"), 2.0)

func _draw_gate(pos: Vector2, label: String, color: Color) -> void:
	draw_circle(pos, 26.0, color)
	draw_circle(pos, 26.0, Color("#111827"), false, 3.0)
	draw_string(ThemeDB.fallback_font, pos + Vector2(-15, 5), label, HORIZONTAL_ALIGNMENT_CENTER, 30, 13, Color("#111827"))
