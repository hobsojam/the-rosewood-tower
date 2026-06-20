extends Node

signal enemy_died(reward: int)
signal enemy_reached_exit(breach_damage: int)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal all_waves_completed

const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")

var path_points := []
var enemy_data := {}
var waves := []
var current_wave := -1
var total_waves := 0
var active_enemies := 0
var queued_enemies := 0
var queued_enemy_counts := {}
var spawning := false
var game_over := false
var completed_wave_index := -1

func _ready() -> void:
	_load_data()

func start_next_wave() -> bool:
	if game_over or spawning or active_enemies > 0:
		return false

	if current_wave + 1 >= waves.size():
		return false

	current_wave += 1
	spawning = true
	wave_started.emit(current_wave + 1)
	_spawn_wave(_get_wave_counts(current_wave))
	return true

func stop_game() -> void:
	game_over = true
	spawning = false

func _load_data() -> void:
	var enemy_file := FileAccess.open("res://data/enemies.json", FileAccess.READ)
	enemy_data = JSON.parse_string(enemy_file.get_as_text())

	var wave_file := FileAccess.open("res://data/waves.json", FileAccess.READ)
	waves = JSON.parse_string(wave_file.get_as_text())
	total_waves = waves.size()

func _spawn_wave(wave: Dictionary) -> void:
	var queue := _build_spawn_queue(wave)

	queued_enemies = queue.size()
	queued_enemy_counts = _count_queue(queue)
	for enemy_id in queue:
		if game_over:
			break
		_spawn_enemy(enemy_id)
		queued_enemies = max(queued_enemies - 1, 0)
		queued_enemy_counts[enemy_id] = max(int(queued_enemy_counts.get(enemy_id, 0)) - 1, 0)
		await get_tree().create_timer(0.55).timeout

	spawning = false
	queued_enemies = 0
	queued_enemy_counts = {}
	_check_wave_completion()

func _build_spawn_queue(wave: Dictionary) -> Array:
	var remaining := {}
	for enemy_id in enemy_data.keys():
		remaining[enemy_id] = int(wave.get(enemy_id, 0))
	var order := ["standard", "fast", "air", "decoy", "shield", "standard", "armored", "siege"]
	for enemy_id in remaining.keys():
		if not order.has(enemy_id):
			order.append(enemy_id)
	var queue := []

	while _has_queued_enemy(remaining):
		for enemy_id in order:
			if int(remaining.get(enemy_id, 0)) > 0:
				queue.append(enemy_id)
				remaining[enemy_id] -= 1

	return queue

func _has_queued_enemy(remaining: Dictionary) -> bool:
	for count in remaining.values():
		if int(count) > 0:
			return true
	return false

func _count_queue(queue: Array) -> Dictionary:
	var counts := {}
	for enemy_id in queue:
		counts[enemy_id] = int(counts.get(enemy_id, 0)) + 1
	return counts

func _spawn_enemy(enemy_id: String) -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.configure(enemy_id, enemy_data[enemy_id], path_points)
	enemy.died.connect(_on_enemy_died)
	enemy.reached_exit.connect(_on_enemy_reached_exit)
	get_tree().current_scene.add_child(enemy)
	active_enemies += 1

func _on_enemy_died(reward: int) -> void:
	active_enemies = max(active_enemies - 1, 0)
	enemy_died.emit(reward)
	_check_wave_completion()

func _on_enemy_reached_exit(breach_damage: int) -> void:
	active_enemies = max(active_enemies - 1, 0)
	enemy_reached_exit.emit(breach_damage)
	_check_wave_completion()

func _check_wave_completion() -> void:
	active_enemies = max(active_enemies, 0)
	queued_enemies = max(queued_enemies, 0)
	if spawning or game_over:
		return

	call_deferred("_finish_wave_if_clear")

func _finish_wave_if_clear() -> void:
	if spawning or game_over or queued_enemies > 0 or _get_live_enemy_count() > 0:
		return

	if current_wave >= 0 and completed_wave_index != current_wave:
		completed_wave_index = current_wave
		wave_completed.emit(current_wave + 1)

	if current_wave + 1 >= waves.size():
		game_over = true
		all_waves_completed.emit()

func get_remaining_enemies() -> int:
	return max(_get_live_enemy_count() + queued_enemies, 0)

func get_queued_enemy_count(enemy_id: String) -> int:
	return int(queued_enemy_counts.get(enemy_id, 0))

func _get_live_enemy_count() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			count += 1
	return count

func get_next_wave_summary() -> String:
	var wave: Dictionary = get_next_wave_counts()
	if wave.is_empty():
		return "None"

	var parts := []
	for enemy_id in ["standard", "fast", "air", "decoy", "shield", "armored", "siege"]:
		var count := int(wave.get(enemy_id, 0))
		if count > 0:
			parts.append("%s %s" % [count, enemy_id])
	return ", ".join(parts)

func get_next_wave_counts() -> Dictionary:
	var next_index := current_wave + 1
	if next_index >= waves.size():
		return {}
	return _get_wave_counts(next_index)

func get_current_wave_counts() -> Dictionary:
	if current_wave < 0 or current_wave >= waves.size():
		return {}
	return _get_wave_counts(current_wave)

func get_next_wave_name() -> String:
	var next_index := current_wave + 1
	if next_index >= waves.size():
		return "None"
	return _get_wave_name(next_index)

func get_current_wave_name() -> String:
	if current_wave < 0 or current_wave >= waves.size():
		return "None"
	return _get_wave_name(current_wave)

func _get_wave_counts(wave_index: int) -> Dictionary:
	var wave: Dictionary = waves[wave_index]
	return wave.get("enemies", wave)

func _get_wave_name(wave_index: int) -> String:
	var wave: Dictionary = waves[wave_index]
	return str(wave.get("name", "Wave %s" % [wave_index + 1]))
