extends Node2D

var stage_id: int = 1
var camera_pos: Vector2 = Vector2.ZERO

var _time: float = 0.0
var _time_since_camera_set: float = 999.0

const TILE_SIZE: float = 380.0
const VIEW_HALF_EXTENT: Vector2 = Vector2(780.0, 560.0)
var _redraw_accum: float = 0.0


func _ready() -> void:
	z_index = -100


func set_stage(id: int) -> void:
	stage_id = 2 if id == 2 else 1
	queue_redraw()


func set_camera_pos(pos: Vector2) -> void:
	camera_pos = pos
	_time_since_camera_set = 0.0


func _process(delta: float) -> void:
	_time += delta
	_time_since_camera_set += delta
	if _time_since_camera_set > 0.25:
		var vp: Viewport = get_viewport()
		if vp != null:
			var cam: Camera2D = vp.get_camera_2d()
			if cam != null:
				camera_pos = cam.get_screen_center_position()
	_redraw_accum += delta
	if _redraw_accum >= 0.033:
		_redraw_accum = 0.0
		queue_redraw()


func _hash_int(x: int, y: int, salt: int = 0) -> int:
	var h: int = (x * 374761393 + y * 668265263 + salt * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)


func _hash_float(x: int, y: int, salt: int = 0) -> float:
	return float(_hash_int(x, y, salt) & 0xffffff) / 16777216.0


func _draw() -> void:
	var center: Vector2 = camera_pos
	var half: Vector2 = VIEW_HALF_EXTENT
	var left: float = center.x - half.x
	var right: float = center.x + half.x
	var top: float = center.y - half.y
	var bottom: float = center.y + half.y

	if stage_id == 1:
		_draw_stage1_shallow(center, left, right, top, bottom)
	else:
		_draw_stage2_abyss(center, left, right, top, bottom)


func _draw_vertical_gradient(left: float, right: float, top: float, bottom: float, c_top: Color, c_mid: Color, c_bot: Color) -> void:
	var mid_y: float = (top + bottom) * 0.5
	var top_pts := PackedVector2Array([
		Vector2(left, top),
		Vector2(right, top),
		Vector2(right, mid_y),
		Vector2(left, mid_y),
	])
	var top_cols := PackedColorArray([c_top, c_top, c_mid, c_mid])
	draw_polygon(top_pts, top_cols)

	var bot_pts := PackedVector2Array([
		Vector2(left, mid_y),
		Vector2(right, mid_y),
		Vector2(right, bottom),
		Vector2(left, bottom),
	])
	var bot_cols := PackedColorArray([c_mid, c_mid, c_bot, c_bot])
	draw_polygon(bot_pts, bot_cols)


func _draw_sonar_grid(left: float, right: float, top: float, bottom: float, grid_size: float, line_col: Color, cross_col: Color) -> void:
	var start_ix: int = int(floor(left / grid_size))
	var end_ix: int = int(ceil(right / grid_size))
	var start_iy: int = int(floor(top / grid_size))
	var end_iy: int = int(ceil(bottom / grid_size))

	for ix in range(start_ix, end_ix + 1):
		var x: float = float(ix) * grid_size
		draw_line(Vector2(x, top), Vector2(x, bottom), line_col, 1.0)
	for iy in range(start_iy, end_iy + 1):
		var y: float = float(iy) * grid_size
		draw_line(Vector2(left, y), Vector2(right, y), line_col, 1.0)

	for ix in range(start_ix, end_ix + 1):
		if ix % 2 != 0:
			continue
		for iy in range(start_iy, end_iy + 1):
			if iy % 2 != 0:
				continue
			var cx: float = float(ix) * grid_size
			var cy: float = float(iy) * grid_size
			draw_line(Vector2(cx - 7.0, cy), Vector2(cx + 7.0, cy), cross_col, 1.5)
			draw_line(Vector2(cx, cy - 7.0), Vector2(cx, cy + 7.0), cross_col, 1.5)


func _draw_stage1_shallow(center: Vector2, left: float, right: float, top: float, bottom: float) -> void:
	_draw_vertical_gradient(
		left, right, top, bottom,
		Color(0.039, 0.435, 0.569, 1.0), # luminous shallow turquoise
		Color(0.020, 0.231, 0.369, 1.0), # vibrant turquoise-blue (#053b5e)
		Color(0.012, 0.098, 0.180, 1.0)  # deep reef teal-navy (#03192e)
	)

	# Subtle neon sonar grid locked to world coordinates
	_draw_sonar_grid(
		left, right, top, bottom, 240.0,
		Color(0.0, 0.96, 0.83, 0.065),
		Color(0.0, 0.96, 0.83, 0.15)
	)

	# Diagonal golden-cyan sunlight caustic rays scrolling softly in world space
	var ray_spacing: float = 380.0
	var ray_start: int = int(floor((left - 400.0) / ray_spacing))
	var ray_end: int = int(ceil((right + 400.0) / ray_spacing))
	for r_idx in range(ray_start, ray_end + 1):
		var shimmer: float = 0.65 + 0.35 * sin(_time * 1.15 + float(r_idx) * 1.37)
		var base_x: float = float(r_idx) * ray_spacing + sin(_time * 0.45 + float(r_idx)) * 28.0
		var w_top: float = 64.0 + 24.0 * sin(float(r_idx) * 2.1)
		var w_bot: float = w_top * 2.35
		var skew: float = 420.0
		var poly := PackedVector2Array([
			Vector2(base_x - w_top * 0.5, top),
			Vector2(base_x + w_top * 0.5, top),
			Vector2(base_x + skew + w_bot * 0.5, bottom),
			Vector2(base_x + skew - w_bot * 0.5, bottom),
		])
		var c_top := Color(0.55, 0.98, 0.88, 0.08 * shimmer)
		var c_bot := Color(0.0, 0.96, 0.83, 0.01 * shimmer)
		draw_polygon(poly, PackedColorArray([c_top, c_top, c_bot, c_bot]))

	# Tiled world-hashed reef decorations
	var min_gx: int = int(floor(left / TILE_SIZE)) - 1
	var max_gx: int = int(floor(right / TILE_SIZE)) + 1
	var min_gy: int = int(floor(top / TILE_SIZE)) - 1
	var max_gy: int = int(floor(bottom / TILE_SIZE)) + 1

	var coral_palette: Array[Color] = [
		Color("#8f3f6a"), # muted reef pink
		Color("#8f5a44"), # muted coral terracotta
		Color("#4d7d63"), # muted seafoam sage
		Color("#2a7582"), # muted deep teal
	]

	for gx in range(min_gx, max_gx + 1):
		for gy in range(min_gy, max_gy + 1):
			var origin := Vector2(float(gx) * TILE_SIZE, float(gy) * TILE_SIZE)
			var r0: float = _hash_float(gx, gy, 1)
			var r1: float = _hash_float(gx, gy, 2)
			var r2: float = _hash_float(gx, gy, 3)
			var r3: float = _hash_float(gx, gy, 4)

			# Soft seabed reef patch
			if r0 < 0.42:
				var patch_pos := origin + Vector2(r1 * TILE_SIZE, r2 * TILE_SIZE)
				var patch_r: float = 42.0 + r3 * 46.0
				draw_circle(patch_pos, patch_r, Color(0.0, 0.65, 0.72, 0.065))

			# Glowing neon coral clusters
			if r0 > 0.45:
				var coral_pos := origin + Vector2((0.18 + r1 * 0.64) * TILE_SIZE, (0.18 + r2 * 0.64) * TILE_SIZE)
				var col_idx: int = _hash_int(gx, gy, 5) % coral_palette.size()
				var coral_col: Color = coral_palette[col_idx]
				_draw_coral_cluster(coral_pos, coral_col, gx, gy)

			# Starfish
			if _hash_float(gx, gy, 6) < 0.28:
				var star_pos := origin + Vector2((0.2 + _hash_float(gx, gy, 7) * 0.6) * TILE_SIZE, (0.2 + _hash_float(gx, gy, 8) * 0.6) * TILE_SIZE)
				var star_col: Color = Color("#8c5c45") if (_hash_int(gx, gy, 9) % 2 == 0) else Color("#8a466b")
				var star_rot: float = _hash_float(gx, gy, 10) * TAU
				var star_rad: float = 12.0 + _hash_float(gx, gy, 11) * 7.0
				_draw_starfish(star_pos, star_rad, star_rot, star_col)

			# Swaying kelp / seaweed
			if _hash_float(gx, gy, 12) < 0.48:
				var kelp_base := origin + Vector2((0.15 + _hash_float(gx, gy, 13) * 0.7) * TILE_SIZE, (0.25 + _hash_float(gx, gy, 14) * 0.65) * TILE_SIZE)
				var stalk_count: int = 2
				for s in range(stalk_count):
					var offset_x: float = (float(s) - 0.5) * 11.0
					var height: float = 48.0 + _hash_float(gx, gy, 16 + s) * 34.0
					var phase: float = _hash_float(gx, gy, 20 + s) * TAU
					_draw_kelp_stalk(kelp_base + Vector2(offset_x, 0.0), height, phase)

			# Rising shimmering bubbles
			var bubble_count: int = 1 + (_hash_int(gx, gy, 30) % 2)
			for b in range(bubble_count):
				var bx: float = origin.x + _hash_float(gx, gy, 31 + b * 3) * TILE_SIZE
				var speed: float = 28.0 + _hash_float(gx, gy, 32 + b * 3) * 26.0
				var phase_y: float = _hash_float(gx, gy, 33 + b * 3) * TILE_SIZE
				var by_local: float = fposmod(TILE_SIZE - fmod(_time * speed + phase_y, TILE_SIZE), TILE_SIZE)
				var wobble: float = sin(_time * 2.4 + phase_y + float(b)) * 7.0
				var b_pos := Vector2(bx + wobble, origin.y + by_local)
				if b_pos.x >= left - 20.0 and b_pos.x <= right + 20.0 and b_pos.y >= top - 20.0 and b_pos.y <= bottom + 20.0:
					var br: float = 2.8 + _hash_float(gx, gy, 40 + b) * 3.4
					var shimmer_a: float = 0.25 + 0.12 * sin(_time * 4.0 + phase_y)
					draw_arc(b_pos, br, 0.0, TAU, 10, Color(0.65, 1.0, 1.0, shimmer_a + 0.18), 1.2)


func _draw_coral_cluster(pos: Vector2, col: Color, gx: int, gy: int) -> void:
	var glow_col := Color(col.r, col.g, col.b, 0.055)
	var stem_col := Color(col.r, col.g, col.b, 0.18)
	var tip_col := Color(minf(1.0, col.r + 0.12), minf(1.0, col.g + 0.12), minf(1.0, col.b + 0.12), 0.25)
	draw_circle(pos + Vector2(0.0, -14.0), 26.0, glow_col)

	var branches: int = 3 + (_hash_int(gx, gy, 50) % 3)
	for i in range(branches):
		var spread: float = (float(i) - float(branches - 1) * 0.5) * 0.42
		var len_b: float = 20.0 + _hash_float(gx, gy, 51 + i) * 18.0
		var sway: float = sin(_time * 1.4 + float(gx + gy + i)) * 2.0
		var dir := Vector2(sin(spread), -cos(spread))
		var mid := pos + dir * (len_b * 0.55) + Vector2(sway * 0.5, 0.0)
		var tip := pos + dir * len_b + Vector2(sway, 0.0)
		draw_line(pos, mid, glow_col, 9.0)
		draw_line(mid, tip, glow_col, 7.0)
		draw_line(pos, mid, stem_col, 4.2)
		draw_line(mid, tip, stem_col, 3.2)
		draw_circle(tip, 4.2, tip_col)
		# Sub-fork
		if i % 2 == 0:
			var sub_dir := dir.rotated(0.45 if i == 0 else -0.45)
			var sub_tip := mid + sub_dir * (len_b * 0.45)
			draw_line(mid, sub_tip, stem_col, 2.8)
			draw_circle(sub_tip, 3.2, tip_col)


func _draw_starfish(pos: Vector2, radius: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var ang: float = rot + float(i) * (TAU / 10.0)
		var r: float = radius if (i % 2 == 0) else radius * 0.42
		pts.append(pos + Vector2(cos(ang), sin(ang)) * r)
	draw_polygon(pts, PackedColorArray([Color(col.r, col.g, col.b, 0.15)]))
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, Color(col.r, col.g, col.b, 0.26), 1.4)
	draw_circle(pos, radius * 0.18, Color(0.85, 0.85, 0.72, 0.22))


func _draw_kelp_stalk(base: Vector2, height: float, phase: float) -> void:
	var segments: int = 5
	var pts := PackedVector2Array()
	pts.append(base)
	for s in range(1, segments + 1):
		var frac: float = float(s) / float(segments)
		var sway: float = sin(_time * 2.1 + phase - frac * 2.4) * (10.0 * frac)
		pts.append(base + Vector2(sway, -height * frac))
	draw_polyline(pts, Color(0.06, 0.36, 0.42, 0.08), 7.0)
	draw_polyline(pts, Color(0.12, 0.50, 0.52, 0.20), 2.6)


func _draw_stage2_abyss(center: Vector2, left: float, right: float, top: float, bottom: float) -> void:
	_draw_vertical_gradient(
		left, right, top, bottom,
		Color(0.067, 0.027, 0.200, 1.0), # midnight indigo-violet
		Color(0.043, 0.020, 0.149, 1.0), # #0b0526
		Color(0.008, 0.004, 0.039, 1.0)  # #02010a
	)

	# Faint abyssal grid
	_draw_sonar_grid(
		left, right, top, bottom, 180.0,
		Color(0.55, 0.30, 0.95, 0.055),
		Color(0.0, 0.92, 0.98, 0.12)
	)

	var min_gx: int = int(floor(left / TILE_SIZE)) - 1
	var max_gx: int = int(floor(right / TILE_SIZE)) + 1
	var min_gy: int = int(floor(top / TILE_SIZE)) - 1
	var max_gy: int = int(floor(bottom / TILE_SIZE)) + 1

	var spore_palette: Array[Color] = [
		Color("#2b7d85"), # muted cyan
		Color("#684191"), # muted violet
		Color("#2c7a62"), # muted emerald
	]

	for gx in range(min_gx, max_gx + 1):
		for gy in range(min_gy, max_gy + 1):
			var origin := Vector2(float(gx) * TILE_SIZE, float(gy) * TILE_SIZE)
			var r0: float = _hash_float(gx, gy, 101)
			var r1: float = _hash_float(gx, gy, 102)
			var r2: float = _hash_float(gx, gy, 103)

			# Deep-sea sonar beacon rings
			if _hash_float(gx, gy, 104) < 0.18:
				var beacon_pos := origin + Vector2((0.25 + r1 * 0.5) * TILE_SIZE, (0.25 + r2 * 0.5) * TILE_SIZE)
				var cycle: float = fmod(_time * 0.55 + _hash_float(gx, gy, 105), 1.0)
				var ring_r: float = 14.0 + cycle * 96.0
				var ring_a: float = (1.0 - cycle) * 0.15
				draw_arc(beacon_pos, ring_r, 0.0, TAU, 36, Color(0.15, 0.62, 0.75, ring_a), 1.4)
				draw_arc(beacon_pos, ring_r * 0.58, 0.0, TAU, 28, Color(0.50, 0.28, 0.70, ring_a * 0.75), 1.0)
				draw_circle(beacon_pos, 3.0, Color(0.15, 0.65, 0.70, 0.22))

			# Glowing abyssal crystal formations
			if r0 < 0.46:
				var crys_pos := origin + Vector2((0.18 + r1 * 0.64) * TILE_SIZE, (0.2 + r2 * 0.6) * TILE_SIZE)
				var c_col: Color = spore_palette[_hash_int(gx, gy, 106) % spore_palette.size()]
				_draw_abyss_crystal(crys_pos, c_col, gx, gy)

			# Volcanic hydrothermal vent fissures with rising neon embers
			if _hash_float(gx, gy, 110) < 0.28:
				var vent_pos := origin + Vector2((0.2 + _hash_float(gx, gy, 111) * 0.6) * TILE_SIZE, (0.3 + _hash_float(gx, gy, 112) * 0.55) * TILE_SIZE)
				_draw_hydrothermal_vent(vent_pos, gx, gy)

			# Drifting bioluminescent spores (cyan/violet/emerald)
			var spore_count: int = 3 + (_hash_int(gx, gy, 120) % 2)
			for s in range(spore_count):
				var sx_base: float = origin.x + _hash_float(gx, gy, 121 + s * 4) * TILE_SIZE
				var sy_base: float = origin.y + _hash_float(gx, gy, 122 + s * 4) * TILE_SIZE
				var phase: float = _hash_float(gx, gy, 123 + s * 4) * TAU
				var drift := Vector2(
					sin(_time * 0.85 + phase) * 24.0,
					cos(_time * 0.65 + phase * 1.3) * 20.0
				)
				var s_pos := Vector2(sx_base, sy_base) + drift
				if s_pos.x < left - 24.0 or s_pos.x > right + 24.0 or s_pos.y < top - 24.0 or s_pos.y > bottom + 24.0:
					continue
				var s_col: Color = spore_palette[(_hash_int(gx, gy, 124 + s) + s) % spore_palette.size()]
				var pulse: float = 0.55 + 0.45 * sin(_time * 2.6 + phase)
				var rad: float = 2.2 + _hash_float(gx, gy, 140 + s) * 2.5
				draw_circle(s_pos, rad * 3.0, Color(s_col.r, s_col.g, s_col.b, 0.045 * pulse))
				draw_circle(s_pos, rad * 1.4, Color(s_col.r, s_col.g, s_col.b, 0.16 * pulse))
				draw_circle(s_pos, rad * 0.6, Color(0.75, 0.88, 0.92, 0.32 * pulse))


func _draw_abyss_crystal(pos: Vector2, col: Color, gx: int, gy: int) -> void:
	var pulse: float = 0.75 + 0.25 * sin(_time * 1.9 + float(gx * 3 + gy))
	draw_circle(pos + Vector2(0.0, -14.0), 32.0, Color(col.r, col.g, col.b, 0.055 * pulse))

	var shards: int = 3 + (_hash_int(gx, gy, 150) % 2)
	for i in range(shards):
		var tilt: float = (float(i) - float(shards - 1) * 0.5) * 0.42
		var h: float = 24.0 + _hash_float(gx, gy, 151 + i) * 22.0
		var w: float = 6.0 + _hash_float(gx, gy, 160 + i) * 4.0
		var axis := Vector2(sin(tilt), -cos(tilt))
		var perp := Vector2(-axis.y, axis.x)
		var base := pos + perp * (float(i) - float(shards - 1) * 0.5) * 7.0
		var tip := base + axis * h
		var left_pt := base + axis * (h * 0.28) - perp * w
		var right_pt := base + axis * (h * 0.28) + perp * w
		var poly := PackedVector2Array([base, left_pt, tip, right_pt])
		draw_polygon(poly, PackedColorArray([Color(col.r, col.g, col.b, 0.14 * pulse)]))
		var outline := PackedVector2Array([base, left_pt, tip, right_pt, base])
		draw_polyline(outline, Color(minf(1.0, col.r + 0.15), minf(1.0, col.g + 0.15), minf(1.0, col.b + 0.15), 0.28 * pulse), 1.4)


func _draw_hydrothermal_vent(pos: Vector2, gx: int, gy: int) -> void:
	var heat: float = 0.7 + 0.3 * sin(_time * 3.1 + float(gx + gy * 2))
	draw_circle(pos, 30.0, Color(0.75, 0.25, 0.18, 0.055 * heat))

	# Jagged magma-neon fissure cracks
	var crack_a := PackedVector2Array([
		pos + Vector2(-24.0, 4.0),
		pos + Vector2(-10.0, -3.0),
		pos + Vector2(2.0, 2.0),
		pos + Vector2(18.0, -5.0),
		pos + Vector2(26.0, 3.0),
	])
	var crack_b := PackedVector2Array([
		pos + Vector2(-6.0, -1.0),
		pos + Vector2(4.0, 10.0),
		pos + Vector2(14.0, 14.0),
	])
	draw_polyline(crack_a, Color(0.80, 0.25, 0.18, 0.11 * heat), 7.0)
	draw_polyline(crack_a, Color(0.82, 0.46, 0.18, 0.30 * heat), 2.2)
	draw_polyline(crack_b, Color(0.78, 0.38, 0.18, 0.24 * heat), 1.8)

	# Rising neon volcanic embers
	for e in range(4):
		var cycle: float = fmod(_time * (0.45 + 0.12 * float(e)) + _hash_float(gx, gy, 170 + e), 1.0)
		var ex: float = pos.x + (_hash_float(gx, gy, 180 + e) - 0.5) * 28.0 + sin(_time * 3.0 + float(e) * 1.7) * 8.0
		var ey: float = pos.y - cycle * 64.0
		var alpha: float = (1.0 - cycle) * 0.32
		var e_col := Color(0.82, 0.42 + 0.25 * (1.0 - cycle), 0.18, alpha)
		draw_circle(Vector2(ex, ey), 2.4 * (1.0 - cycle * 0.5), e_col)
