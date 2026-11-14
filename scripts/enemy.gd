extends CharacterBody2D

var enemy_type: String = "jellyfish"
var hp: float = 24.0
var max_hp: float = 24.0
var speed: float = 95.0
var damage: float = 10.0
var xp_drop: int = 3
var score_value: int = 15
var hit_radius: float = 20.0
var gem_container: Node2D = null
var fx_manager: Node2D = null
var player_ref: Node2D = null

var _anim_phase: float = 0.0
var _flash_timer: float = 0.0
var _contact_cooldown: float = 0.0
var _knockback_vel: Vector2 = Vector2.ZERO
var _facing_angle: float = 0.0
var _is_dead: bool = false
var _collision_shape: CollisionShape2D = null
var _wander_seed: float = 0.0

static var _xp_gem_script: Script = null


func _ready() -> void:
	add_to_group("enemies")
	z_index = 3
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 0
	_anim_phase = randf() * TAU
	_wander_seed = randf() * TAU

	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = hit_radius
		_collision_shape.shape = circle
		add_child(_collision_shape)
	elif _collision_shape.shape is CircleShape2D:
		(_collision_shape.shape as CircleShape2D).radius = hit_radius

	queue_redraw()


func setup(type: String, player: Node2D, gems: Node2D, fx: Node2D, hp_mult: float = 1.0, spd_mult: float = 1.0) -> void:
	enemy_type = type
	player_ref = player
	gem_container = gems
	fx_manager = fx

	match enemy_type:
		"jellyfish":
			max_hp = 24.0 * hp_mult
			speed = 92.0 * spd_mult
			damage = 10.0
			xp_drop = 3
			score_value = 15
			hit_radius = 19.0
		"crab":
			max_hp = 36.0 * hp_mult
			speed = 108.0 * spd_mult
			damage = 12.0
			xp_drop = 4
			score_value = 22
			hit_radius = 20.0
		"pufferfish":
			max_hp = 48.0 * hp_mult
			speed = 78.0 * spd_mult
			damage = 15.0
			xp_drop = 5
			score_value = 30
			hit_radius = 23.0
		"shark":
			max_hp = 62.0 * hp_mult
			speed = 155.0 * spd_mult
			damage = 18.0
			xp_drop = 8
			score_value = 45
			hit_radius = 24.0
		"anglerfish":
			max_hp = 78.0 * hp_mult
			speed = 115.0 * spd_mult
			damage = 20.0
			xp_drop = 9
			score_value = 55
			hit_radius = 24.0
		"abyss_jelly":
			max_hp = 96.0 * hp_mult
			speed = 98.0 * spd_mult
			damage = 22.0
			xp_drop = 12
			score_value = 70
			hit_radius = 28.0
		"kraken":
			max_hp = 340.0 * hp_mult
			speed = 82.0 * spd_mult
			damage = 28.0
			xp_drop = 35
			score_value = 250
			hit_radius = 40.0
		_:
			max_hp = 24.0 * hp_mult
			speed = 95.0 * spd_mult
			damage = 10.0
			xp_drop = 3
			score_value = 15
			hit_radius = 20.0

	hp = max_hp
	if _collision_shape != null and _collision_shape.shape is CircleShape2D:
		(_collision_shape.shape as CircleShape2D).radius = hit_radius
	queue_redraw()


func _process(delta: float) -> void:
	_anim_phase += delta * 5.2
	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _contact_cooldown > 0.0:
		_contact_cooldown = maxf(0.0, _contact_cooldown - delta)

	if not is_instance_valid(player_ref):
		var tree: SceneTree = get_tree()
		if tree != null:
			player_ref = tree.get_first_node_in_group("player") as Node2D

	var move_dir := Vector2.ZERO
	if is_instance_valid(player_ref):
		var to_player: Vector2 = player_ref.global_position - global_position
		var dist: float = to_player.length()
		if dist > 1.0:
			move_dir = to_player / dist
		if enemy_type == "crab":
			var perp := Vector2(-move_dir.y, move_dir.x)
			move_dir = (move_dir + perp * sin(_anim_phase * 1.4) * 0.42).normalized()
		elif enemy_type == "jellyfish" or enemy_type == "abyss_jelly":
			var pulse_speed_mod: float = 0.72 + 0.48 * maxf(0.0, sin(_anim_phase * 0.9))
			move_dir *= pulse_speed_mod

		if dist < hit_radius + 18.0 and _contact_cooldown <= 0.0:
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(damage)
			_contact_cooldown = 0.55
	else:
		move_dir = Vector2(cos(_wander_seed + _anim_phase * 0.25), sin(_wander_seed + _anim_phase * 0.25)) * 0.55

	# Soft separation from nearby enemies so swarms stay readable without physics sticking
	var sep := Vector2.ZERO
	var tree_ref: SceneTree = get_tree()
	if tree_ref != null:
		var enemies: Array[Node] = tree_ref.get_nodes_in_group("enemies")
		var count: int = enemies.size()
		var stride: int = 1 if count <= 50 else 2
		var i: int = 0
		while i < count:
			var other := enemies[i] as Node2D
			i += stride
			if other == null or other == self or not is_instance_valid(other):
				continue
			var diff: Vector2 = global_position - other.global_position
			var min_dist: float = hit_radius + 16.0
			var d_sq: float = diff.length_squared()
			if d_sq > 0.01 and d_sq < min_dist * min_dist:
				var d: float = sqrt(d_sq)
				sep += (diff / d) * ((min_dist - d) / min_dist) * 140.0

	_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, 680.0 * delta)
	velocity = move_dir * speed + sep + _knockback_vel
	move_and_slide()

	if move_dir.length_squared() > 0.01:
		var target_angle: float = move_dir.angle()
		_facing_angle = lerp_angle(_facing_angle, target_angle, clampf(delta * 8.0, 0.0, 1.0))


func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if _is_dead:
		return

	hp -= amount
	_flash_timer = 0.11
	var kb_scale: float = 0.35 if enemy_type == "kraken" else 1.0
	_knockback_vel += knockback * kb_scale

	if is_instance_valid(fx_manager) and fx_manager.has_method("spawn_floating_text"):
		fx_manager.spawn_floating_text(global_position + Vector2(0, -18), str(int(round(amount))), Color.WHITE)

	if hp <= 0.0:
		_is_dead = true
		_spawn_xp_gem()
		if is_instance_valid(fx_manager) and fx_manager.has_method("spawn_hit_burst"):
			fx_manager.spawn_hit_burst(global_position, _get_primary_color(), 16 if enemy_type == "kraken" else 10)
		var gd: Node = get_node_or_null("/root/GameData")
		if gd != null and gd.has_method("register_kill"):
			gd.register_kill(score_value)
		queue_free()


func _spawn_xp_gem() -> void:
	if _xp_gem_script == null and ResourceLoader.exists("res://scripts/xp_gem.gd"):
		_xp_gem_script = load("res://scripts/xp_gem.gd") as Script
	if _xp_gem_script == null:
		return

	var target_parent: Node = gem_container if is_instance_valid(gem_container) else get_parent()
	if not is_instance_valid(target_parent):
		return

	var gem: Area2D = _xp_gem_script.new() as Area2D
	if gem == null:
		return
	if target_parent is Node2D:
		gem.position = (target_parent as Node2D).to_local(global_position)
	else:
		gem.position = global_position
	gem.xp_value = xp_drop
	gem.gem_color = _get_gem_color()
	gem.player_ref = player_ref
	target_parent.call_deferred("add_child", gem)


func _get_primary_color() -> Color:
	match enemy_type:
		"jellyfish":
			return Color("#ff2a85")
		"crab":
			return Color("#ff6b35")
		"pufferfish":
			return Color("#d9ff00")
		"shark":
			return Color("#ff1e42")
		"anglerfish":
			return Color("#9eff00")
		"abyss_jelly":
			return Color("#b5179e")
		"kraken":
			return Color("#ff0099")
		_:
			return Color("#00f5d4")


func _get_gem_color() -> Color:
	match enemy_type:
		"kraken":
			return Color("#7dd3fc")
		"abyss_jelly", "anglerfish", "shark":
			return Color("#00b4ff")
		_:
			return Color("#38bdf8")


func _flash_col(c: Color) -> Color:
	if _flash_timer <= 0.0:
		return c
	var t: float = clampf(_flash_timer / 0.11, 0.0, 1.0) * 0.85
	return c.lerp(Color.WHITE, t)


func _draw() -> void:
	match enemy_type:
		"jellyfish":
			_draw_jellyfish()
		"crab":
			_draw_crab()
		"pufferfish":
			_draw_pufferfish()
		"shark":
			_draw_shark()
		"anglerfish":
			_draw_anglerfish()
		"abyss_jelly":
			_draw_abyss_jelly()
		"kraken":
			_draw_kraken()
		_:
			_draw_jellyfish()

	if _flash_timer > 0.0:
		var ft: float = clampf(_flash_timer / 0.11, 0.0, 1.0)
		draw_circle(Vector2.ZERO, hit_radius * 0.85, Color(1.0, 1.0, 1.0, 0.45 * ft))


func _draw_jellyfish() -> void:
	var pulse: float = sin(_anim_phase * 0.9)
	var dome_w: float = 17.0 + pulse * 2.2
	var dome_h: float = 14.0 - pulse * 1.5
	var glow := _flash_col(Color(1.0, 0.16, 0.56, 0.22))
	var fill := _flash_col(Color(1.0, 0.22, 0.58, 0.72))
	var rim := _flash_col(Color("#ff85c0"))

	# Outer neon aura
	draw_circle(Vector2(0, -3), dome_w + 5.0, glow)

	# Waving glowing tentacles
	for t_idx in range(-2, 3):
		var start_x: float = float(t_idx) * 5.2
		var pts := PackedVector2Array()
		for seg in range(5):
			var frac: float = float(seg) / 4.0
			var wave: float = sin(_anim_phase * 1.3 + float(t_idx) * 1.1 - frac * 2.8) * (4.5 * frac)
			pts.append(Vector2(start_x + wave, 2.0 + frac * 20.0))
		draw_polyline(pts, _flash_col(Color(1.0, 0.45, 0.78, 0.88)), 2.2)

	# Translucent hot-pink bell dome
	var dome_pts := PackedVector2Array()
	for i in range(13):
		var a: float = PI + (float(i) / 12.0) * PI
		dome_pts.append(Vector2(cos(a) * dome_w, sin(a) * dome_h + 2.0))
	dome_pts.append(Vector2(dome_w * 0.7, 4.0))
	dome_pts.append(Vector2(0.0, 1.0))
	dome_pts.append(Vector2(-dome_w * 0.7, 4.0))
	draw_polygon(dome_pts, PackedColorArray([fill]))

	var outline := PackedVector2Array(dome_pts)
	outline.append(dome_pts[0])
	draw_polyline(outline, rim, 2.2)
	draw_circle(Vector2(-5.0, -5.0), 3.0, _flash_col(Color(1.0, 0.85, 0.95, 0.8)))
	draw_circle(Vector2(4.0, -7.0), 2.2, _flash_col(Color(1.0, 0.85, 0.95, 0.7)))


func _draw_crab() -> void:
	var shell_col := _flash_col(Color("#ff6b35"))
	var rim_col := _flash_col(Color("#ffb703"))
	var glow_col := _flash_col(Color(1.0, 0.42, 0.21, 0.20))
	draw_circle(Vector2.ZERO, 24.0, glow_col)

	# Skittering legs (3 per side)
	for side in [-1.0, 1.0]:
		for l in range(3):
			var phase: float = _anim_phase * 2.0 + float(l) * 1.4 + (0.0 if side < 0.0 else PI * 0.5)
			var y_off: float = -3.0 + float(l) * 5.5
			var knee := Vector2(side * (16.0 + sin(phase) * 3.0), y_off - 3.0)
			var foot := Vector2(side * (23.0 + cos(phase) * 3.5), y_off + 5.0)
			draw_line(Vector2(side * 10.0, y_off), knee, rim_col, 2.4)
			draw_line(knee, foot, shell_col, 2.2)

	# Snapping claws
	var snap: float = absf(sin(_anim_phase * 1.6)) * 0.45
	for side in [-1.0, 1.0]:
		var shoulder := Vector2(side * 11.0, -9.0)
		var wrist := Vector2(side * 18.0, -16.0)
		draw_line(shoulder, wrist, rim_col, 3.0)
		var base_ang: float = -PI * 0.5 + side * 0.3
		draw_arc(wrist, 6.5, base_ang - 0.8 - snap, base_ang + 0.8 + snap, 10, rim_col, 3.2)
		draw_circle(wrist, 3.6, shell_col)

	# Hexagonal coral-orange carapace
	var shell_pts := PackedVector2Array([
		Vector2(-15.0, -4.0),
		Vector2(-9.0, -12.0),
		Vector2(9.0, -12.0),
		Vector2(15.0, -4.0),
		Vector2(12.0, 9.0),
		Vector2(-12.0, 9.0),
	])
	draw_polygon(shell_pts, PackedColorArray([shell_col]))
	var outline := PackedVector2Array(shell_pts)
	outline.append(shell_pts[0])
	draw_polyline(outline, rim_col, 2.2)

	# Eyes
	draw_circle(Vector2(-5.5, -10.0), 3.0, Color.WHITE)
	draw_circle(Vector2(5.5, -10.0), 3.0, Color.WHITE)
	draw_circle(Vector2(-5.5, -10.0), 1.4, Color("#1a090d"))
	draw_circle(Vector2(5.5, -10.0), 1.4, Color("#1a090d"))


func _draw_pufferfish() -> void:
	var puff: float = 1.0 + 0.10 * sin(_anim_phase * 1.2)
	var r: float = 17.5 * puff
	var body_col := _flash_col(Color("#d9ff00"))
	var core_col := _flash_col(Color("#80ed1a"))
	var rim_col := _flash_col(Color("#f4ff78"))

	draw_circle(Vector2.ZERO, r + 6.0, _flash_col(Color(0.85, 1.0, 0.0, 0.18)))

	# Puffed spines around perimeter
	var spine_count: int = 12
	for i in range(spine_count):
		var a: float = float(i) * (TAU / float(spine_count)) + sin(_anim_phase * 0.6) * 0.08
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x)
		var base1 := dir * (r - 2.0) + perp * 3.0
		var base2 := dir * (r - 2.0) - perp * 3.0
		var tip := dir * (r + 8.5)
		draw_polygon(PackedVector2Array([base1, tip, base2]), PackedColorArray([rim_col]))

	# Round body
	draw_circle(Vector2.ZERO, r, body_col)
	draw_circle(Vector2(0.0, 2.0), r * 0.72, core_col)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, rim_col, 2.0)

	# Side fins fluttering
	var flap: float = sin(_anim_phase * 2.5) * 4.0
	draw_polygon(PackedVector2Array([Vector2(-r + 2, 0), Vector2(-r - 9, -5 + flap), Vector2(-r - 7, 5 + flap)]), PackedColorArray([rim_col]))
	draw_polygon(PackedVector2Array([Vector2(r - 2, 0), Vector2(r + 9, -5 - flap), Vector2(r + 7, 5 - flap)]), PackedColorArray([rim_col]))

	# Cute wide eyes + puffer mouth
	draw_circle(Vector2(-6.0, -4.0), 4.0, Color.WHITE)
	draw_circle(Vector2(6.0, -4.0), 4.0, Color.WHITE)
	draw_circle(Vector2(-5.5, -4.0), 1.8, Color("#0a1904"))
	draw_circle(Vector2(5.5, -4.0), 1.8, Color("#0a1904"))
	draw_arc(Vector2(0.0, 4.0), 3.2, 0.0, TAU, 12, Color("#243b06"), 1.8)


func _draw_shark() -> void:
	draw_set_transform(Vector2.ZERO, _facing_angle, Vector2.ONE)
	var thrash: float = sin(_anim_phase * 2.2) * 6.5
	var body_col := _flash_col(Color("#ff1e42"))
	var belly_col := _flash_col(Color("#ff758f"))
	var rim_col := _flash_col(Color("#ffb3c1"))

	draw_circle(Vector2.ZERO, 26.0, _flash_col(Color(1.0, 0.12, 0.26, 0.20)))

	# Thrashing crescent tail fin
	var tail_pts := PackedVector2Array([
		Vector2(-16.0, 0.0),
		Vector2(-31.0, -12.0 + thrash),
		Vector2(-24.0, thrash * 0.5),
		Vector2(-30.0, 11.0 + thrash),
	])
	draw_polygon(tail_pts, PackedColorArray([body_col]))
	draw_polyline(tail_pts, rim_col, 1.8)

	# Sleek predator body
	var body_pts := PackedVector2Array([
		Vector2(26.0, 0.0),
		Vector2(11.0, -10.0),
		Vector2(-8.0, -9.0),
		Vector2(-20.0, -3.0 + thrash * 0.25),
		Vector2(-20.0, 3.0 + thrash * 0.25),
		Vector2(-8.0, 9.0),
		Vector2(11.0, 10.0),
	])
	draw_polygon(body_pts, PackedColorArray([body_col]))

	# Pectoral side fins
	draw_polygon(PackedVector2Array([Vector2(4.0, -7.0), Vector2(-5.0, -19.0), Vector2(-6.0, -7.0)]), PackedColorArray([belly_col]))
	draw_polygon(PackedVector2Array([Vector2(4.0, 7.0), Vector2(-5.0, 19.0), Vector2(-6.0, 7.0)]), PackedColorArray([belly_col]))

	# Prominent central dorsal ridge fin
	draw_polygon(PackedVector2Array([Vector2(6.0, -2.0), Vector2(-4.0, -13.0), Vector2(-10.0, -1.0)]), PackedColorArray([rim_col]))

	var outline := PackedVector2Array(body_pts)
	outline.append(body_pts[0])
	draw_polyline(outline, rim_col, 2.0)

	# Fierce eye & gill slits
	draw_circle(Vector2(14.0, -4.0), 2.5, Color("#fff0f3"))
	draw_circle(Vector2(14.6, -4.0), 1.2, Color("#3a0010"))
	draw_line(Vector2(5.0, -5.0), Vector2(3.0, -2.0), rim_col, 1.5)
	draw_line(Vector2(2.0, -5.0), Vector2(0.0, -2.0), rim_col, 1.5)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_anglerfish() -> void:
	draw_set_transform(Vector2.ZERO, _facing_angle, Vector2.ONE)
	var bob: float = sin(_anim_phase * 1.4) * 3.0
	var body_col := _flash_col(Color("#0d6e7a"))
	var rim_col := _flash_col(Color("#8a2be2"))
	var lure_col := _flash_col(Color("#aaff00"))

	draw_circle(Vector2.ZERO, 26.0, _flash_col(Color(0.54, 0.17, 0.89, 0.22)))

	# Tail fin
	var tail_sway: float = sin(_anim_phase * 1.8) * 5.0
	draw_polygon(PackedVector2Array([
		Vector2(-15.0, 0.0),
		Vector2(-26.0, -10.0 + tail_sway),
		Vector2(-26.0, 10.0 + tail_sway),
	]), PackedColorArray([rim_col]))

	# Bulbous deep-sea body
	var body_pts := PackedVector2Array([
		Vector2(19.0, -4.0),
		Vector2(10.0, -16.0),
		Vector2(-8.0, -15.0),
		Vector2(-18.0, -5.0),
		Vector2(-18.0, 6.0),
		Vector2(-6.0, 15.0),
		Vector2(13.0, 13.0),
		Vector2(21.0, 5.0),
	])
	draw_polygon(body_pts, PackedColorArray([body_col]))
	var outline := PackedVector2Array(body_pts)
	outline.append(body_pts[0])
	draw_polyline(outline, rim_col, 2.4)

	# Fangs along fierce underbite jaw
	for f in range(4):
		var fx: float = 9.0 + float(f) * 3.2
		draw_line(Vector2(fx, 8.0), Vector2(fx + 1.0, 2.0), Color.WHITE, 1.8)

	# Glowing eye
	draw_circle(Vector2(8.0, -6.0), 3.4, Color("#e0fbfc"))
	draw_circle(Vector2(8.8, -6.0), 1.5, Color("#1a0b2e"))

	# Illicium stalk & glowing neon-lime lure hanging in front
	var lure_pos := Vector2(28.0, -11.0 + bob)
	var stalk := PackedVector2Array([
		Vector2(6.0, -13.0),
		Vector2(18.0, -21.0),
		lure_pos,
	])
	draw_polyline(stalk, rim_col, 2.2)
	draw_circle(lure_pos, 11.0, _flash_col(Color(0.66, 1.0, 0.0, 0.26)))
	draw_circle(lure_pos, 5.0, lure_col)
	draw_circle(lure_pos, 2.2, Color.WHITE)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_abyss_jelly() -> void:
	var pulse: float = sin(_anim_phase * 0.85)
	var bell_w: float = 24.0 + pulse * 2.8
	var bell_h: float = 19.0 - pulse * 2.0
	var purple := _flash_col(Color("#b5179e"))
	var cyan := _flash_col(Color("#00f5d4"))

	draw_circle(Vector2(0, -4), bell_w + 9.0, _flash_col(Color(0.71, 0.09, 0.62, 0.22)))

	# Long trailing bioluminescent ribbons
	for r_idx in range(-3, 4):
		var start_x: float = float(r_idx) * 5.5
		var col: Color = cyan if (r_idx % 2 == 0) else purple
		var pts := PackedVector2Array()
		for seg in range(6):
			var frac: float = float(seg) / 5.0
			var wave: float = sin(_anim_phase * 1.15 + float(r_idx) * 0.9 - frac * 3.1) * (7.0 * frac)
			pts.append(Vector2(start_x + wave, 3.0 + frac * 30.0))
		draw_polyline(pts, Color(col.r, col.g, col.b, 0.85), 2.4)

	# Translucent violet bell with electric cyan rim & veins
	var dome_pts := PackedVector2Array()
	for i in range(15):
		var a: float = PI + (float(i) / 14.0) * PI
		dome_pts.append(Vector2(cos(a) * bell_w, sin(a) * bell_h + 2.0))
	dome_pts.append(Vector2(bell_w * 0.78, 6.0))
	dome_pts.append(Vector2(0.0, 1.0))
	dome_pts.append(Vector2(-bell_w * 0.78, 6.0))
	draw_polygon(dome_pts, PackedColorArray([Color(purple.r, purple.g, purple.b, 0.68)]))

	var outline := PackedVector2Array(dome_pts)
	outline.append(dome_pts[0])
	draw_polyline(outline, cyan, 2.5)
	draw_circle(Vector2(-6.0, -7.0), 3.8, cyan)
	draw_circle(Vector2(6.0, -7.0), 3.8, cyan)


func _draw_kraken() -> void:
	var pulse: float = sin(_anim_phase * 0.8)
	var magenta := _flash_col(Color("#ff0099"))
	var deep_purple := _flash_col(Color("#6a004f"))
	var gold := _flash_col(Color("#ffd166"))

	# Pulsing boss aura ring
	var aura_r: float = 46.0 + pulse * 5.0
	draw_circle(Vector2.ZERO, aura_r, _flash_col(Color(1.0, 0.0, 0.6, 0.16)))
	draw_arc(Vector2.ZERO, aura_r, 0.0, TAU, 36, Color(gold.r, gold.g, gold.b, 0.55), 2.2)

	# 8 thick writhing tentacles
	for t_idx in range(8):
		var base_ang: float = PI * 0.15 + (float(t_idx) / 7.0) * (PI * 0.70)
		var dir := Vector2(cos(base_ang), sin(base_ang))
		var perp := Vector2(-dir.y, dir.x)
		var pts := PackedVector2Array()
		for seg in range(6):
			var frac: float = float(seg) / 5.0
			var sway: float = sin(_anim_phase * 1.25 + float(t_idx) * 0.85 - frac * 2.6) * (9.0 * frac)
			pts.append(dir * (14.0 + frac * 34.0) + perp * sway)
		draw_polyline(pts, magenta, 5.0 - float(t_idx % 2))
		draw_circle(pts[pts.size() - 1], 2.8, gold)

	# Armored squid mantle/head
	var head_pts := PackedVector2Array([
		Vector2(0.0, -38.0),
		Vector2(20.0, -24.0),
		Vector2(26.0, -2.0),
		Vector2(18.0, 14.0),
		Vector2(-18.0, 14.0),
		Vector2(-26.0, -2.0),
		Vector2(-20.0, -24.0),
	])
	draw_polygon(head_pts, PackedColorArray([deep_purple]))
	var outline := PackedVector2Array(head_pts)
	outline.append(head_pts[0])
	draw_polyline(outline, magenta, 3.0)

	# Golden crown crest & glowing boss eyes
	draw_polyline(PackedVector2Array([Vector2(-11, -18), Vector2(0, -29), Vector2(11, -18)]), gold, 2.5)
	draw_circle(Vector2(-9.0, -3.0), 4.5, gold)
	draw_circle(Vector2(9.0, -3.0), 4.5, gold)
	draw_circle(Vector2(-9.0, -3.0), 2.0, Color("#240018"))
	draw_circle(Vector2(9.0, -3.0), 2.0, Color("#240018"))

	# Mini HP bar above Kraken
	var bar_w: float = 64.0
	var bar_h: float = 7.0
	var bar_pos := Vector2(-bar_w * 0.5, -52.0)
	var ratio: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.05, 0.02, 0.10, 0.85), true)
	draw_rect(Rect2(bar_pos + Vector2(1.0, 1.0), Vector2((bar_w - 2.0) * ratio, bar_h - 2.0)), Color("#ff0099"), true)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color("#ffd166"), false, 1.4)
