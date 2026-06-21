extends Node2D

const MAP_SCENE := preload("res://scenes/Map.tscn")
const TOWER_SCENE := preload("res://scenes/towers/Tower.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const CODEX_PORTRAIT_SIZE := Vector2i(72, 72)
const WAVE_MANAGER_SCRIPT := preload("res://scripts/WaveManager.gd")
const AUDIO_MANAGER_SCRIPT := preload("res://scripts/AudioManager.gd")
const UI_X := 976.0
const UI_WIDTH := 288.0
const STARTING_LIVES := 12
const MAX_LIVES := 12
const RECENT_BONUS_LIMIT := 2
const TOWER_BONUS_SCALES := [1.0, 0.67, 0.4]
const TOWER_ORDER := ["basic", "slow", "splash", "railgun", "aaa"]
const ENEMY_IDS := ["standard", "fast", "decoy", "repair", "shield", "burrower", "armored", "siege", "air"]
const ENEMY_CODEX := {
	"standard": {"name": "Crawler",        "description": "Baseline unit. Rivets handle it efficiently.",               "counters": ["basic"]},
	"fast":     {"name": "Runner Drone",   "description": "Fast, fragile unit. Catch it with early coverage.",          "counters": ["slow", "basic"]},
	"shield":   {"name": "Shield Carrier", "description": "Protects nearby enemies. Focus the carrier.",                "counters": ["basic", "railgun"]},
	"decoy":    {"name": "Signal Decoy",   "description": "Tough, low-reward distraction. Targeting mode matters.",     "counters": ["basic"]},
	"repair":   {"name": "Repair Drone",   "description": "Repairs nearby enemies. Kill it before armored groups.",     "counters": ["railgun", "basic"]},
	"burrower": {"name": "Tunnel Rig",     "description": "Sprints above ground, then burrows. Mortars handle it best.","counters": ["splash"]},
	"air":      {"name": "Rotor Drone",    "description": "Air threat. Requires AAA coverage.",                         "counters": ["aaa"]},
	"armored":  {"name": "Armored Hauler", "description": "Resists ordinary direct fire. Railguns and blast help.",     "counters": ["railgun", "splash"]},
	"siege":    {"name": "Siege Walker",   "description": "Very tough, slow, and costs 2 lives if it breaches.",        "counters": ["splash", "railgun"]},
}
const TOWER_GUIDE := {
	"basic":   {"name": "Rivet Turret",    "description": "Reliable direct fire. Cost-effective against most threats.", "strong_vs": ["standard", "fast", "decoy", "repair", "shield"]},
	"slow":    {"name": "Foam Sprayer",    "description": "Slows enemies in range. Essential against fast units.",      "strong_vs": ["fast", "siege"]},
	"splash":  {"name": "Foundry Mortar",  "description": "Area blast. Punishes groups, armored, and burrowing units.","strong_vs": ["burrower", "armored", "siege"]},
	"railgun": {"name": "Railgun Spire",   "description": "Pierce fire. Cuts through armor and high-health targets.",  "strong_vs": ["armored", "siege", "shield", "repair"]},
	"aaa":     {"name": "AAA Flak Turret", "description": "Anti-air flak. Required to damage air threats.",            "strong_vs": ["air"]},
}
const INITIAL_UNLOCKED_TOWERS := ["basic"]
const REQUIRED_COUNTER_UNLOCKS := {
	"air": {"id": "unlock_aaa", "name": "AAA Authorization", "description": "Air threat detected. Unlock AAA Flak Turrets.", "unlock_tower_id": "aaa"}
}
const TOWER_UNLOCK_BONUSES := [
	{"id": "unlock_slow", "name": "Foam Blueprints", "description": "Unlock Foam Sprayers.", "unlock_tower_id": "slow"},
	{"id": "unlock_splash", "name": "Mortar Crew", "description": "Unlock Foundry Mortars.", "unlock_tower_id": "splash"},
	{"id": "unlock_railgun", "name": "Rail Schematics", "description": "Unlock Railgun Spires.", "unlock_tower_id": "railgun"}
]
const WAVE_BONUSES := [
	{"id": "budget", "name": "Overtime Budget", "description": "+$75 immediately.", "money": 75},
	{"id": "repairs", "name": "Emergency Repairs", "description": "Recover up to 2 lives.", "lives": 2},
	{"id": "rivet_damage", "name": "Reinforced Rivets", "description": "Rivet towers gain +10% damage.", "tower_id": "basic", "damage_multiplier": 1.1},
	{"id": "foam_reserve", "name": "Foam Reserves", "description": "Foam towers gain stronger slow.", "tower_id": "slow", "slow_bonus": 0.08},
	{"id": "mortar_stock", "name": "Mortar Stockpile", "description": "Mortars gain larger blasts.", "tower_id": "splash", "splash_bonus": 14.0},
	{"id": "rail_calibration", "name": "Rail Calibration", "description": "Railguns gain +18 range.", "tower_id": "railgun", "range_bonus": 18.0}
]

var money := 130
var lives := STARTING_LIVES
var selected_tower_id := "basic"
var tower_data := {}
var placed_towers: Array[Node2D] = []
var selected_tower: Node2D
var game_speed := 1.0
var game_paused := false
var game_started := false
var selected_map_index := 0
var bonus_pending := false
var active_bonus_choices: Array = []
var recent_bonus_ids: Array[String] = []
var tower_bonus_counts := {}
var tower_match_bonuses := {}
var unlocked_tower_ids: Array[String] = ["basic"]

var map
var wave_manager
var audio_manager
var hud_layer: CanvasLayer
var hud_panel: PanelContainer
var bonus_panel: PanelContainer
var bonus_title_label: Label
var bonus_buttons: Array[Button] = []
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
var seen_enemy_ids: Array[String] = []
var codex_panel: PanelContainer
var codex_rows := {}
var codex_row_labels := {}
var codex_row_portraits := {}
var codex_button: Button
var tower_guide_panel: PanelContainer
var tower_guide_row_labels := {}
var tower_guide_button: Button

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
	_update_air_audio()
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
	for enemy_id in ENEMY_IDS:
		var label := Label.new()
		label.text = "%s: 0" % _get_enemy_icon(enemy_id)
		label.mouse_filter = Control.MOUSE_FILTER_STOP
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

	for tower_id in TOWER_ORDER:
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

	codex_button = Button.new()
	codex_button.text = "Field Guide"
	codex_button.toggle_mode = true
	codex_button.pressed.connect(_on_codex_pressed)
	layout.add_child(codex_button)

	tower_guide_button = Button.new()
	tower_guide_button.text = "Tower Guide"
	tower_guide_button.toggle_mode = true
	tower_guide_button.pressed.connect(_on_tower_guide_pressed)
	layout.add_child(tower_guide_button)

	_create_bonus_panel()
	_create_settings_panel(layout)
	_create_selection_panel(layout)
	_create_overlay_panel()
	_create_title_panel()
	_create_feedback_overlays()
	_create_codex_panel()
	_create_tower_guide_panel()
	tower_buttons[selected_tower_id].button_pressed = true
	speed_1x_button.button_pressed = true
	_update_tower_unlocks()

func _create_bonus_panel() -> void:
	bonus_panel = PanelContainer.new()
	bonus_panel.position = Vector2(252, 226)
	bonus_panel.custom_minimum_size = Vector2(456, 230)
	hud_layer.add_child(bonus_panel)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 10)
	bonus_panel.add_child(layout)

	bonus_title_label = Label.new()
	bonus_title_label.text = "City support available"
	bonus_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(bonus_title_label)

	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(420, 46)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_bonus_pressed.bind(index))
		layout.add_child(button)
		bonus_buttons.append(button)

	bonus_panel.visible = false

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

	var overlay_restart_button := Button.new()
	overlay_restart_button.text = "Restart"
	overlay_restart_button.pressed.connect(_on_restart_pressed)
	layout.add_child(overlay_restart_button)

	var overlay_menu_button := Button.new()
	overlay_menu_button.text = "Main Menu"
	overlay_menu_button.pressed.connect(_on_menu_pressed)
	layout.add_child(overlay_menu_button)

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

func _create_codex_panel() -> void:
	codex_panel = PanelContainer.new()
	codex_panel.position = Vector2(178, 30)
	codex_panel.custom_minimum_size = Vector2(620, 0)
	hud_layer.add_child(codex_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	codex_panel.add_child(layout)

	var title := Label.new()
	title.text = "Field Guide"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)

	for enemy_id in ENEMY_IDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		layout.add_child(row)
		codex_rows[enemy_id] = row

		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(CODEX_PORTRAIT_SIZE)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.visible = false
		row.add_child(portrait)
		codex_row_portraits[enemy_id] = portrait

		var viewport := SubViewport.new()
		viewport.size = CODEX_PORTRAIT_SIZE
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		hud_layer.add_child(viewport)
		portrait.texture = viewport.get_texture()

		var portrait_enemy = ENEMY_SCENE.instantiate()
		portrait_enemy.enemy_id = enemy_id
		portrait_enemy.body_color = Color.html(str(wave_manager.enemy_data.get(enemy_id, {}).get("color", "#ffffff")))
		portrait_enemy.finished = true
		portrait_enemy.position = Vector2(CODEX_PORTRAIT_SIZE.x / 2.0, CODEX_PORTRAIT_SIZE.y / 2.0)
		viewport.add_child(portrait_enemy)
		portrait_enemy.remove_from_group("enemies")

		var text := Label.new()
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		codex_row_labels[enemy_id] = text

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_on_codex_pressed)
	layout.add_child(close_button)

	codex_panel.visible = false
	_update_codex_panel()

func _on_codex_pressed() -> void:
	var new_state := not codex_panel.visible
	if new_state and tower_guide_panel.visible:
		tower_guide_panel.visible = false
		tower_guide_button.button_pressed = false
	codex_panel.visible = new_state
	codex_button.button_pressed = new_state

func _update_codex_panel() -> void:
	for enemy_id in codex_row_labels:
		var text: Label = codex_row_labels[enemy_id]
		var portrait: TextureRect = codex_row_portraits[enemy_id]
		if seen_enemy_ids.has(enemy_id):
			var data: Dictionary = ENEMY_CODEX[enemy_id]
			portrait.visible = true
			var counter_names := PackedStringArray()
			for tower_id in data["counters"]:
				counter_names.append(_get_short_tower_name(tower_id))
			text.text = "%s\n%s\nBest: %s" % [data["name"], data["description"], ", ".join(counter_names)]
			next_wave_count_labels[enemy_id].tooltip_text = "%s\n%s" % [data["name"], data["description"]]
		else:
			portrait.visible = false
			text.text = "???"
			next_wave_count_labels[enemy_id].tooltip_text = ""
	var ordered: Array[String] = seen_enemy_ids.duplicate()
	for enemy_id in ENEMY_IDS:
		if not seen_enemy_ids.has(enemy_id):
			ordered.append(enemy_id)
	var layout := codex_rows[ordered[0]].get_parent()
	for i in ordered.size():
		layout.move_child(codex_rows[ordered[i]], i + 1)

func _on_tower_guide_pressed() -> void:
	var new_state := not tower_guide_panel.visible
	if new_state and codex_panel.visible:
		codex_panel.visible = false
		codex_button.button_pressed = false
	tower_guide_panel.visible = new_state
	tower_guide_button.button_pressed = new_state

func _create_tower_guide_panel() -> void:
	tower_guide_panel = PanelContainer.new()
	tower_guide_panel.position = Vector2(178, 30)
	tower_guide_panel.custom_minimum_size = Vector2(500, 0)
	hud_layer.add_child(tower_guide_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	tower_guide_panel.add_child(layout)

	var title := Label.new()
	title.text = "Tower Guide"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)

	for tower_id in TOWER_ORDER:
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.visible = false
		layout.add_child(row)
		tower_guide_row_labels[tower_id] = row

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_on_tower_guide_pressed)
	layout.add_child(close_button)

	tower_guide_panel.visible = false
	_update_tower_guide_panel()

func _update_tower_guide_panel() -> void:
	for tower_id in tower_guide_row_labels:
		var row: Label = tower_guide_row_labels[tower_id]
		if unlocked_tower_ids.has(tower_id):
			var data: Dictionary = TOWER_GUIDE[tower_id]
			var strong_names := PackedStringArray()
			for enemy_id in data["strong_vs"]:
				strong_names.append(ENEMY_CODEX[enemy_id]["name"])
			row.text = "%s\n%s\nStrong vs: %s" % [data["name"], data["description"], ", ".join(strong_names)]
			row.visible = true
		else:
			row.visible = false

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
		"aaa":
			return "AAA"
		_:
			return str(tower_data[tower_id]["name"])

func _get_enemy_icon(enemy_id: String) -> String:
	match enemy_id:
		"standard":
			return "C"
		"fast":
			return "D"
		"shield":
			return "S"
		"decoy":
			return "X"
		"repair":
			return "R"
		"burrower":
			return "B"
		"air":
			return "A"
		"armored":
			return "T"
		"siege":
			return "W"
		_:
			push_warning("_get_enemy_icon: unknown enemy_id '%s'" % enemy_id)
			return "?"


func _try_place_tower(global_pos: Vector2) -> void:
	if not game_started or wave_manager.game_over:
		return
	if not unlocked_tower_ids.has(selected_tower_id):
		status_label.text = "%s is not unlocked." % tower_data[selected_tower_id]["name"]
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
	_apply_stored_bonuses_to_tower(tower)
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
	if not unlocked_tower_ids.has(tower_id):
		status_label.text = "%s is not unlocked." % tower_data[tower_id]["name"]
		_update_tower_unlocks()
		return

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
	if bonus_pending:
		status_label.text = "Choose city support before starting the next wave."
		return

	if wave_manager.start_next_wave():
		status_label.text = "%s in progress." % wave_manager.get_current_wave_name()
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
	_clamp_lives()
	_play_sound("breach")
	_pulse_breach_flash()
	if lives <= 0:
		wave_manager.stop_game()
		status_label.text = "City grid breached. Defeat."
		_play_sound("defeat")
		_show_end_overlay("Defeat: city grid breached")
	_update_hud()

func _on_wave_started(_wave_number: int) -> void:
	bonus_pending = false
	bonus_panel.visible = false
	_play_sound("wave_start")
	if int(wave_manager.get_current_wave_counts().get("air", 0)) > 0:
		_play_sound("helicopter_alert")
	_show_banner("Wave %s: %s" % [_wave_number, wave_manager.get_current_wave_name()], Color("#f5c542"))
	_update_hud()

func _on_wave_completed(_wave_number: int) -> void:
	if _wave_number < wave_manager.total_waves:
		_show_bonus_choices(_wave_number)
		status_label.text = "Air threat detected. Choose the required counter." if _has_required_counter_choice() else "Wave cleared. Choose city support."
	else:
		status_label.text = "Wave cleared."
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
	bonus_pending = false
	if bonus_panel != null:
		bonus_panel.visible = false
	if overlay_title_label != null:
		overlay_title_label.text = title_text
	overlay_panel.visible = true

func _show_bonus_choices(wave_number: int) -> void:
	bonus_pending = true
	active_bonus_choices = _get_bonus_choices(wave_number)
	bonus_panel.visible = true
	bonus_title_label.text = "Air threat detected" if _has_required_counter_choice() else "Wave %s cleared: choose support" % wave_number
	for index in bonus_buttons.size():
		var button := bonus_buttons[index]
		if index >= active_bonus_choices.size():
			button.visible = false
			continue
		var bonus: Dictionary = active_bonus_choices[index]
		button.visible = true
		button.text = "%s\n%s" % [bonus["name"], bonus["description"]]

func _get_bonus_choices(wave_number: int) -> Array:
	var required_counter := _get_required_counter_bonus_for_next_wave()
	if not required_counter.is_empty():
		return [required_counter]

	var choices := []
	_add_unlock_bonus_choices(choices)
	var start_index: int = wave_number % WAVE_BONUSES.size()
	_add_bonus_choices(choices, start_index, true)
	if choices.size() < 3:
		_add_bonus_choices(choices, start_index, false)
	return choices

func _add_unlock_bonus_choices(choices: Array) -> void:
	for bonus in TOWER_UNLOCK_BONUSES:
		if choices.size() >= 3:
			return
		var available_bonus := _get_available_bonus(bonus)
		if not available_bonus.is_empty():
			choices.append(available_bonus)

func _add_bonus_choices(choices: Array, start_index: int, avoid_recent: bool) -> void:
	var bonus_index := start_index
	while choices.size() < 3 and bonus_index < start_index + WAVE_BONUSES.size():
		var bonus: Dictionary = WAVE_BONUSES[bonus_index % WAVE_BONUSES.size()]
		if avoid_recent and _is_recent_bonus(bonus):
			bonus_index += 1
			continue
		if _has_bonus_choice(choices, bonus):
			bonus_index += 1
			continue
		var available_bonus := _get_available_bonus(bonus)
		if not available_bonus.is_empty():
			choices.append(available_bonus)
		bonus_index += 1

func _is_recent_bonus(bonus: Dictionary) -> bool:
	return recent_bonus_ids.has(str(bonus.get("id", "")))

func _has_bonus_choice(choices: Array, bonus: Dictionary) -> bool:
	var bonus_id := str(bonus.get("id", ""))
	for choice in choices:
		if str(choice.get("id", "")) == bonus_id:
			return true
	return false

func _get_available_bonus(bonus: Dictionary) -> Dictionary:
	var available_bonus := bonus.duplicate()
	if available_bonus.has("lives"):
		var missing_lives: int = MAX_LIVES - lives
		if missing_lives <= 0:
			return {}
		var offered_lives: int = min(int(available_bonus["lives"]), missing_lives)
		available_bonus["lives"] = offered_lives
		available_bonus["description"] = "+%s %s." % [offered_lives, "life" if offered_lives == 1 else "lives"]
	elif available_bonus.has("tower_id"):
		if not unlocked_tower_ids.has(str(available_bonus["tower_id"])):
			return {}
		available_bonus = _scale_tower_bonus_offer(available_bonus)
	elif available_bonus.has("unlock_tower_id"):
		if unlocked_tower_ids.has(str(available_bonus["unlock_tower_id"])):
			return {}
	return available_bonus

func _scale_tower_bonus_offer(bonus: Dictionary) -> Dictionary:
	var tower_id := str(bonus["tower_id"])
	var bonus_scale := _get_tower_bonus_scale(tower_id)
	var scaled_bonus := bonus.duplicate()
	for key in ["range_bonus", "splash_bonus", "slow_bonus", "pierce_bonus"]:
		if scaled_bonus.has(key):
			scaled_bonus[key] = float(scaled_bonus[key]) * bonus_scale
	for key in ["damage_multiplier", "fire_rate_multiplier"]:
		if scaled_bonus.has(key):
			scaled_bonus[key] = 1.0 + (float(scaled_bonus[key]) - 1.0) * bonus_scale
	scaled_bonus["description"] = _get_scaled_bonus_description(scaled_bonus)
	return scaled_bonus

func _get_tower_bonus_scale(tower_id: String) -> float:
	var count := int(tower_bonus_counts.get(tower_id, 0))
	var scale_index: int = min(count, TOWER_BONUS_SCALES.size() - 1)
	return float(TOWER_BONUS_SCALES[scale_index])

func _get_scaled_bonus_description(bonus: Dictionary) -> String:
	if bonus.has("damage_multiplier"):
		var damage_bonus: int = int(round((float(bonus["damage_multiplier"]) - 1.0) * 100.0))
		return "%s towers gain +%s%% damage." % [_get_short_tower_name(str(bonus["tower_id"])), damage_bonus]
	if bonus.has("slow_bonus"):
		return "%s towers gain stronger slow." % _get_short_tower_name(str(bonus["tower_id"]))
	if bonus.has("splash_bonus"):
		return "%s gain +%s blast radius." % [_get_short_tower_name(str(bonus["tower_id"])), int(round(float(bonus["splash_bonus"])))]
	if bonus.has("range_bonus"):
		return "%s gain +%s range." % [_get_short_tower_name(str(bonus["tower_id"])), int(round(float(bonus["range_bonus"])))]
	return str(bonus.get("description", "Tower bonus."))

func _on_bonus_pressed(index: int) -> void:
	if not bonus_pending or index < 0 or index >= active_bonus_choices.size():
		return

	var bonus: Dictionary = active_bonus_choices[index]
	_apply_wave_bonus(bonus)
	_remember_bonus_choice(bonus)
	bonus_pending = false
	bonus_panel.visible = false
	status_label.text = "Support received: %s." % bonus["name"]
	_play_sound("upgrade")
	_update_hud()

func _apply_wave_bonus(bonus: Dictionary) -> void:
	money += int(bonus.get("money", 0))
	lives = min(lives + int(bonus.get("lives", 0)), MAX_LIVES)
	_clamp_lives()
	if bonus.has("unlock_tower_id"):
		_unlock_tower(str(bonus["unlock_tower_id"]))
		return
	if not bonus.has("tower_id"):
		return

	var tower_id := str(bonus["tower_id"])
	var effect := _get_tower_bonus_effect(bonus)
	tower_bonus_counts[tower_id] = int(tower_bonus_counts.get(tower_id, 0)) + 1
	_store_tower_bonus(tower_id, effect)
	for tower in placed_towers:
		if is_instance_valid(tower) and tower.tower_id == tower_id:
			tower.apply_match_bonus(effect)
	if selected_tower != null and is_instance_valid(selected_tower):
		_update_selection_panel()

func _get_tower_bonus_effect(bonus: Dictionary) -> Dictionary:
	var effect := {}
	for key in ["damage_multiplier", "range_bonus", "fire_rate_multiplier", "splash_bonus", "slow_bonus", "pierce_bonus"]:
		if bonus.has(key):
			effect[key] = bonus[key]
	return effect

func _store_tower_bonus(tower_id: String, effect: Dictionary) -> void:
	if not tower_match_bonuses.has(tower_id):
		tower_match_bonuses[tower_id] = []
	tower_match_bonuses[tower_id].append(effect)

func _apply_stored_bonuses_to_tower(tower: Node2D) -> void:
	if not tower_match_bonuses.has(tower.tower_id):
		return
	for effect in tower_match_bonuses[tower.tower_id]:
		tower.apply_match_bonus(effect)

func _remember_bonus_choice(bonus: Dictionary) -> void:
	var bonus_id := str(bonus.get("id", ""))
	if bonus_id.is_empty():
		return
	recent_bonus_ids.append(bonus_id)
	while recent_bonus_ids.size() > RECENT_BONUS_LIMIT:
		recent_bonus_ids.pop_front()

func _has_required_counter_choice() -> bool:
	for bonus in active_bonus_choices:
		if str(bonus.get("id", "")) == "unlock_aaa":
			return true
	return false

func _get_required_counter_bonus_for_next_wave() -> Dictionary:
	var next_counts: Dictionary = wave_manager.get_next_wave_counts()
	for enemy_id in next_counts:
		if int(next_counts[enemy_id]) <= 0:
			continue
		var enemy_definition: Dictionary = wave_manager.enemy_data.get(enemy_id, {})
		var traits: Array = enemy_definition.get("traits", [])
		for enemy_trait in traits:
			if REQUIRED_COUNTER_UNLOCKS.has(str(enemy_trait)):
				var bonus: Dictionary = REQUIRED_COUNTER_UNLOCKS[str(enemy_trait)]
				if not unlocked_tower_ids.has(str(bonus["unlock_tower_id"])):
					return bonus.duplicate()
	return {}

func _unlock_tower(tower_id: String) -> bool:
	if not tower_data.has(tower_id) or unlocked_tower_ids.has(tower_id):
		return false
	unlocked_tower_ids.append(tower_id)
	selected_tower_id = tower_id
	_update_tower_unlocks()
	_update_tower_guide_panel()
	return true

func _update_tower_unlocks() -> void:
	for tower_id in tower_buttons:
		var button: Button = tower_buttons[tower_id]
		var unlocked := unlocked_tower_ids.has(tower_id)
		button.visible = unlocked
		button.disabled = not unlocked or not game_started or wave_manager.game_over
		button.button_pressed = unlocked and tower_id == selected_tower_id
	if not unlocked_tower_ids.has(selected_tower_id):
		selected_tower_id = "basic"
		if tower_buttons.has(selected_tower_id):
			tower_buttons[selected_tower_id].button_pressed = true

func _play_sound(sound_id: String) -> void:
	if audio_manager != null and audio_manager.has_method("play"):
		audio_manager.play(sound_id)

func _update_air_audio() -> void:
	if audio_manager == null or not audio_manager.has_method("set_loop_active") or wave_manager == null:
		return
	audio_manager.set_loop_active("helicopter_loop", _has_air_threat())

func _has_air_threat() -> bool:
	if wave_manager.game_over:
		return false
	if wave_manager.get_queued_enemy_count("air") > 0:
		return true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and str(enemy.get("enemy_id")) == "air":
			return true
	return false

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
	for panel in [hud_panel, bonus_panel, selection_panel, settings_panel, overlay_panel, title_panel, codex_panel, tower_guide_panel]:
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
	_clamp_lives()
	money_label.text = "Money: $%s" % money
	lives_label.text = "Lives: %s" % lives
	var current_wave_number: int = max(wave_manager.current_wave + 1, 0)
	if current_wave_number > 0:
		wave_label.text = "Wave %s/%s: %s" % [current_wave_number, wave_manager.total_waves, wave_manager.get_current_wave_name()]
	else:
		wave_label.text = "Wave: 0 / %s" % wave_manager.total_waves
	enemies_label.text = "Enemies remaining: %s" % wave_manager.get_remaining_enemies()
	next_wave_label.text = "Next: %s" % wave_manager.get_next_wave_name()
	var next_counts: Dictionary = wave_manager.get_next_wave_counts()
	var newly_seen := false
	for enemy_id in ENEMY_IDS:
		if int(next_counts.get(enemy_id, 0)) > 0 and not seen_enemy_ids.has(enemy_id):
			seen_enemy_ids.append(enemy_id)
			newly_seen = true
	if newly_seen:
		_update_codex_panel()
	for enemy_id in next_wave_count_labels:
		next_wave_count_labels[enemy_id].text = "%s: %s" % [_get_enemy_icon(enemy_id), int(next_counts.get(enemy_id, 0))]
	speed_label.text = "Speed: paused" if game_paused else "Speed: %sx" % int(game_speed)
	start_button.disabled = not game_started or bonus_pending or wave_manager.game_over or wave_manager.spawning or wave_manager.active_enemies > 0
	var next_wave_name: String = wave_manager.get_next_wave_name()
	start_button.text = "Start Wave" if next_wave_name == "None" else "Start %s" % next_wave_name
	restart_button.disabled = not game_started
	menu_button.disabled = not game_started
	settings_button.button_pressed = settings_panel.visible
	var blocking_open := bonus_panel.visible or overlay_panel.visible or title_panel.visible
	if blocking_open and codex_panel.visible:
		codex_panel.visible = false
		codex_button.button_pressed = false
	if blocking_open and tower_guide_panel.visible:
		tower_guide_panel.visible = false
		tower_guide_button.button_pressed = false
	codex_button.disabled = blocking_open
	tower_guide_button.disabled = blocking_open
	volume_label.text = "Volume: %s%%" % int(audio_manager.get_master_volume() * 100.0)
	volume_slider.value = audio_manager.get_master_volume()
	mute_button.button_pressed = audio_manager.is_muted()
	if map_label != null:
		map_label.text = "Map: %s" % map.get_map_name(selected_map_index)
	pause_button.button_pressed = game_paused
	pause_button.disabled = not game_started or wave_manager.game_over
	for tower_id in tower_buttons:
		tower_buttons[tower_id].disabled = not unlocked_tower_ids.has(tower_id) or not game_started or wave_manager.game_over
		tower_buttons[tower_id].visible = unlocked_tower_ids.has(tower_id)
	_update_selection_panel()

func _is_hud_ready() -> bool:
	return money_label != null \
		and lives_label != null \
		and wave_label != null \
		and enemies_label != null \
		and next_wave_label != null \
		and speed_label != null \
		and bonus_panel != null \
		and bonus_title_label != null \
		and start_button != null \
		and restart_button != null \
		and menu_button != null \
		and settings_button != null \
		and volume_label != null \
		and volume_slider != null \
		and mute_button != null \
		and map_label != null \
		and next_map_button != null

func _clamp_lives() -> void:
	lives = clampi(lives, 0, MAX_LIVES)
