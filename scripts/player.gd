extends CharacterBody2D

## Neon Dolphin player controller with 8-directional movement, procedural neon visuals,
## 4 auto-attack weapons (sonic_pulse, bubble_barrage, hydro_orbit, bio_lightning),
## and world-space HP bar.

signal hp_changed(current_hp: float, max_hp: float)
signal died()

const PROJECTILE_SCRIPT: GDScript = preload("res://scripts/projectile.gd")

var max_hp: float = 100.0
var hp: float = 100.0
var move_speed: float = 260.0
var pickup_radius: float = 135.0
var projectile_container: Node2D = null
var fx_manager: Node2D = null
var autotest_move_dir: Vector2 = Vector2.ZERO
var touch_move_dir: Vector2 = Vector2.ZERO
var weapon_levels: Dictionary = {
	"sonic_pulse": 1,
	"bubble_barrage": 0,
	"hydro_orbit": 0,
	"bio_lightning": 0
}

var _is_dead: bool = false
var _invuln_timer: float = 0.0
var _swim_time: float = 0.0
var _facing_angle: float = 0.0
var _flip_sign: float = 1.0

# Weapon timers and states
var _sonic_timer: float = 0.25
var _bubble_timer: float = 0.45
var _lightning_timer: float = 0.85
var _orbit_angle: float = 0.0
var _orbit_hit_cooldowns: Dictionary = {}
var _sonar_ring_timer: float = 0.0
var _lightning_fx_timer: float = 0.0
var _lightning_arcs: Array[PackedVector2Array] = []
var _sfx_throttle_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	z_index = 10
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 0

	var col_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	col_shape.shape = circle
	add_child(col_shape)


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	_swim_time += delta
	if _sfx_throttle_timer > 0.0:
		_sfx_throttle_timer = maxf(0.0, _sfx_throttle_timer - delta)

	if _invuln_timer > 0.0:
		_invuln_timer = maxf(0.0, _invuln_timer - delta)
		var blink_on: bool = fmod(_invuln_timer * 18.0, 1.0) > 0.45
		modulate = Color(1.0, 0.55, 0.65, 0.72) if blink_on else Color.WHITE
		if _invuln_timer <= 0.0:
			modulate = Color.WHITE

	_handle_movement(delta)
	_update_weapons(delta)

	if _sonar_ring_timer > 0.0:
		_sonar_ring_timer = maxf(0.0, _sonar_ring_timer - delta)
	if _lightning_fx_timer > 0.0:
		_lightning_fx_timer = maxf(0.0, _lightning_fx_timer - delta)
		if _lightning_fx_timer <= 0.0:
			_lightning_arcs.clear()

	queue_redraw()


func _handle_movement(delta: float) -> void:
	var move_dir: Vector2 = Vector2.ZERO
	if autotest_move_dir.length_squared() > 0.01:
		move_dir = autotest_move_dir.normalized()
	elif touch_move_dir.length_squared() > 0.01:
		move_dir = touch_move_dir.normalized() if touch_move_dir.length_squared() > 1.0 else touch_move_dir
	else:
		var ix: float = 0.0
		var iy: float = 0.0
		if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
			ix += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
			ix -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
			iy += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
			iy -= 1.0

		# Gamepad / Controller support (Left Stick + D-Pad across connected joypads)
		for jid in Input.get_connected_joypads():
			var ax: float = Input.get_joy_axis(jid, JOY_AXIS_LEFT_X)
			var ay: float = Input.get_joy_axis(jid, JOY_AXIS_LEFT_Y)
			if absf(ax) > 0.18:
				ix += ax
			if absf(ay) > 0.18:
				iy += ay
			if Input.is_joy_button_pressed(jid, JOY_BUTTON_DPAD_RIGHT):
				ix += 1.0
			if Input.is_joy_button_pressed(jid, JOY_BUTTON_DPAD_LEFT):
				ix -= 1.0
			if Input.is_joy_button_pressed(jid, JOY_BUTTON_DPAD_DOWN):
				iy += 1.0
			if Input.is_joy_button_pressed(jid, JOY_BUTTON_DPAD_UP):
				iy -= 1.0

		move_dir = Vector2(ix, iy)
		if move_dir.length_squared() > 1.0:
			move_dir = move_dir.normalized()

	velocity = move_dir * move_speed
	move_and_slide()

	if move_dir.length_squared() > 0.001:
		var target_angle: float = move_dir.angle()
		_facing_angle = lerp_angle(_facing_angle, target_angle, clampf(delta * 14.0, 0.0, 1.0))

	# Keep dorsal fin facing skyward even when swimming left
	var target_flip: float = -1.0 if cos(_facing_angle) < -0.08 else 1.0
	_flip_sign = lerpf(_flip_sign, target_flip, clampf(delta * 16.0, 0.0, 1.0))
	if absf(_flip_sign) < 0.15:
		_flip_sign = 0.15 if target_flip >= 0.0 else -0.15


func _update_weapons(delta: float) -> void:
	# 1. Sonic Pulse
	var sonic_lv: int = int(weapon_levels.get("sonic_pulse", 0))
	if sonic_lv > 0:
		_sonic_timer -= delta
		if _sonic_timer <= 0.0:
			_sonic_timer = maxf(0.32, 0.88 - float(sonic_lv - 1) * 0.11)
			_fire_sonic_pulse(sonic_lv)

	# 2. Bubble Barrage
	var bubble_lv: int = int(weapon_levels.get("bubble_barrage", 0))
	if bubble_lv > 0:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			_bubble_timer = maxf(0.45, 1.25 - float(bubble_lv - 1) * 0.14)
			_fire_bubble_barrage(bubble_lv)

	# 3. Hydro Orbit
	var orbit_lv: int = int(weapon_levels.get("hydro_orbit", 0))
	if orbit_lv > 0:
		_update_hydro_orbit(delta, orbit_lv)

	# 4. Bio Lightning
	var bolt_lv: int = int(weapon_levels.get("bio_lightning", 0))
	if bolt_lv > 0:
		_lightning_timer -= delta
		if _lightning_timer <= 0.0:
			_lightning_timer = maxf(1.2, 3.0 - float(bolt_lv - 1) * 0.32)
			_fire_bio_lightning(bolt_lv)


func _get_nearest_enemy_dir() -> Vector2:
	if not is_inside_tree():
		return Vector2.from_angle(_facing_angle)
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var best_dist_sq: float = INF
	var best_node: Node2D = null
	for node in enemies:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var enemy_node := node as Node2D
		var d_sq: float = global_position.distance_squared_to(enemy_node.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_node = enemy_node
	if best_node != null and best_dist_sq > 0.001:
		return (best_node.global_position - global_position).normalized()
	return Vector2.from_angle(_facing_angle)


func _spawn_projectile_node(proj: Area2D) -> void:
	var target_parent: Node = projectile_container if is_instance_valid(projectile_container) else get_parent()
	if is_instance_valid(target_parent):
		target_parent.add_child(proj)


func _fire_sonic_pulse(lv: int) -> void:
	var aim_dir: Vector2 = _get_nearest_enemy_dir()
	var count: int = 1
	if lv >= 5:
		count = 3
	elif lv >= 3:
		count = 2

	var spread_step: float = 0.22
	var start_offset: float = -spread_step * float(count - 1) * 0.5
	var dmg: float = 18.0 + float(lv - 1) * 7.0
	var pierce_val: int = 1 + int(lv / 2)
	var speed_val: float = 480.0 + float(lv) * 20.0
	var rad: float = 15.0 + float(lv) * 1.5

	for i in count:
		var dir: Vector2 = aim_dir.rotated(start_offset + float(i) * spread_step)
		var proj := PROJECTILE_SCRIPT.new() as Area2D
		proj.global_position = global_position + dir * 20.0
		proj.set("proj_type", "sonic")
		proj.set("velocity", dir * speed_val)
		proj.set("damage", dmg)
		proj.set("pierce", pierce_val)
		proj.set("lifetime", 1.45)
		proj.set("radius", rad)
		proj.set("color", Color("#00f5d4"))
		proj.set("fx_manager", fx_manager)
		_spawn_projectile_node(proj)

	_sonar_ring_timer = 0.35
	_play_shoot_sfx()


func _fire_bubble_barrage(lv: int) -> void:
	var aim_dir: Vector2 = _get_nearest_enemy_dir()
	var count: int = 2 + lv
	var total_arc: float = minf(1.25, 0.32 + float(count) * 0.13)
	var dmg: float = 12.0 + float(lv - 1) * 5.0
	var pierce_val: int = 2 if lv >= 4 else 1

	for i in count:
		var t: float = float(i) / maxf(float(count - 1), 1.0) - 0.5
		var angle_offset: float = t * total_arc + randf_range(-0.05, 0.05)
		var dir: Vector2 = aim_dir.rotated(angle_offset)
		var spd: float = randf_range(340.0, 415.0)
		var b_color: Color = Color("#ff4fd8") if i % 2 == 0 else Color("#38bdf8")

		var proj := PROJECTILE_SCRIPT.new() as Area2D
		proj.global_position = global_position + dir * 16.0
		proj.set("proj_type", "bubble")
		proj.set("velocity", dir * spd)
		proj.set("damage", dmg)
		proj.set("pierce", pierce_val)
		proj.set("lifetime", 1.55)
		proj.set("radius", 10.5 + float(lv) * 0.8)
		proj.set("color", b_color)
		proj.set("fx_manager", fx_manager)
		_spawn_projectile_node(proj)

	_play_shoot_sfx()


func _update_hydro_orbit(delta: float, lv: int) -> void:
	var orb_speed: float = 2.8 + float(lv) * 0.35
	_orbit_angle = wrapf(_orbit_angle + orb_speed * delta, 0.0, TAU)

	# Decay per-enemy hit cooldowns
	var expired: Array = []
	for eid in _orbit_hit_cooldowns.keys():
		var rem: float = float(_orbit_hit_cooldowns[eid]) - delta
		if rem <= 0.0:
			expired.append(eid)
		else:
			_orbit_hit_cooldowns[eid] = rem
	for eid in expired:
		_orbit_hit_cooldowns.erase(eid)

	if not is_inside_tree():
		return

	var orb_count: int = 1 + lv
	var orbit_r: float = _get_orbit_radius(lv)
	var orb_hit_r: float = 14.0
	var dmg: float = 14.0 + float(lv - 1) * 6.0
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")

	for node in enemies:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		if not node.has_method("take_damage"):
			continue
		var enemy_node := node as Node2D
		var eid: int = enemy_node.get_instance_id()
		if _orbit_hit_cooldowns.has(eid):
			continue

		var e_radius: float = 18.0
		var hr: Variant = enemy_node.get("hit_radius")
		if hr != null:
			e_radius = float(hr)
		var hit_dist_sq: float = (orb_hit_r + e_radius) * (orb_hit_r + e_radius)

		for k in orb_count:
			var ang: float = _orbit_angle + TAU * float(k) / float(orb_count)
			var orb_world_pos: Vector2 = global_position + Vector2.from_angle(ang) * orbit_r
			if orb_world_pos.distance_squared_to(enemy_node.global_position) <= hit_dist_sq:
				var kb_dir: Vector2 = (enemy_node.global_position - global_position).normalized()
				enemy_node.take_damage(dmg, kb_dir * 125.0)
				_orbit_hit_cooldowns[eid] = 0.38
				if is_instance_valid(fx_manager) and fx_manager.has_method("spawn_hit_burst"):
					fx_manager.spawn_hit_burst(enemy_node.global_position, Color("#38bdf8"), 6)
				if _sfx_throttle_timer <= 0.0:
					_play_hit_sfx()
					_sfx_throttle_timer = 0.08
				break


func _fire_bio_lightning(lv: int) -> void:
	var shock_radius: float = 135.0 + float(lv - 1) * 26.0
	var dmg: float = 24.0 + float(lv - 1) * 10.0

	if is_instance_valid(fx_manager):
		if fx_manager.has_method("spawn_shockwave_ring"):
			fx_manager.spawn_shockwave_ring(global_position, shock_radius, Color("#a855f7"))
			fx_manager.spawn_shockwave_ring(global_position, shock_radius * 0.72, Color("#00f5d4"))
		if fx_manager.has_method("trigger_shake"):
			fx_manager.trigger_shake(4.0, 0.14)

	_lightning_arcs.clear()
	_lightning_fx_timer = 0.24

	if is_inside_tree():
		var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
		var r_sq: float = shock_radius * shock_radius
		for node in enemies:
			if not is_instance_valid(node) or not (node is Node2D):
				continue
			if not node.has_method("take_damage"):
				continue
			var enemy_node := node as Node2D
			var diff: Vector2 = enemy_node.global_position - global_position
			if diff.length_squared() <= r_sq:
				var kb_dir: Vector2 = diff.normalized() if diff.length_squared() > 0.001 else Vector2.RIGHT
				enemy_node.take_damage(dmg, kb_dir * 175.0)
				if is_instance_valid(fx_manager) and fx_manager.has_method("spawn_hit_burst"):
					fx_manager.spawn_hit_burst(enemy_node.global_position, Color("#c084fc"), 8)
				if _lightning_arcs.size() < 8:
					_lightning_arcs.append(_build_jagged_arc(Vector2.ZERO, to_local(enemy_node.global_position)))

	# Decorative radial arcs even when no enemies are nearby
	if _lightning_arcs.is_empty():
		for i in 4:
			var ang: float = randf() * TAU
			_lightning_arcs.append(_build_jagged_arc(Vector2.ZERO, Vector2.from_angle(ang) * (shock_radius * 0.75)))

	_play_shoot_sfx()


func _build_jagged_arc(from_pt: Vector2, to_pt: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(from_pt)
	var segments: int = 4
	var delta_v: Vector2 = to_pt - from_pt
	var perp: Vector2 = Vector2(-delta_v.y, delta_v.x).normalized()
	for i in range(1, segments):
		var t: float = float(i) / float(segments)
		var jitter: float = randf_range(-14.0, 14.0)
		pts.append(from_pt.lerp(to_pt, t) + perp * jitter)
	pts.append(to_pt)
	return pts


func _get_orbit_radius(lv: int) -> float:
	return 66.0 + float(mini(lv, 4)) * 5.0


func _play_shoot_sfx() -> void:
	if _sfx_throttle_timer > 0.0 or not is_inside_tree():
		return
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr != null and sound_mgr.has_method("play_shoot"):
		sound_mgr.play_shoot()
		_sfx_throttle_timer = 0.06


func _play_hit_sfx() -> void:
	if not is_inside_tree():
		return
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr != null and sound_mgr.has_method("play_hit"):
		sound_mgr.play_hit()


func take_damage(amount: float) -> void:
	if _is_dead or _invuln_timer > 0.0 or amount <= 0.0:
		return

	hp = maxf(0.0, hp - amount)
	_invuln_timer = 0.45
	hp_changed.emit(hp, max_hp)

	if is_instance_valid(fx_manager):
		if fx_manager.has_method("trigger_shake"):
			fx_manager.trigger_shake(7.5, 0.22)
		if fx_manager.has_method("spawn_floating_text"):
			fx_manager.spawn_floating_text(global_position + Vector2(0.0, -26.0), "-" + str(int(round(amount))), Color("#ff4d6d"))
		if fx_manager.has_method("spawn_hit_burst"):
			fx_manager.spawn_hit_burst(global_position, Color("#ff4d6d"), 10)

	if is_inside_tree():
		var sound_mgr: Node = get_node_or_null("/root/SoundManager")
		if sound_mgr != null and sound_mgr.has_method("play_hurt"):
			sound_mgr.play_hurt()

	if hp <= 0.0:
		_is_dead = true
		died.emit()


func apply_upgrade(upgrade_id: String) -> void:
	var label_text: String = "อัปเกรด!"
	var fx_color: Color = Color("#00f5d4")

	match upgrade_id:
		"sonic_pulse":
			weapon_levels["sonic_pulse"] = mini(int(weapon_levels.get("sonic_pulse", 1)) + 1, 5)
			label_text = "โซนาร์ Lv.%d" % int(weapon_levels["sonic_pulse"])
			fx_color = Color("#00f5d4")
		"bubble_barrage":
			weapon_levels["bubble_barrage"] = mini(int(weapon_levels.get("bubble_barrage", 0)) + 1, 5)
			label_text = "ฟองอากาศ Lv.%d" % int(weapon_levels["bubble_barrage"])
			fx_color = Color("#38bdf8")
		"hydro_orbit":
			weapon_levels["hydro_orbit"] = mini(int(weapon_levels.get("hydro_orbit", 0)) + 1, 5)
			label_text = "น้ำวน Lv.%d" % int(weapon_levels["hydro_orbit"])
			fx_color = Color("#f15bb5")
		"bio_lightning":
			weapon_levels["bio_lightning"] = mini(int(weapon_levels.get("bio_lightning", 0)) + 1, 5)
			label_text = "สายฟ้า Lv.%d" % int(weapon_levels["bio_lightning"])
			fx_color = Color("#a855f7")
		"speed_boost":
			move_speed *= 1.15
			label_text = "ว่ายเร็ว +15%"
			fx_color = Color("#4ade80")
		"max_hp":
			max_hp += 25.0
			hp = minf(max_hp, hp + 30.0)
			hp_changed.emit(hp, max_hp)
			label_text = "พลังชีวิต +25"
			fx_color = Color("#fb7185")
		"magnet_range":
			pickup_radius *= 1.45
			label_text = "ดูดไกล +45%"
			fx_color = Color("#facc15")
		_:
			pass

	if is_instance_valid(fx_manager):
		if fx_manager.has_method("spawn_shockwave_ring"):
			fx_manager.spawn_shockwave_ring(global_position, 95.0, fx_color)
		if fx_manager.has_method("spawn_floating_text"):
			fx_manager.spawn_floating_text(global_position + Vector2(0.0, -32.0), label_text, fx_color)

	queue_redraw()


func reset_player() -> void:
	max_hp = 100.0
	hp = 100.0
	move_speed = 260.0
	pickup_radius = 135.0
	autotest_move_dir = Vector2.ZERO
	touch_move_dir = Vector2.ZERO
	velocity = Vector2.ZERO
	weapon_levels = {
		"sonic_pulse": 1,
		"bubble_barrage": 0,
		"hydro_orbit": 0,
		"bio_lightning": 0
	}
	_is_dead = false
	_invuln_timer = 0.0
	_facing_angle = 0.0
	_flip_sign = 1.0
	_sonic_timer = 0.25
	_bubble_timer = 0.45
	_lightning_timer = 0.85
	_orbit_angle = 0.0
	_orbit_hit_cooldowns.clear()
	_sonar_ring_timer = 0.0
	_lightning_fx_timer = 0.0
	_lightning_arcs.clear()
	_sfx_throttle_timer = 0.0
	modulate = Color.WHITE
	hp_changed.emit(hp, max_hp)
	queue_redraw()


func get_weapon_summary() -> String:
	var parts: PackedStringArray = []
	var sonic_lv: int = int(weapon_levels.get("sonic_pulse", 0))
	if sonic_lv > 0:
		parts.append("โซนาร์ Lv.%d" % sonic_lv)
	var bubble_lv: int = int(weapon_levels.get("bubble_barrage", 0))
	if bubble_lv > 0:
		parts.append("ฟองอากาศ Lv.%d" % bubble_lv)
	var orbit_lv: int = int(weapon_levels.get("hydro_orbit", 0))
	if orbit_lv > 0:
		parts.append("น้ำวน Lv.%d" % orbit_lv)
	var bolt_lv: int = int(weapon_levels.get("bio_lightning", 0))
	if bolt_lv > 0:
		parts.append("สายฟ้า Lv.%d" % bolt_lv)
	return " | ".join(parts)


func _draw() -> void:
	# 1. World-aligned aura, sonar pulse, bio-lightning arcs, and hydro orbitals
	_draw_sonar_and_aura()
	_draw_lightning_arcs()
	_draw_hydro_orbitals()

	# 2. Rotated + horizontally-aware Neon Dolphin body
	draw_set_transform(Vector2.ZERO, _facing_angle, Vector2(1.0, _flip_sign))
	_draw_neon_dolphin()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 3. Compact world-space HP bar below dolphin
	_draw_world_hp_bar()


func _draw_sonar_and_aura() -> void:
	var idle_pulse: float = 0.5 + 0.5 * sin(_swim_time * 3.4)
	draw_circle(Vector2.ZERO, 28.0 + idle_pulse * 4.0, Color("#00f5d4", 0.10))

	if _sonar_ring_timer > 0.0:
		var t: float = 1.0 - clampf(_sonar_ring_timer / 0.35, 0.0, 1.0)
		var ring_r: float = lerpf(16.0, 56.0, t)
		var alpha: float = (1.0 - t) * 0.72
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 32, Color("#00f5d4", alpha), 2.4, true)


func _draw_lightning_arcs() -> void:
	if _lightning_fx_timer <= 0.0 or _lightning_arcs.is_empty():
		return
	var alpha: float = clampf(_lightning_fx_timer / 0.24, 0.0, 1.0)
	for arc in _lightning_arcs:
		draw_polyline(arc, Color("#a855f7", alpha * 0.55), 5.0, true)
		draw_polyline(arc, Color("#e0f2fe", alpha * 0.95), 2.0, true)


func _draw_hydro_orbitals() -> void:
	var orbit_lv: int = int(weapon_levels.get("hydro_orbit", 0))
	if orbit_lv <= 0:
		return
	var orb_count: int = 1 + orbit_lv
	var orbit_r: float = _get_orbit_radius(orbit_lv)

	# Faint orbital guide ring
	draw_arc(Vector2.ZERO, orbit_r, 0.0, TAU, 48, Color("#38bdf8", 0.22), 1.5, true)

	for k in orb_count:
		var ang: float = _orbit_angle + TAU * float(k) / float(orb_count)
		var pos: Vector2 = Vector2.from_angle(ang) * orbit_r
		# Spinning trailing vortex arc
		draw_arc(Vector2.ZERO, orbit_r, ang - 0.38, ang, 10, Color("#00f5d4", 0.55), 3.2, true)
		# Orb glow & core
		draw_circle(pos, 15.0, Color("#38bdf8", 0.24))
		draw_circle(pos, 9.5, Color("#00f5d4", 0.88))
		draw_arc(pos, 10.5, _swim_time * 4.0 + float(k), _swim_time * 4.0 + float(k) + PI * 1.3, 12, Color("#ffffff", 0.85), 1.8, true)
		draw_circle(pos, 4.2, Color(1.0, 1.0, 1.0, 0.95))


func _draw_neon_dolphin() -> void:
	var moving_factor: float = clampf(velocity.length() / maxf(move_speed, 1.0), 0.18, 1.0)
	var tail_swing: float = sin(_swim_time * (6.5 + moving_factor * 7.5)) * (5.5 + moving_factor * 4.5)
	var fin_flutter: float = sin(_swim_time * 7.0) * 2.0

	var cyan_glow := Color("#00f5d4")
	var ocean_cyan := Color("#0ea5e9")
	var belly_tint := Color("#a5f3fc")
	var fin_tint := Color("#0284c7")

	# Back pectoral fin (subtle)
	var back_pec := PackedVector2Array([
		Vector2(2.0, 5.0),
		Vector2(-6.0, 14.0 - fin_flutter * 0.4),
		Vector2(-10.0, 7.0)
	])
	draw_colored_polygon(back_pec, fin_tint)

	# Dorsal fin
	var dorsal := PackedVector2Array([
		Vector2(3.0, -9.0),
		Vector2(-7.0, -24.0),
		Vector2(-13.0, -21.0),
		Vector2(-9.0, -8.0)
	])
	draw_colored_polygon(dorsal, ocean_cyan)
	draw_polyline(PackedVector2Array([Vector2(3.0, -9.0), Vector2(-7.0, -24.0), Vector2(-13.0, -21.0)]), cyan_glow, 2.0, true)

	# Sweeping tail fluke (animated)
	var tail_base := Vector2(-20.0, tail_swing * 0.45)
	var tail_tip := Vector2(-31.0, tail_swing)
	var fluke := PackedVector2Array([
		tail_base + Vector2(3.0, -2.5),
		tail_tip + Vector2(-7.0, -13.0),
		tail_tip + Vector2(-2.0, -1.0),
		tail_tip + Vector2(-7.0, 13.0),
		tail_base + Vector2(3.0, 2.5)
	])
	draw_colored_polygon(fluke, ocean_cyan)
	draw_polyline(fluke, cyan_glow, 1.8, true)

	# Main sleek dolphin silhouette (with rostrum/snout on +X)
	var body := PackedVector2Array([
		Vector2(30.0, 2.0),           # Rostrum tip
		Vector2(22.0, -1.5),          # Snout bridge
		Vector2(17.0, -8.5),          # Forehead melon
		Vector2(6.0, -11.5),          # Upper back
		Vector2(-10.0, -8.5 + tail_swing * 0.2),
		Vector2(-22.0, -3.0 + tail_swing * 0.45),
		Vector2(-22.0, 3.0 + tail_swing * 0.45),
		Vector2(-10.0, 8.0 + tail_swing * 0.2),
		Vector2(7.0, 9.5),            # Belly curve
		Vector2(19.0, 6.0),           # Lower jaw
		Vector2(29.0, 3.8)            # Lower snout
	])

	# Neon outer glow silhouette
	draw_polyline(body, Color(cyan_glow, 0.35), 7.0, true)
	draw_colored_polygon(body, ocean_cyan)

	# Lighter glowing belly highlight
	var belly := PackedVector2Array([
		Vector2(24.0, 3.0),
		Vector2(15.0, 1.0),
		Vector2(4.0, 2.5),
		Vector2(-9.0, 4.5 + tail_swing * 0.15),
		Vector2(-6.0, 7.6 + tail_swing * 0.2),
		Vector2(7.0, 9.0),
		Vector2(19.0, 5.6)
	])
	draw_colored_polygon(belly, Color(belly_tint, 0.72))

	# Crisp neon outline around body
	var closed_body := body.duplicate()
	closed_body.append(body[0])
	draw_polyline(closed_body, cyan_glow, 2.2, true)

	# Foreground pectoral fin
	var front_pec := PackedVector2Array([
		Vector2(6.0, 4.5),
		Vector2(-3.0, 17.5 + fin_flutter),
		Vector2(-9.0, 14.5 + fin_flutter * 0.7),
		Vector2(-2.0, 6.0)
	])
	draw_colored_polygon(front_pec, cyan_glow.darkened(0.15))
	draw_polyline(front_pec, Color(1.0, 1.0, 1.0, 0.75), 1.5, true)

	# Cute eye with bright highlight
	var eye_pos := Vector2(15.5, -2.2)
	draw_circle(eye_pos, 3.1, Color("#041526"))
	draw_circle(eye_pos + Vector2(0.8, -0.8), 1.2, Color.WHITE)


func _draw_world_hp_bar() -> void:
	var bar_w: float = 48.0
	var bar_h: float = 6.0
	var top_left := Vector2(-bar_w * 0.5, 31.0)
	var ratio: float = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)

	# Background & border
	draw_rect(Rect2(top_left - Vector2(1.0, 1.0), Vector2(bar_w + 2.0, bar_h + 2.0)), Color(0.02, 0.06, 0.12, 0.85), true)
	draw_rect(Rect2(top_left, Vector2(bar_w, bar_h)), Color(0.12, 0.18, 0.28, 0.9), true)

	# Fill color shifts from cyan-green to amber to red when low
	var fill_col: Color = Color("#00f5d4")
	if ratio < 0.32:
		fill_col = Color("#ff4d6d")
	elif ratio < 0.62:
		fill_col = Color("#fbbf24")

	if ratio > 0.0:
		draw_rect(Rect2(top_left, Vector2(bar_w * ratio, bar_h)), fill_col, true)
	draw_rect(Rect2(top_left - Vector2(1.0, 1.0), Vector2(bar_w + 2.0, bar_h + 2.0)), Color(fill_col, 0.55), false, 1.0)
