extends Node

const SAMPLE_RATE := 22050

var sounds := {}
var loop_players := {}
var master_volume := 0.7
var muted := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_sounds()

func play(sound_id: String) -> void:
	if muted or not sounds.has(sound_id):
		return

	var player := AudioStreamPlayer.new()
	player.stream = sounds[sound_id]
	player.bus = "Master"
	player.volume_db = linear_to_db(master_volume)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func set_loop_active(sound_id: String, active: bool) -> void:
	if active:
		_start_loop(sound_id)
	else:
		_stop_loop(sound_id)

func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	for sound_id in loop_players:
		var player: AudioStreamPlayer = loop_players[sound_id]
		player.volume_db = _get_loop_volume_db(str(sound_id))

func set_muted(value: bool) -> void:
	muted = value
	for player in loop_players.values():
		player.stream_paused = muted

func get_master_volume() -> float:
	return master_volume

func is_muted() -> bool:
	return muted

func _build_sounds() -> void:
	sounds["tower_fire"] = _make_tone(820.0, 0.055, 0.22, "square")
	sounds["enemy_death"] = _make_tone(260.0, 0.13, 0.28, "saw_down")
	sounds["breach"] = _make_tone(110.0, 0.22, 0.35, "saw_down")
	sounds["wave_start"] = _make_chime([440.0, 660.0], 0.18, 0.25)
	sounds["wave_clear"] = _make_chime([523.25, 659.25, 783.99], 0.24, 0.24)
	sounds["upgrade"] = _make_chime([660.0, 880.0], 0.12, 0.22)
	sounds["sell"] = _make_tone(360.0, 0.09, 0.2, "sine")
	sounds["victory"] = _make_chime([523.25, 659.25, 783.99, 1046.5], 0.5, 0.28)
	sounds["defeat"] = _make_chime([220.0, 164.81, 110.0], 0.5, 0.3)
	sounds["helicopter_alert"] = _make_helicopter_alert()
	sounds["helicopter_loop"] = _make_helicopter_loop()

func _start_loop(sound_id: String) -> void:
	if muted or loop_players.has(sound_id) or not sounds.has(sound_id):
		return

	var player := AudioStreamPlayer.new()
	player.stream = sounds[sound_id]
	player.bus = "Master"
	player.volume_db = _get_loop_volume_db(sound_id)
	player.finished.connect(_restart_loop.bind(sound_id))
	add_child(player)
	loop_players[sound_id] = player
	player.play()

func _stop_loop(sound_id: String) -> void:
	if not loop_players.has(sound_id):
		return

	var player: AudioStreamPlayer = loop_players[sound_id]
	loop_players.erase(sound_id)
	player.stop()
	player.queue_free()

func _restart_loop(sound_id: String) -> void:
	if muted or not loop_players.has(sound_id):
		return
	var player: AudioStreamPlayer = loop_players[sound_id]
	player.play()

func _get_loop_volume_db(sound_id: String) -> float:
	var boost_db := 5.0 if sound_id == "helicopter_loop" else 0.0
	return linear_to_db(master_volume) + boost_db

func _make_chime(frequencies: Array, duration: float, volume: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	var frames := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)

	for i in frames:
		var t := float(i) / SAMPLE_RATE
		var sample := 0.0
		for f in frequencies:
			sample += sin(TAU * float(f) * t)
		sample /= max(frequencies.size(), 1)
		sample *= _envelope(t, duration) * volume
		_write_sample(data, i, sample)

	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

func _make_tone(frequency: float, duration: float, volume: float, wave: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	var frames := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)

	for i in frames:
		var t := float(i) / SAMPLE_RATE
		var phase := fmod(frequency * t, 1.0)
		var sample := _wave_sample(phase, wave)
		sample *= _envelope(t, duration) * volume
		_write_sample(data, i, sample)

	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

func _make_helicopter_loop() -> AudioStreamWAV:
	var duration := 0.55
	var stream := AudioStreamWAV.new()
	var frames := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)

	for i in frames:
		var t: float = float(i) / SAMPLE_RATE
		var blade_phase: float = fmod(22.0 * t, 1.0)
		var blade_pulse: float = pow(max(1.0 - abs(blade_phase - 0.5) * 2.0, 0.0), 4.0)
		var second_blade_phase: float = fmod(22.0 * t + 0.5, 1.0)
		var second_blade: float = pow(max(1.0 - abs(second_blade_phase - 0.5) * 2.0, 0.0), 4.0)
		var engine: float = sin(TAU * 62.0 * t) * 0.3 + sin(TAU * 124.0 * t) * 0.16
		var chop: float = ((blade_pulse + second_blade) * 1.7 - 0.65) * 0.48
		var sample: float = (engine + chop) * 0.75
		_write_sample(data, i, sample)

	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	stream.data = data
	return stream

func _make_helicopter_alert() -> AudioStreamWAV:
	var duration := 1.1
	var stream := AudioStreamWAV.new()
	var frames := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)

	for i in frames:
		var t: float = float(i) / SAMPLE_RATE
		var ramp: float = min(t / 0.45, 1.0)
		var blade_phase: float = fmod(18.0 * t + t * 4.0, 1.0)
		var blade_pulse: float = pow(max(1.0 - abs(blade_phase - 0.5) * 2.0, 0.0), 4.0)
		var engine: float = sin(TAU * 58.0 * t) * 0.28 + sin(TAU * 116.0 * t) * 0.12
		var sample: float = (engine + (blade_pulse * 2.0 - 0.7) * 0.48) * ramp * _envelope(t, duration) * 0.85
		_write_sample(data, i, sample)

	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

func _wave_sample(phase: float, wave: String) -> float:
	match wave:
		"square":
			return 1.0 if phase < 0.5 else -1.0
		"saw_down":
			return 1.0 - phase * 2.0
		_:
			return sin(TAU * phase)

func _envelope(t: float, duration: float) -> float:
	var attack: float = min(0.015, duration * 0.25)
	var release: float = min(0.08, duration * 0.5)
	if t < attack:
		return t / attack
	if t > duration - release:
		return max((duration - t) / release, 0.0)
	return 1.0

func _write_sample(data: PackedByteArray, frame: int, sample: float) -> void:
	var value := int(clamp(sample, -1.0, 1.0) * 32767.0)
	if value < 0:
		value += 65536
	data[frame * 2] = value & 0xff
	data[frame * 2 + 1] = (value >> 8) & 0xff
