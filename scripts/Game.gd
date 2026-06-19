extends Node2D

const MAP_SCENE := preload("res://scenes/Map.tscn")
const TOWER_SCENE := preload("res://scenes/towers/Tower.tscn")
const WAVE_MANAGER_SCRIPT := preload("res://scripts/WaveManager.gd")
const AUDIO_MANAGER_SCRIPT := preload("res://scripts/AudioManager.gd")
const UI_X := 976.0
const UI_WIDTH := 288.0

var money := 130
var lives := 20
var selected_tower_id := "basic"
var tower_data := {}
var placed_towers: Array[Node2D] = []
var selected_tower: Node2D
var game_speed := 1.0
var game_paused := false
var game_started := false
var selected_map_index := 0

var map
var wave_manager
var audio_manager
var hud_layer: CanvasLayer
var hud_panel: PanelContainer
var selection_panel: PanelContainer
var settings_panel: PanelContainer
var overlay_panel: PanelContainer
var title_panel: PanelContainer
var banner_label: Label
var breach_flash: ColorRect
var money_label: Label
var lives_label: Label
var wave_label: Label
var enemies_label: Label
var next_wave_label: Label
var speed_label: Label
var status_label: Label
var selected_tower_label: Label
var overlay_title_label: Label
var map_label: Label
var next_map_button: Button
var start_button: Button
var restart_button: Button
var menu_button: Button
var settings_button: Button
var pause_button: Button
var speed_1x_button: Button
var speed_2x_button: Button
var targeting_button: Button
var upgrade_a_button: Button
var upgrade_b_button: Button
var sell_button: Button
var mute_button: CheckBox
var volume_slider: HSlider
var volume_label: Label
var tower_buttons := {}
var next_wave_count_labels := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_tower_data()
	_create_map()
	_create_wave_manager()
	_create_audio_manager()
	_create_hud()
	_update_hud()

func _process(_delta: float) -> void:
	if map != null:
		map.set_hovered_slot(get_global_mouse_position())
		_update_placement_preview()
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if not game_started:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_pointer_over_ui():
			return

		var clicked_tower := _get_tower_at(get_global_mouse_position())
		if clicked_tower != null:
			_select_placed_tower(clicked_tower)
		else:
			_try_place_tower(get_global_mouse_position())

func _load_tower_data() -> void:
	var file := FileAccess.open("res://data/towers.json", FileAccess.READ)
	tower_data = JSON.parse_string(file.get_as_text())

func _create_map() -> void:
	map = MAP_SCENE.instantiate()
	map.load_map_index(selected_map_index)
	add_child(map)

func _create_wave_manager() -> void:
	wave_manager = Node.new()
	wave_manager.name = "WaveManager"
	wave_manager.set_script(WAVE_MANAGER_SCRIPT)
	wave_manager.path_points = map.path_points
	add_child(wave_manager)
	wave_manager.enemy_died.connect(_on_enemy_died)
	wave_manager.enemy_reached_exit.connect(_on_enemy_reached_exit)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.all_waves_completed.connect(_on_all_waves_completed)

func _create_audio_manager() -> void:
	audio_manager = Node.new()
	audio_manager.name = "AudioManager"
	audio_manager.set_script(AUDIO_MANAGER_SCRIPT)
	add_child(audio_manager)

func _create_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	hud_panel = PanelContainer.new()
	hud_panel.position = Vector2(UI_X, 16)
	hud_panel.custom_minimum_size = Vector2(UI_WIDTH, 688)
	hud_layer.add_child(hud_panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(UI_WIDTH, 688)
	hud_panel.add_child(scroll)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	scroll.add_child(layout)

	money_label = Label.new()
	lives_label = Label.new()
	wave_label = Label.new()
	enemies_label = Label.new()
	next_wave_label = Label.new()
	speed_label = Label.new()
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(money_label)
	layout.add_child(lives_label)
	layout.add_child(wave_label)
	layout.add_child(enemies_label)
	layout.add_child(next_wave_label)
	var next_wave_row := GridContainer.new()
	next_wave_row.columns = 3
	next_wave_row.add_theme_constant_override("h_separation", 8)
	next_wave_row.add_theme_constant_override("v_separation", 2)
	layout.add_child(next_wave_row)
	for enemy_id in ["standard", "fast", "decoy", "shield", "armored", "siege"]:
		var label := Label.new()
		label.text = "%s: 0" % _get_enemy_icon(enemy_id)
		next_wave_row.add_child(label)
		next_wave_count_labels[enemy_id] = label
	layout.add_child(speed_label)

	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 6)
	layout.add_child(speed_row)

	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.toggle_mode = true
	pause_button.pressed.connect(_on_pause_pressed)
	speed_row.add_child(pause_button)

	speed_1x_button = Button.new()
	speed_1x_button.text = "1x"
	speed_1x_button.toggle_mode = true
	speed_1x_button.pressed.connect(_on_speed_pressed.bind(1.0))
	speed_row.add_child(speed_1x_button)

	speed_2x_button = Button.new()
	speed_2x_button.text = "2x"
	speed_2x_button.toggle_mode = true
	speed_2x_button.pressed.connect(_on_speed_pressed.bind(2.0))
	speed_row.add_child(speed_2x_button)

	layout.add_child(status_label)

	var button_grid := GridContainer.new()
	button_grid.columns = 2
	button_grid.add_theme_constant_override("h_separation", 6)
	button_grid.add_theme_constant_override("v_separation", 6)
	layout.add_child(button_grid)

	for tower_id in ["basic", "slow", "splash", "railgun"]:
		var button := Button.new()
		button.text = "%s $%s" % [_get_short_tower_name(tower_id), tower_data[tower_id]["cost"]]
		button.toggle_mode = true
		button.pressed.connect(_on_tower_type_selected.bind(tower_id))
		button_grid.add_child(button)
		tower_buttons[tower_id] = button

	start_button = Button.new()
	start_button.text = "Start Wave"
	start_button.pressed.connect(_on_start_wave_pressed)
	layout.add_child(start_button)

	var menu_row := HBoxContainer.new()
	menu_row.add_theme_constant_override("separation", 6)
	layout.add_child(menu_row)

	restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.pressed.connect(_on_restart_pressed)
	menu_row.add_child(restart_button)

	menu_button = Button.new()
	menu_button.text = "Menu"
	menu_button.pressed.connect(_on_menu_pressed)
	menu_row.add_child(menu_button)

	settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.toggle_mode = true
	settings_button.pressed.connect(_on_settings_pressed)
	layout.add_child(settings_button)

	_create_settings_panel(layout)
	_create_selection_panel(layout)
	_create_overlay_panel()
	_create_title_panel()
	_create_feedback_overlays()
	tower_buttons[selected_tower_id].button_pressed = true
	speed_1x_button.button_pressed = true

func _create_feedback_overlays() -> void:
	breach_flash = ColorRect.new()
	breach_flash.color = Color(0.95, 0.1, 0.08, 0.0)
	breach_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breach_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(breach_flash)

	banner_label = Label.new()
	banner_label.position = Vector2(250, 118)
	banner_label.custom_minimum_size = Vector2(460, 56)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.visible = false
	hud_layer.add_child(banner_label)

func _create_selection_panel(parent: VBoxContainer) -> void:
	selection_panel = PanelContainer.new()
	selection_panel.custom_minimum_size = Vector2(UI_WIDTH, 176)
	parent.add_child(selection_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	selection_panel.add_child(layout)

	selected_tower_label = Label.new()
	selected_tower_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(selected_tower_label)

	targeting_button = Button.new()
	targeting_button.pressed.connect(_on_targeting_pressed)
	layout.add_child(targeting_button)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 6)
	layout.add_child(button_row)

	upgrade_a_button = Button.new()
	upgrade_a_button.pressed.connect(_on_upgrade_pressed.bind("a"))
	button_row.add_child(upgrade_a_button)

	upgrade_b_button = Button.new()
	upgrade_b_button.pressed.connect(_on_upgrade_pressed.bind("b"))
	button_row.add_child(upgrade_b_button)

	sell_button = Button.new()
	sell_button.text = "Sell"
	sell_button.pressed.connect(_on_sell_pressed)
	button_row.add_child(sell_button)

	selection_panel.visible = false

func _create_settings_panel(parent: VBoxContainer) -> void:
	settings_panel = PanelContainer.new()
	settings_panel.custom_minimum_size = Vector2(UI_WIDTH, 124)
	parent.add_child(settings_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	settings_panel.add_child(layout)

	volume_label = Label.new()
	layout.add_child(volume_label)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = audio_manager.get_master_volume()
	volume_slider.value_changed.connect(_on_volume_changed)
	layout.add_child(volume_slider)

	mute_button = CheckBox.new()
	mute_button.text = "Mute"
	mute_button.button_pressed = audio_manager.is_muted()
	mute_button.toggled.connect(_on_mute_toggled)
	layout.add_child(mute_button)

	settings_panel.visible = false

func _create_overlay_panel() -> void:
	overlay_panel = PanelContainer.new()
	overlay_panel.position = Vector2(280, 250)
	overlay_panel.custom_minimum_size = Vector2(400, 180)
	overlay_panel.visible = false
	hud_layer.add_child(overlay_panel)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 12)
	overlay_panel.add_child(layout)

	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	overlay_title_label = title

	var restart_button := Button.new()
	restart_button.text = "Restart"
	restart_button.pressed.connect(_on_restart_pressed)
	layout.add_child(restart_button)

	var menu_button := Button.new()
	menu_button.text = "Main Menu"
	menu_button.pressed.connect(_on_menu_pressed)
	layout.add_child(menu_button)

func _create_title_panel() -> void:
	title_panel = PanelContainer.new()
	title_panel.position = Vector2(270, 190)
	title_panel.custom_minimum_size = Vector2(420, 260)
	hud_layer.add_child(title_panel)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 12)
	title_panel.add_child(layout)

	var title := Label.new()
	title.text = "The Rosewood Tower"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Hold the line through 10 industrial breach waves."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(subtitle)

	map_label = Label.new()
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(map_label)

	next_map_button = Button.new()
	next_map_button.text = "Change Map"
	next_map_button.pressed.connect(_on_next_map_pressed)
	layout.add_child(next_map_button)

	var start_game_button := Button.new()
	start_game_button.text = "Start Game"
	start_game_button.pressed.connect(_on_start_game_pressed)
	layout.add_child(start_game_button)

	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(_on_quit_pressed)
	layout.add_child(quit_button)

func _get_short_tower_name(tower_id: String) -> String:
	match tower_id:
		"basic":
			return "Rivet"
		"slow":
			return "Foam"
		"splash":
			return "Mortar"
		"railgun":
			return "Rail"
		_:
			return str(tower_data[tower_id]["name"])

func _get_enemy_icon(enemy_id: String) -> String:
	match enemy_id:
		"fast":
			return "D"
		"shield":
			return "S"
		"decoy":
			return "X"
		"armored":
			return "T"
		"siege":
			return "W"
		_:
			return "C"

func _try_place_tower(global_pos: Vector2) -> void:
	if not game_started or wave_manager.game_over:
		return

	var slot: Dictionary = map.get_slot_at(global_pos)
	if slot.is_empty():
		_clear_selected_tower()
		status_label.text = "Select an open build pad."
		return

	var cost := int(tower_data[selected_tower_id]["cost"])
	if money < cost:
		status_label.text = "Need $%s for %s." % [cost, tower_data[selected_tower_id]["name"]]
		return

	var tower = TOWER_SCENE.instantiate()
	tower.configure(selected_tower_id, tower_data[selected_tower_id])
	tower.global_position = slot["center"]
	tower.slot_index = int(slot["index"])
	add_child(tower)
	placed_towers.append(tower)

	map.occupy_slot(tower.slot_index)
	money -= cost
	status_label.text = "Placed %s." % tower_data[selected_tower_id]["name"]
	_select_placed_tower(tower)
	_update_hud()

func _get_tower_at(global_pos: Vector2) -> Node2D:
	for tower in placed_towers:
		if is_instance_valid(tower) and tower.global_position.distance_to(global_pos) <= 28.0:
			return tower
	return null

func _select_placed_tower(tower: Node2D) -> void:
	_clear_selected_tower()
	selected_tower = tower
	selected_tower.set_selected(true)
	status_label.text = "Selected %s." % selected_tower.display_name
	_update_selection_panel()

func _clear_selected_tower() -> void:
	if selected_tower != null and is_instance_valid(selected_tower):
		selected_tower.set_selected(false)
	selected_tower = null
	selection_panel.visible = false

func _update_selection_panel() -> void:
	if selected_tower == null or not is_instance_valid(selected_tower):
		selection_panel.visible = false
		return

	var upgrade_cost: int = selected_tower.get_upgrade_cost()
	var sell_value: int = selected_tower.get_sell_value()
	selected_tower_label.text = "%s L%s\n%s\nSell $%s" % [
		selected_tower.display_name,
		selected_tower.upgrade_level,
		selected_tower.get_stats_summary(),
		sell_value
	]
	targeting_button.text = "Target: %s" % selected_tower.get_targeting_label()
	targeting_button.disabled = wave_manager.game_over
	var upgrade_options: Array = selected_tower.get_upgrade_options()
	upgrade_a_button.text = "%s $%s" % [upgrade_options[0]["name"], upgrade_cost]
	upgrade_b_button.text = "%s $%s" % [upgrade_options[1]["name"], upgrade_cost]
	upgrade_a_button.tooltip_text = upgrade_options[0]["description"]
	upgrade_b_button.tooltip_text = upgrade_options[1]["description"]
	upgrade_a_button.disabled = money < upgrade_cost or wave_manager.game_over
	upgrade_b_button.disabled = money < upgrade_cost or wave_manager.game_over
	sell_button.disabled = wave_manager.game_over
	selection_panel.visible = true

func _on_tower_type_selected(tower_id: String) -> void:
	selected_tower_id = tower_id
	for id in tower_buttons:
		tower_buttons[id].button_pressed = id == tower_id
	status_label.text = "Selected build: %s." % tower_data[tower_id]["name"]
	_update_placement_preview()

func _on_upgrade_pressed(path_id: String) -> void:
	if selected_tower == null or not is_instance_valid(selected_tower):
		return

	var upgrade_cost: int = selected_tower.get_upgrade_cost()
	if money < upgrade_cost:
		status_label.text = "Need $%s to upgrade." % upgrade_cost
		return

	money -= upgrade_cost
	selected_tower.upgrade(path_id)
	_play_sound("upgrade")
	status_label.text = "%s upgraded to level %s." % [selected_tower.display_name, selected_tower.upgrade_level]
	_update_hud()

func _on_targeting_pressed() -> void:
	if selected_tower == null or not is_instance_valid(selected_tower):
		return

	selected_tower.cycle_targeting_mode()
	status_label.text = "%s targeting %s." % [selected_tower.display_name, selected_tower.get_targeting_label()]
	_update_selection_panel()

func _on_sell_pressed() -> void:
	if selected_tower == null or not is_instance_valid(selected_tower):
		return

	var sold_tower := selected_tower
	var refund: int = sold_tower.get_sell_value()
	money += refund
	map.free_slot(sold_tower.slot_index)
	placed_towers.erase(sold_tower)
	_clear_selected_tower()
	sold_tower.queue_free()
	_play_sound("sell")
	status_label.text = "Sold tower for $%s." % refund
	_update_hud()

func _on_start_wave_pressed() -> void:
	if not game_started:
		return

	if wave_manager.start_next_wave():
		status_label.text = "Wave in progress."
	else:
		status_label.text = "Wave already active or game finished."
	_update_hud()

func _on_pause_pressed() -> void:
	if not game_started:
		return

	game_paused = not game_paused
	get_tree().paused = game_paused
	status_label.text = "Paused." if game_paused else "Resumed."
	_update_hud()

func _on_speed_pressed(speed: float) -> void:
	if not game_started:
		return

	game_speed = speed
	Engine.time_scale = game_speed
	speed_1x_button.button_pressed = is_equal_approx(game_speed, 1.0)
	speed_2x_button.button_pressed = is_equal_approx(game_speed, 2.0)
	status_label.text = "Speed set to %sx." % int(game_speed)
	_update_hud()

func _on_settings_pressed() -> void:
	settings_panel.visible = not settings_panel.visible
	settings_button.button_pressed = settings_panel.visible
	_update_hud()

func _on_volume_changed(value: float) -> void:
	if audio_manager != null and audio_manager.has_method("set_master_volume"):
		audio_manager.set_master_volume(value)
	_update_hud()

func _on_mute_toggled(button_pressed: bool) -> void:
	if audio_manager != null and audio_manager.has_method("set_muted"):
		audio_manager.set_muted(button_pressed)
	_update_hud()

func _on_enemy_died(reward: int) -> void:
	money += reward
	_play_sound("enemy_death")
	_update_hud()

func _on_enemy_reached_exit(breach_damage: int) -> void:
	lives -= breach_damage
	_play_sound("breach")
	_pulse_breach_flash()
	if lives <= 0:
		lives = 0
		wave_manager.stop_game()
		status_label.text = "City grid breached. Defeat."
		_play_sound("defeat")
		_show_end_overlay("Defeat: city grid breached")
	_update_hud()

func _on_wave_started(_wave_number: int) -> void:
	_play_sound("wave_start")
	_show_banner("Wave %s" % _wave_number, Color("#f5c542"))
	_update_hud()

func _on_wave_completed(_wave_number: int) -> void:
	status_label.text = "Wave cleared. Build or start the next wave."
	_play_sound("wave_clear")
	_show_banner("Wave cleared", Color("#8bd36b"))
	_update_hud()

func _on_all_waves_completed() -> void:
	status_label.text = "Rosewood sector secured. Victory."
	_play_sound("victory")
	_show_banner("District secured", Color("#8bd36b"))
	_show_end_overlay("Victory: district secured")
	_update_hud()

func _show_end_overlay(title_text: String) -> void:
	game_paused = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	game_speed = 1.0
	if overlay_title_label != null:
		overlay_title_label.text = title_text
	overlay_panel.visible = true

func _play_sound(sound_id: String) -> void:
	if audio_manager != null and audio_manager.has_method("play"):
		audio_manager.play(sound_id)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _on_start_game_pressed() -> void:
	game_started = true
	title_panel.visible = false
	status_label.text = "Build defenses, then start wave 1."
	_update_hud()

func _on_next_map_pressed() -> void:
	if game_started:
		return

	selected_map_index = wrapi(selected_map_index + 1, 0, map.get_map_count())
	map.load_map_index(selected_map_index)
	wave_manager.path_points = map.path_points
	_update_hud()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _show_banner(text: String, color: Color) -> void:
	if banner_label == null:
		return

	banner_label.text = text
	banner_label.add_theme_color_override("font_color", color)
	banner_label.visible = true
	banner_label.modulate = Color.WHITE

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(0.75)
	tween.tween_property(banner_label, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func() -> void: banner_label.visible = false)

func _pulse_breach_flash() -> void:
	if breach_flash == null:
		return

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(breach_flash, "color:a", 0.22, 0.05)
	tween.tween_property(breach_flash, "color:a", 0.0, 0.35)

func _is_pointer_over_ui() -> bool:
	var mouse_pos := get_viewport().get_mouse_position()
	for panel in [hud_panel, selection_panel, settings_panel, overlay_panel, title_panel]:
		if panel != null and panel.visible and panel.get_global_rect().has_point(mouse_pos):
			return true
	return false

func _update_placement_preview() -> void:
	if not game_started or wave_manager.game_over:
		map.set_placement_preview(0.0, false)
		return

	var slot: Dictionary = map.get_slot_at(get_global_mouse_position())
	if slot.is_empty():
		map.set_placement_preview(0.0, false)
		return

	var cost := int(tower_data[selected_tower_id]["cost"])
	var range_value := float(tower_data[selected_tower_id]["range"])
	map.set_placement_preview(range_value, money >= cost)

func _update_hud() -> void:
	if not _is_hud_ready():
		return
	money_label.text = "Money: $%s" % money
	lives_label.text = "Lives: %s" % lives
	wave_label.text = "Wave: %s / %s" % [wave_manager.current_wave + 1, wave_manager.total_waves]
	enemies_label.text = "Enemies remaining: %s" % wave_manager.get_remaining_enemies()
	next_wave_label.text = "Next wave:"
	var next_counts: Dictionary = wave_manager.get_next_wave_counts()
	for enemy_id in next_wave_count_labels:
		next_wave_count_labels[enemy_id].text = "%s: %s" % [_get_enemy_icon(enemy_id), int(next_counts.get(enemy_id, 0))]
	speed_label.text = "Speed: paused" if game_paused else "Speed: %sx" % int(game_speed)
	start_button.disabled = not game_started or wave_manager.game_over or wave_manager.spawning or wave_manager.active_enemies > 0
	restart_button.disabled = not game_started
	menu_button.disabled = not game_started
	settings_button.button_pressed = settings_panel.visible
	volume_label.text = "Volume: %s%%" % int(audio_manager.get_master_volume() * 100.0)
	volume_slider.value = audio_manager.get_master_volume()
	mute_button.button_pressed = audio_manager.is_muted()
	if map_label != null:
		map_label.text = "Map: %s" % map.get_map_name(selected_map_index)
	pause_button.button_pressed = game_paused
	pause_button.disabled = not game_started or wave_manager.game_over
	for tower_id in tower_buttons:
		tower_buttons[tower_id].disabled = not game_started or wave_manager.game_over
	_update_selection_panel()

func _is_hud_ready() -> bool:
	return money_label != null \
		and lives_label != null \
		and wave_label != null \
		and enemies_label != null \
		and next_wave_label != null \
		and speed_label != null \
		and start_button != null \
		and restart_button != null \
		and menu_button != null \
		and settings_button != null \
		and volume_label != null \
		and volume_slider != null \
		and mute_button != null \
		and map_label != null \
		and next_map_button != null
