extends Node2D

## Manages procedural neon hit bursts, expanding shockwave rings,
## floating damage/status text, and camera screen shake.

class NeonParticle:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var life: float = 0.0
	var max_life: float = 0.35
	var size: float = 4.0
	var color: Color = Color.CYAN

class ShockwaveRing:
	var pos: Vector2 = Vector2.ZERO
	var max_radius: float = 80.0
	var life: float = 0.0
	var duration: float = 0.36
	var color: Color = Color.CYAN

class FloatingLabel:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2(0.0, -48.0)
	var text: String = ""
	var life: float = 0.0
	var duration: float = 0.72
	var color: Color = Color.WHITE
	var font_size: int = 16

const MAX_PARTICLES: int = 600
const MAX_RINGS: int = 64
const MAX_LABELS: int = 96

var camera_ref: Camera2D = null

var _particles: Array[NeonParticle] = []
var _rings: Array[ShockwaveRing] = []
var _labels: Array[FloatingLabel] = []

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _needs_final_clear_draw: bool = false


func _ready() -> void:
	z_index = 25


func _process(delta: float) -> void:
	_update_shake(delta)

	var had_items: bool = not _particles.is_empty() or not _rings.is_empty() or not _labels.is_empty()

	# Update particles
	var pi: int = _particles.size() - 1
	while pi >= 0:
		var p: NeonParticle = _particles[pi]
		p.life += delta
		if p.life >= p.max_life:
			_particles.remove_at(pi)
		else:
			p.pos += p.vel * delta
			p.vel *= exp(-6.5 * delta)
		pi -= 1

	# Update shockwave rings
	var ri: int = _rings.size() - 1
	while ri >= 0:
		var r: ShockwaveRing = _rings[ri]
		r.life += delta
		if r.life >= r.duration:
			_rings.remove_at(ri)
		ri -= 1

	# Update floating text labels
	var li: int = _labels.size() - 1
	while li >= 0:
		var lbl: FloatingLabel = _labels[li]
		lbl.life += delta
		if lbl.life >= lbl.duration:
			_labels.remove_at(li)
		else:
			lbl.pos += lbl.vel * delta
			lbl.vel.y *= exp(-2.8 * delta)
		li -= 1

	var has_items: bool = not _particles.is_empty() or not _rings.is_empty() or not _labels.is_empty()
	if has_items or (had_items and _needs_final_clear_draw):
		_needs_final_clear_draw = has_items
		queue_redraw()


func _update_shake(delta: float) -> void:
	if not is_instance_valid(camera_ref):
		return
	if _shake_timer > 0.0:
		_shake_timer = maxf(0.0, _shake_timer - delta)
		var ratio: float = _shake_timer / maxf(_shake_duration, 0.001)
		var mag: float = _shake_intensity * ratio
		camera_ref.offset = Vector2(randf_range(-mag, mag), randf_range(-mag, mag))
		if _shake_timer <= 0.0:
			_shake_intensity = 0.0
			camera_ref.offset = Vector2.ZERO
	elif camera_ref.offset != Vector2.ZERO:
		camera_ref.offset = Vector2.ZERO


func trigger_shake(intensity: float, duration: float) -> void:
	if intensity <= 0.0 or duration <= 0.0:
		return
	if intensity >= _shake_intensity or _shake_timer <= 0.0:
		_shake_intensity = intensity
		_shake_duration = duration
		_shake_timer = duration
	else:
		_shake_timer = maxf(_shake_timer, duration * 0.5)


func spawn_floating_text(pos: Vector2, text: String, color: Color) -> void:
	if _labels.size() >= MAX_LABELS:
		_labels.remove_at(0)
	var lbl := FloatingLabel.new()
	lbl.pos = pos + Vector2(randf_range(-8.0, 8.0), randf_range(-4.0, 4.0))
	lbl.vel = Vector2(randf_range(-14.0, 14.0), -52.0)
	lbl.text = text
	lbl.duration = 0.72
	lbl.color = color
	lbl.font_size = 17 if text.length() <= 4 else 16
	_labels.append(lbl)
	_needs_final_clear_draw = true
	queue_redraw()


func spawn_hit_burst(pos: Vector2, color: Color, count: int = 10) -> void:
	var spawn_count: int = clampi(count, 1, 32)
	for i in spawn_count:
		if _particles.size() >= MAX_PARTICLES:
			_particles.remove_at(0)
		var angle: float = randf() * TAU
		var speed: float = randf_range(75.0, 240.0)
		var p := NeonParticle.new()
		p.pos = pos
		p.vel = Vector2.from_angle(angle) * speed
		p.max_life = randf_range(0.20, 0.42)
		p.size = randf_range(2.4, 5.4)
		p.color = color if i % 4 != 0 else color.lightened(0.45)
		_particles.append(p)
	_needs_final_clear_draw = true
	queue_redraw()


func spawn_shockwave_ring(pos: Vector2, max_radius: float, color: Color) -> void:
	if _rings.size() >= MAX_RINGS:
		_rings.remove_at(0)
	var r := ShockwaveRing.new()
	r.pos = pos
	r.max_radius = maxf(max_radius, 12.0)
	r.duration = 0.36
	r.color = color
	_rings.append(r)
	_needs_final_clear_draw = true
	queue_redraw()


func _draw() -> void:
	# Shockwave rings
	for r in _rings:
		var t: float = clampf(r.life / maxf(r.duration, 0.001), 0.0, 1.0)
		var ease_t: float = 1.0 - pow(1.0 - t, 2.5)
		var cur_radius: float = lerpf(10.0, r.max_radius, ease_t)
		var alpha: float = 1.0 - t
		var local_pos: Vector2 = to_local(r.pos)
		draw_arc(local_pos, cur_radius, 0.0, TAU, 40, Color(r.color, alpha * 0.28), maxf(1.5, 10.0 * alpha), true)
		draw_arc(local_pos, cur_radius, 0.0, TAU, 40, Color(r.color, alpha * 0.92), maxf(1.2, 3.6 * alpha), true)
		draw_arc(local_pos, cur_radius * 0.97, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, alpha * 0.7), maxf(1.0, 1.6 * alpha), true)

	# Neon particles
	for p in _particles:
		var t: float = clampf(p.life / maxf(p.max_life, 0.001), 0.0, 1.0)
		var alpha: float = 1.0 - t * t
		var r: float = p.size * (1.0 - t * 0.55)
		var local_pos: Vector2 = to_local(p.pos)
		draw_circle(local_pos, r * 1.9, Color(p.color, alpha * 0.24))
		draw_circle(local_pos, r, Color(p.color, alpha))
		draw_circle(local_pos, r * 0.45, Color(1.0, 1.0, 1.0, alpha * 0.85))

	# Floating damage/status labels
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	for lbl in _labels:
		var t: float = clampf(lbl.life / maxf(lbl.duration, 0.001), 0.0, 1.0)
		var alpha: float = clampf((1.0 - t) * 1.35, 0.0, 1.0)
		var scale_pop: float = 1.22 - 0.22 * minf(t * 4.0, 1.0)
		var fsize: int = maxi(10, int(round(lbl.font_size * scale_pop)))
		var text_size: Vector2 = font.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var local_pos: Vector2 = to_local(lbl.pos) - Vector2(text_size.x * 0.5, 0.0)
		var shadow_col := Color(0.02, 0.04, 0.08, alpha * 0.85)
		var main_col := Color(lbl.color, alpha)
		draw_string(font, local_pos + Vector2(1.5, 1.5), lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, shadow_col)
		draw_string(font, local_pos + Vector2(-1.0, 0.0), lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, shadow_col)
		draw_string(font, local_pos, lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, main_col)
