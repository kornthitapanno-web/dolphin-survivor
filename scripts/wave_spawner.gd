extends Node2D

var stage_id: int = 1
var player: Node2D = null
var enemy_container: Node2D = null
var gem_container: Node2D = null
var fx_manager: Node2D = null
var active: bool = false

var _spawn_timer: float = 0.0
var _burst_timer: float = 20.0
var _shark_wave_timer: float = 12.0
var _kraken_timer: float = 18.0
var _enemy_script: Script = null

const MAX_CONTINUOUS_ENEMIES: int = 85
const MAX_TOTAL_ENEMIES: int = 110


func _ready() -> void:
	_load_enemy_script()


func _load_enemy_script() -> void:
	if _enemy_script == null and ResourceLoader.exists("res://scripts/enemy.gd"):
		_enemy_script = load("res://scripts/enemy.gd") as Script


func start_stage(id: int) -> void:
	stage_id = 2 if id == 2 else 1
	active = true
	_spawn_timer = 0.25
	_burst_timer = 20.0
	_shark_wave_timer = 11.0
	_kraken_timer = 16.0
	_load_enemy_script()


func stop() -> void:
	active = false


func _process(delta: float) -> void:
	if not active:
		return

	var t: float = _get_time_survived()
	var current_count: int = _get_enemy_count()

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		var interval: float = maxf(0.32, 1.05 - t * 0.0065)
		_spawn_timer = interval
		if current_count < MAX_CONTINUOUS_ENEMIES:
			var batch: int = mini(3, 1 + int(t / 35.0))
			for _i in range(batch):
				if _get_enemy_count() >= MAX_CONTINUOUS_ENEMIES:
					break
				_spawn_single(_pick_enemy_type(t), 430.0, 620.0, t)

	if stage_id == 1:
		_shark_wave_timer -= delta
		if _shark_wave_timer <= 0.0:
			_shark_wave_timer = maxf(9.0, 15.0 - t * 0.04)
			if _get_enemy_count() < MAX_TOTAL_ENEMIES:
				var shark_pack: int = 2 + mini(3, int(t / 30.0))
				for i in range(shark_pack):
					var ang: float = randf() * TAU + float(i) * 0.28
					_spawn_single_at_angle("shark", ang, 460.0, 590.0, t)
	else:
		_kraken_timer -= delta
		if _kraken_timer <= 0.0:
			_kraken_timer = maxf(18.0, 28.0 - t * 0.06)
			if _count_enemies_of_type("kraken") < 2 and _get_enemy_count() < MAX_TOTAL_ENEMIES:
				_spawn_single("kraken", 450.0, 580.0, t)

	_burst_timer -= delta
	if _burst_timer <= 0.0:
		_burst_timer = 20.0
		var burst_count: int = mini(22, 8 + int(t / 20.0) * 3)
		spawn_wave_burst(burst_count, 400.0, 580.0)


func spawn_wave_burst(count: int, radius_min: float = 380.0, radius_max: float = 560.0) -> void:
	_load_enemy_script()
	if _enemy_script == null or count <= 0:
		return

	var t: float = _get_time_survived()
	var base_angle: float = randf() * TAU
	var krakens_alive: int = _count_enemies_of_type("kraken")

	for i in range(count):
		if _get_enemy_count() >= MAX_TOTAL_ENEMIES:
			break
		var angle: float = base_angle + (float(i) / float(count)) * TAU + randf_range(-0.18, 0.18)
		var etype: String = _pick_burst_enemy_type(i, count, t, krakens_alive)
		if etype == "kraken":
			krakens_alive += 1
		_spawn_single_at_angle(etype, angle, radius_min, radius_max, t)


func _pick_burst_enemy_type(index: int, total: int, t: float, krakens_alive: int) -> String:
	if stage_id == 1:
		if total >= 8:
			if index == 0:
				return "shark"
			if index == 1:
				return "pufferfish"
			if index == 2:
				return "crab"
		return _pick_enemy_type(t)
	else:
		if total >= 10 and index == 0 and krakens_alive < 1:
			return "kraken"
		if total >= 6:
			match index % 4:
				0:
					return "anglerfish"
				1:
					return "abyss_jelly"
				2:
					return "shark"
				_:
					return _pick_enemy_type(t)
		return _pick_enemy_type(t)


func _pick_enemy_type(t: float) -> String:
	var roll: float = randf()
	if stage_id == 1:
		var shark_chance: float = clampf(0.08 + t * 0.0012, 0.08, 0.22)
		var puffer_chance: float = clampf(0.16 + t * 0.0010, 0.16, 0.26)
		var crab_chance: float = 0.28
		if roll < shark_chance:
			return "shark"
		elif roll < shark_chance + puffer_chance:
			return "pufferfish"
		elif roll < shark_chance + puffer_chance + crab_chance:
			return "crab"
		return "jellyfish"
	else:
		var kraken_chance: float = 0.04 if (t > 20.0 and _count_enemies_of_type("kraken") < 2) else 0.0
		var shark_chance: float = 0.22
		var abyss_chance: float = 0.36
		if roll < kraken_chance:
			return "kraken"
		elif roll < kraken_chance + shark_chance:
			return "shark"
		elif roll < kraken_chance + shark_chance + abyss_chance:
			return "abyss_jelly"
		return "anglerfish"


func _spawn_single(etype: String, radius_min: float, radius_max: float, t: float) -> void:
	_spawn_single_at_angle(etype, randf() * TAU, radius_min, radius_max, t)


func _spawn_single_at_angle(etype: String, angle: float, radius_min: float, radius_max: float, t: float) -> void:
	_load_enemy_script()
	if _enemy_script == null:
		return

	var target_player: Node2D = _resolve_player()
	var center: Vector2 = target_player.global_position if is_instance_valid(target_player) else Vector2.ZERO
	var dist: float = randf_range(radius_min, radius_max)
	var spawn_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist

	var target_container: Node = enemy_container if is_instance_valid(enemy_container) else get_parent()
	if not is_instance_valid(target_container):
		target_container = self

	var enemy: CharacterBody2D = _enemy_script.new() as CharacterBody2D
	if enemy == null:
		return

	var hp_mult: float = 1.0 + t * 0.015
	var spd_mult: float = 1.0 + minf(t * 0.004, 0.45)
	if target_container is Node2D:
		enemy.position = (target_container as Node2D).to_local(spawn_pos)
	else:
		enemy.position = spawn_pos

	if enemy.has_method("setup"):
		enemy.setup(etype, target_player, gem_container, fx_manager, hp_mult, spd_mult)

	target_container.add_child(enemy)


func _resolve_player() -> Node2D:
	if is_instance_valid(player):
		return player
	var tree: SceneTree = get_tree()
	if tree != null:
		player = tree.get_first_node_in_group("player") as Node2D
	return player


func _get_time_survived() -> float:
	var gd: Node = get_node_or_null("/root/GameData")
	if gd != null and "time_survived" in gd:
		return float(gd.get("time_survived"))
	return 0.0


func _get_enemy_count() -> int:
	var tree: SceneTree = get_tree()
	if tree == null:
		return 0
	return tree.get_nodes_in_group("enemies").size()


func _count_enemies_of_type(etype: String) -> int:
	var tree: SceneTree = get_tree()
	if tree == null:
		return 0
	var n: int = 0
	for node in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(node) and "enemy_type" in node and String(node.get("enemy_type")) == etype:
			n += 1
	return n
