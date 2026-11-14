extends Node

const MIX_RATE: float = 22050.0
const BUFFER_LENGTH: float = 0.15
const MAX_VOICES: int = 12

var _player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _voices: Array[Dictionary] = []
var _is_headless: bool = false
var _shutting_down: bool = false
var _last_play_ms: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tree_exiting.connect(_cleanup_audio)
	if DisplayServer.get_name() == "headless":
		_is_headless = true
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = BUFFER_LENGTH

	_player = AudioStreamPlayer.new()
	_player.name = "ProceduralSFXPlayer"
	_player.stream = gen
	_player.volume_db = -6.0
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func _cleanup_audio() -> void:
	if _shutting_down:
		return
	_shutting_down = true
	_voices.clear()
	_playback = null
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null
		if _player.get_parent() == self:
			remove_child(_player)
		_player.free()
		_player = null
		if not _is_headless:
			OS.delay_msec(30)


func _exit_tree() -> void:
	_cleanup_audio()


func _process(_delta: float) -> void:
	if _shutting_down or _is_headless or _playback == null:
		return
	if _voices.is_empty():
		return
	if _player != null and not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
		if _playback == null:
			return
	_pump_audio(0.05)


func _can_trigger(tag: String, cooldown_ms: int) -> bool:
	var now: int = Time.get_ticks_msec()
	var prev: int = int(_last_play_ms.get(tag, -99999))
	if now - prev < cooldown_ms:
		return false
	_last_play_ms[tag] = now
	return true


func _add_voice(
	waveform: String,
	freq_start: float,
	freq_end: float,
	duration: float,
	volume: float = 0.28,
	delay: float = 0.0
) -> void:
	if _shutting_down or _is_headless or _playback == null:
		return
	if _voices.size() >= MAX_VOICES:
		_voices.pop_front()
	_voices.append({
		"waveform": waveform,
		"freq_start": freq_start,
		"freq_end": freq_end,
		"duration": maxf(0.01, duration),
		"elapsed": 0.0,
		"delay": maxf(0.0, delay),
		"volume": clampf(volume, 0.0, 0.8),
		"phase": 0.0
	})


func _pump_audio(max_chunk_sec: float) -> void:
	if _shutting_down or _is_headless or _playback == null or _voices.is_empty():
		return
	var avail: int = _playback.get_frames_available()
	if avail <= 0:
		return
	var target_frames: int = mini(avail, int(MIX_RATE * max_chunk_sec))
	if target_frames <= 0:
		return

	var dt: float = 1.0 / MIX_RATE
	var frames := PackedVector2Array()
	frames.resize(target_frames)

	for i in range(target_frames):
		var mix: float = 0.0
		var v_idx: int = _voices.size() - 1
		while v_idx >= 0:
			var v: Dictionary = _voices[v_idx]
			if float(v["delay"]) > 0.0:
				v["delay"] = float(v["delay"]) - dt
				v_idx -= 1
				continue

			var elapsed: float = float(v["elapsed"])
			var duration: float = float(v["duration"])
			if elapsed >= duration:
				_voices.remove_at(v_idx)
				v_idx -= 1
				continue

			var t: float = elapsed / duration
			var freq: float = lerpf(float(v["freq_start"]), float(v["freq_end"]), t)
			var phase: float = fmod(float(v["phase"]) + freq * dt, 1.0)
			v["phase"] = phase

			var raw: float = 0.0
			var wf: String = str(v["waveform"])
			if wf == "sine":
				raw = sin(phase * TAU)
			elif wf == "square":
				raw = 1.0 if phase < 0.5 else -1.0
			elif wf == "triangle":
				raw = 1.0 - 4.0 * absf(phase - 0.5)
			elif wf == "noise":
				raw = randf_range(-1.0, 1.0)

			var attack: float = minf(1.0, elapsed / 0.006)
			var decay: float = pow(1.0 - t, 1.35)
			mix += raw * float(v["volume"]) * attack * decay
			v["elapsed"] = elapsed + dt
			v_idx -= 1

		var out: float = clampf(mix, -0.85, 0.85)
		frames[i] = Vector2(out, out)

	_playback.push_buffer(frames)


func play_shoot() -> void:
	if not _can_trigger("shoot", 35):
		return
	_add_voice("triangle", 860.0, 390.0, 0.08, 0.20)
	_add_voice("sine", 1180.0, 540.0, 0.06, 0.12)
	_pump_audio(0.03)


func play_hit() -> void:
	if not _can_trigger("hit", 30):
		return
	_add_voice("square", 240.0, 88.0, 0.07, 0.16)
	_add_voice("noise", 100.0, 100.0, 0.04, 0.10)
	_pump_audio(0.03)


func play_xp() -> void:
	if not _can_trigger("xp", 28):
		return
	_add_voice("sine", 920.0, 1420.0, 0.08, 0.18)
	_pump_audio(0.03)


func play_level_up() -> void:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in range(notes.size()):
		var f: float = float(notes[i])
		_add_voice("triangle", f, f * 1.02, 0.13, 0.22, float(i) * 0.07)
		_add_voice("sine", f * 2.0, f * 2.0, 0.10, 0.10, float(i) * 0.07)
	_pump_audio(0.04)


func play_hurt() -> void:
	if not _can_trigger("hurt", 80):
		return
	_add_voice("square", 210.0, 72.0, 0.15, 0.26)
	_add_voice("noise", 80.0, 60.0, 0.11, 0.16)
	_pump_audio(0.04)


func play_button() -> void:
	_add_voice("sine", 680.0, 980.0, 0.05, 0.20)
	_pump_audio(0.03)


func play_game_over() -> void:
	var notes := [392.0, 349.23, 293.66, 196.0]
	for i in range(notes.size()):
		var f: float = float(notes[i])
		_add_voice("triangle", f, f * 0.96, 0.18, 0.24, float(i) * 0.10)
	_pump_audio(0.04)


func play_stage_clear() -> void:
	var notes := [523.25, 659.25, 783.99, 1046.5, 1318.51]
	for i in range(notes.size()):
		var f: float = float(notes[i])
		_add_voice("triangle", f, f * 1.01, 0.16, 0.23, float(i) * 0.075)
		_add_voice("sine", f * 1.5, f * 1.5, 0.12, 0.10, float(i) * 0.075)
	_pump_audio(0.04)


func play_achievement() -> void:
	var notes := [659.25, 987.77, 1318.51]
	for i in range(notes.size()):
		var f: float = float(notes[i])
		_add_voice("sine", f, f * 1.01, 0.14, 0.22, float(i) * 0.06)
	_pump_audio(0.04)
