extends Area2D

## Glowing neon XP pearl dropped by defeated sea creatures.
## Accelerates smoothly toward the player once within pickup_radius.

var xp_value: int = 3
var gem_color: Color = Color("#38bdf8")
var player_ref: Node2D = null

var _magnetized: bool = false
var _speed: float = 0.0
var _bob_phase: float = 0.0
var _collected: bool = false


func _ready() -> void:
	add_to_group("xp_gems")
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	z_index = 4

	_bob_phase = randf() * TAU

	var col_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	col_shape.shape = circle
	add_child(col_shape)


func _physics_process(delta: float) -> void:
	if _collected:
		return

	_bob_phase += delta * 5.2
	queue_redraw()

	if not is_instance_valid(player_ref) and is_inside_tree():
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player_ref):
		return

	var to_player: Vector2 = player_ref.global_position - global_position
	var dist: float = to_player.length()

	var radius: float = 135.0
	var p_radius: Variant = player_ref.get("pickup_radius")
	if p_radius != null:
		radius = float(p_radius)

	if dist <= radius:
		_magnetized = true

	if _magnetized:
		_speed = clampf(_speed + 1250.0 * delta, 200.0, 720.0)
		var step: float = _speed * delta
		if dist <= step or dist < 24.0:
			global_position = player_ref.global_position
			_collect()
			return
		global_position += (to_player / dist) * step
		dist = global_position.distance_to(player_ref.global_position)

	if dist < 24.0:
		_collect()


func _collect() -> void:
	if _collected:
		return
	_collected = true
	if is_inside_tree():
		var game_data: Node = get_node_or_null("/root/GameData")
		if game_data != null and game_data.has_method("add_xp"):
			game_data.add_xp(xp_value)
		var sound_mgr: Node = get_node_or_null("/root/SoundManager")
		if sound_mgr != null and sound_mgr.has_method("play_xp"):
			sound_mgr.play_xp()
	queue_free()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_bob_phase * 1.4)
	var bob_offset := Vector2(0.0, sin(_bob_phase) * 2.5)
	var scale_factor: float = 1.05 if xp_value < 8 else 1.32
	var base_r: float = (7.5 + pulse * 1.3) * scale_factor

	# Outer electric blue aura + crisp white ring so XP pearls stand out from ocean & enemies
	draw_circle(bob_offset, base_r * 2.0, Color(0.22, 0.74, 1.0, 0.18 + 0.10 * pulse))
	draw_circle(bob_offset, base_r * 1.35, Color(0.0, 0.85, 1.0, 0.34 + 0.12 * pulse))
	draw_arc(bob_offset, base_r * 1.48, 0.0, TAU, 20, Color(0.88, 0.97, 1.0, 0.55 + 0.25 * pulse), 1.4)

	# Diamond pearl shape in vivid sky-blue
	var diamond := PackedVector2Array([
		bob_offset + Vector2(0.0, -base_r * 1.18),
		bob_offset + Vector2(base_r * 0.90, 0.0),
		bob_offset + Vector2(0.0, base_r * 1.18),
		bob_offset + Vector2(-base_r * 0.90, 0.0),
		bob_offset + Vector2(0.0, -base_r * 1.18)
	])
	draw_colored_polygon(diamond.slice(0, 4), gem_color)
	draw_polyline(diamond, Color(0.92, 0.98, 1.0, 0.95), 1.8, true)

	# Bright inner core & specular pearl gleam
	var inner := PackedVector2Array([
		bob_offset + Vector2(0.0, -base_r * 0.62),
		bob_offset + Vector2(base_r * 0.45, 0.0),
		bob_offset + Vector2(0.0, base_r * 0.62),
		bob_offset + Vector2(-base_r * 0.45, 0.0)
	])
	draw_colored_polygon(inner, Color("#bae6fd"))
	draw_circle(bob_offset + Vector2(-base_r * 0.18, -base_r * 0.22), base_r * 0.24, Color(1.0, 1.0, 1.0, 0.95))
