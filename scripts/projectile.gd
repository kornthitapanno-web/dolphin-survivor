extends Area2D

## Procedural neon projectile supporting "sonic", "bubble", and "shockwave" types.
## Hits enemies via both Area2D body_entered and distance checks against group "enemies".

var proj_type: String = "sonic" # "sonic", "bubble", "shockwave"
var velocity: Vector2 = Vector2.ZERO
var damage: float = 18.0
var pierce: int = 1
var lifetime: float = 2.0
var radius: float = 14.0
var color: Color = Color("#00f5d4")
var fx_manager: Node2D = null

var _age: float = 0.0
var _max_lifetime: float = 2.0
var _initial_radius: float = 14.0
var _hit_ids: Dictionary = {}
var _dead: bool = false
var _col_shape: CollisionShape2D = null


func _ready() -> void:
	z_index = 12
	_max_lifetime = maxf(lifetime, 0.05)
	_initial_radius = maxf(radius, 4.0)

	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0

	if proj_type == "sonic" and velocity.length_squared() > 0.001:
		rotation = velocity.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _dead:
		return

	_age += delta
	lifetime -= delta
	if lifetime <= 0.0:
		_dead = true
		queue_free()
		return

	if proj_type == "shockwave":
		var t: float = clampf(_age / _max_lifetime, 0.0, 1.0)
		var target_max: float = maxf(_initial_radius, 90.0)
		radius = lerpf(16.0, target_max, 1.0 - pow(1.0 - t, 2.2))
		if _col_shape != null and _col_shape.shape is CircleShape2D:
			(_col_shape.shape as CircleShape2D).radius = radius
	else:
		global_position += velocity * delta
		if proj_type == "sonic" and velocity.length_squared() > 0.001:
			rotation = velocity.angle()

	_check_enemy_distances()
	if proj_type == "shockwave":
		queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	_try_hit_enemy(body)


func _check_enemy_distances() -> void:
	if _dead or not is_inside_tree():
		return
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for node in enemies:
		if _dead:
			return
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var enemy_node := node as Node2D
		var eid: int = enemy_node.get_instance_id()
		if _hit_ids.has(eid):
			continue
		var e_radius: float = 18.0
		var hr: Variant = enemy_node.get("hit_radius")
		if hr != null:
			e_radius = float(hr)
		var check_r: float = radius + e_radius
		if global_position.distance_squared_to(enemy_node.global_position) <= check_r * check_r:
			_try_hit_enemy(enemy_node)


func _try_hit_enemy(enemy: Node) -> void:
	if _dead or not is_instance_valid(enemy):
		return
	if not enemy.is_in_group("enemies"):
		return
	if not enemy.has_method("take_damage"):
		return
	var eid: int = enemy.get_instance_id()
	if _hit_ids.has(eid):
		return
	_hit_ids[eid] = true

	var kb_dir: Vector2 = velocity.normalized()
	if kb_dir.length_squared() < 0.001 and enemy is Node2D:
		kb_dir = ((enemy as Node2D).global_position - global_position).normalized()

	enemy.take_damage(damage, kb_dir * 140.0)

	var hit_pos: Vector2 = (enemy as Node2D).global_position if enemy is Node2D else global_position
	if is_instance_valid(fx_manager) and fx_manager.has_method("spawn_hit_burst"):
		fx_manager.spawn_hit_burst(hit_pos, color, 8)

	if is_inside_tree():
		var sound_mgr: Node = get_node_or_null("/root/SoundManager")
		if sound_mgr != null and sound_mgr.has_method("play_hit"):
			sound_mgr.play_hit()

	if proj_type != "shockwave":
		pierce -= 1
		if pierce <= 0:
			_dead = true
			queue_free()


func _draw() -> void:
	match proj_type:
		"bubble":
			_draw_bubble()
		"shockwave":
			_draw_shockwave()
		_:
			_draw_sonic()


func _draw_sonic() -> void:
	var r: float = radius
	var center := Vector2(-r * 0.38, 0.0)
	var arc_r: float = r * 1.15
	# Soft outer neon glow
	draw_arc(center, arc_r, -1.08, 1.08, 16, Color(color, 0.28), 10.0, true)
	# Core neon crescent
	draw_arc(center, arc_r * 0.96, -0.96, 0.96, 16, color, 4.6, true)
	# Inner bright energy edge
	draw_arc(center + Vector2(2.0, 0.0), arc_r * 0.88, -0.78, 0.78, 14, Color(1.0, 1.0, 1.0, 0.92), 2.0, true)
	# Trailing sonic fins
	draw_line(Vector2(-r * 0.9, -r * 0.45), Vector2(-r * 0.15, -r * 0.75), Color(color, 0.55), 2.0, true)
	draw_line(Vector2(-r * 0.9, r * 0.45), Vector2(-r * 0.15, r * 0.75), Color(color, 0.55), 2.0, true)


func _draw_bubble() -> void:
	var pulse: float = 1.0 + 0.08 * sin(_age * 16.0)
	var r: float = radius * pulse
	# Outer glow
	draw_circle(Vector2.ZERO, r * 1.38, Color(color, 0.18))
	# Translucent iridescent fill
	draw_circle(Vector2.ZERO, r, Color(color, 0.30))
	# Rim and iridescence shift
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, color.lightened(0.25), 2.5, true)
	draw_arc(Vector2.ZERO, r * 0.82, 0.4, 2.2, 12, Color("#00f5d4", 0.65), 1.8, true)
	# Specular bubble gleam
	draw_circle(Vector2(-r * 0.34, -r * 0.34), maxf(2.0, r * 0.24), Color(1.0, 1.0, 1.0, 0.88))


func _draw_shockwave() -> void:
	var t: float = clampf(_age / _max_lifetime, 0.0, 1.0)
	var alpha: float = 1.0 - t
	var r: float = maxf(radius, 8.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(color, alpha * 0.30), 10.0 * alpha + 1.5, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(color, alpha * 0.95), 3.6 * alpha + 1.0, true)
	draw_arc(Vector2.ZERO, r * 0.96, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, alpha * 0.75), 1.5, true)
