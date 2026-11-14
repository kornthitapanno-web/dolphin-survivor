extends Node

## Procedural SFX manager using pre-baked AudioStreamWAV buffers for zero-overhead playback
## across Desktop and Web (HTML5/WASM) with safe headless mode skip.

const MIX_RATE: int = 22050
const POOL_SIZE: int = 8

var _players: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0
var _streams: Dictionary = {}
var _is_headless: bool = false
var _last_play_ms: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		_is_headless = true
		return

	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.volume_db = -6.0
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)

	_bake_all_sfx()


func _bake_all_sfx() -> void:
	_streams["shoot"] = _bake_voices([
		{"wf": "triangle", "f0": 860.0, "f1": 390.0, "dur": 0.08, "vol": 0.22, "delay": 0.0},
		{"wf": "sine", "f0": 1180.0, "f1": 540.0, "dur": 0.06, "vol": 0.14, "delay": 0.0},
	])
	_streams["hit"] = _bake_voices([
		{"wf": "square", "f0": 240.0, "f1": 88.0, "dur": 0.07, "vol": 0.18, "delay": 0.0},
		{"wf": "noise", "f0": 100.0, "f1": 100.0, "dur": 0.04, "vol": 0.12, "delay": 0.0},
	])
	_streams["xp"] = _bake_voices([
		{"wf": "sine", "f0": 920.0, "f1": 1420.0, "dur": 0.08, "vol": 0.20, "delay": 0.0},
	])
	_streams["hurt"] = _bake_voices([
		{"wf": "square", "f0": 210.0, "f1": 72.0, "dur": 0.15, "vol": 0.28, "delay": 0.0},
		{"wf": "noise", "f0": 80.0, "f1": 60.0, "dur": 0.11, "vol": 0.16, "delay": 0.0},
	])
	_streams["button"] = _bake_voices([
		{"wf": "sine", "f0": 680.0, "f1": 980.0, "dur": 0.05, "vol": 0.22, "delay": 0.0},
	])

	var lvl_voices: Array[Dictionary] = []
	var lvl_notes := [523.25, 659.25, 783.99, 1046.5]
	for i in range(lvl_notes.size()):
		var f: float = float(lvl_notes[i])
		lvl_voices.append({"wf": "triangle", "f0": f, "f1": f * 1.02, "dur": 0.13, "vol": 0.24, "delay": float(i) * 0.07})
		lvl_voices.append({"wf": "sine", "f0": f * 2.0, "f1": f * 2.0, "dur": 0.10, "vol": 0.11, "delay": float(i) * 0.07})
	_streams["level_up"] = _bake_voices(lvl_voices)

	var go_voices: Array[Dictionary] = []
	var go_notes := [392.0, 349.23, 293.66, 196.0]
	for i in range(go_notes.size()):
		var f: float = float(go_notes[i])
		go_voices.append({"wf": "triangle", "f0": f, "f1": f * 0.96, "dur": 0.18, "vol": 0.25, "delay": float(i) * 0.10})
	_streams["game_over"] = _bake_voices(go_voices)

	var clr_voices: Array[Dictionary] = []
	var clr_notes := [523.25, 659.25, 783.99, 1046.5, 1318.51]
	for i in range(clr_notes.size()):
		var f: float = float(clr_notes[i])
		clr_voices.append({"wf": "triangle", "f0": f, "f1": f * 1.01, "dur": 0.16, "vol": 0.24, "delay": float(i) * 0.075})
		clr_voices.append({"wf": "sine", "f0": f * 1.5, "f1": f * 1.5, "dur": 0.12, "vol": 0.11, "delay": float(i) * 0.075})
	_streams["stage_clear"] = _bake_voices(clr_voices)

	var ach_voices: Array[Dictionary] = []
	var ach_notes := [659.25, 987.77, 1318.51]
	for i in range(ach_notes.size()):
		var f: float = float(ach_notes[i])
		ach_voices.append({"wf": "sine", "f0": f, "f1": f * 1.01, "dur": 0.14, "vol": 0.24, "delay": float(i) * 0.06})
	_streams["achievement"] = _bake_voices(ach_voices)


func _bake_voices(voices: Array[Dictionary]) -> AudioStreamWAV:
	var total_sec: float = 0.05
	for v in voices:
		total_sec = maxf(total_sec, float(v["delay"]) + float(v["dur"]))
	var total_samples: int = int(ceil(total_sec * float(MIX_RATE)))
	var dt: float = 1.0 / float(MIX_RATE)
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	var phases: PackedFloat32Array = PackedFloat32Array()
	phases.resize(voices.size())

	for i in range(total_samples):
		var t_sec: float = float(i) * dt
		var mix: float = 0.0
		for vi in range(voices.size()):
			var v: Dictionary = voices[vi]
			var delay: float = float(v["delay"])
			var dur: float = float(v["dur"])
			var elapsed: float = t_sec - delay
			if elapsed < 0.0 or elapsed >= dur:
				continue
			var norm_t: float = elapsed / dur
			var freq: float = lerpf(float(v["f0"]), float(v["f1"]), norm_t)
			var ph: float = fmod(phases[vi] + freq * dt, 1.0)
			phases[vi] = ph

			var raw: float = 0.0
			var wf: String = str(v["wf"])
			if wf == "sine":
				raw = sin(ph * TAU)
			elif wf == "square":
				raw = 1.0 if ph < 0.5 else -1.0
			elif wf == "triangle":
				raw = 1.0 - 4.0 * absf(ph - 0.5)
			elif wf == "noise":
				raw = randf_range(-1.0, 1.0)

			var attack: float = minf(1.0, elapsed / 0.006)
			var decay: float = pow(1.0 - norm_t, 1.35)
			mix += raw * float(v["vol"]) * attack * decay

		var sample_i: int = int(clampf(mix, -0.9, 0.9) * 32767.0)
		data[i * 2] = sample_i & 0xFF
		data[i * 2 + 1] = (sample_i >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _can_trigger(tag: String, cooldown_ms: int) -> bool:
	var now: int = Time.get_ticks_msec()
	var prev: int = int(_last_play_ms.get(tag, -99999))
	if now - prev < cooldown_ms:
		return false
	_last_play_ms[tag] = now
	return true


func _play_tag(tag: String, cooldown_ms: int = 0) -> void:
	if _is_headless or _players.is_empty():
		return
	if cooldown_ms > 0 and not _can_trigger(tag, cooldown_ms):
		return
	var stream: AudioStreamWAV = _streams.get(tag, null)
	if stream == null:
		return
	var p: AudioStreamPlayer = _players[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _players.size()
	p.stream = stream
	p.play()


func play_shoot() -> void:
	_play_tag("shoot", 40)


func play_hit() -> void:
	_play_tag("hit", 35)


func play_xp() -> void:
	_play_tag("xp", 30)


func play_level_up() -> void:
	_play_tag("level_up", 0)


func play_hurt() -> void:
	_play_tag("hurt", 85)


func play_button() -> void:
	_play_tag("button", 0)


func play_game_over() -> void:
	_play_tag("game_over", 0)


func play_stage_clear() -> void:
	_play_tag("stage_clear", 0)


func play_achievement() -> void:
	_play_tag("achievement", 0)
