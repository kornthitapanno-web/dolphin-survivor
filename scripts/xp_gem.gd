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
var _sprite: Sprite2D = null

static var _gem_texture: ImageTexture = null


func _ready() -> void:
	add_to_group("xp_gems")
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	z_index = 4

	_bob_phase = randf() * TAU

	_ensure_gem_texture()
	_sprite = Sprite2D.new()
	_sprite.texture = _gem_texture
	_sprite.modulate = gem_color.lightened(0.25)
	add_child(_sprite)


static func _ensure_gem_texture() -> void:
	if _gem_texture != null:
		return
	var sz: int = 44
	var half: float = float(sz) * 0.5
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	for y in sz:
		for x in sz:
			var dx: float = (float(x) + 0.5 - half)
			var dy: float = (float(y) + 0.5 - half)
			var dist: float = sqrt(dx * dx + dy * dy)

			# Soft outer electric-blue aura + crisp ring
			var col := Color(0.0, 0.0, 0.0, 0.0)
			if dist < 19.0:
				var aura_a: float = clampf(1.0 - dist / 19.0, 0.0, 1.0)
				col = Color(0.22, 0.78, 1.0, aura_a * aura_a * 0.34)
			if absf(dist - 12.8) < 1.2:
				var ring_a: float = 1.0 - absf(dist - 12.8) / 1.2
				col = col.blend(Color(0.88, 0.97, 1.0, ring_a * 0.65))

			# Diamond pearl core (|dx|/0.85 + |dy|/1.15 <= 9.2)
			var manhattan: float = absf(dx) / 0.85 + absf(dy) / 1.15
			if manhattan <= 9.6:
				if manhattan >= 7.7:
					col = col.blend(Color(0.95, 0.99, 1.0, 0.96))
				elif manhattan >= 4.8:
					col = col.blend(Color(0.35, 0.82, 1.0, 0.98))
				else:
					col = col.blend(Color(0.78, 0.94, 1.0, 1.0))

			# Specular gleam top-left
			var gx: float = dx + 1.8
			var gy: float = dy + 2.2
			if gx * gx + gy * gy <= 4.0:
				col = col.blend(Color(1.0, 1.0, 1.0, 0.95))

			if col.a > 0.005:
				img.set_pixel(x, y, col)

	_gem_texture = ImageTexture.create_from_image(img)


func _physics_process(delta: float) -> void:
	if _collected:
		return

	_bob_phase += delta * 5.2
	if _sprite != null:
		_sprite.position.y = sin(_bob_phase) * 2.5
		var base_s: float = 1.05 if xp_value < 8 else 1.32
		var pulse_s: float = base_s * (0.94 + 0.09 * sin(_bob_phase * 1.4))
		_sprite.scale = Vector2(pulse_s, pulse_s)

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
