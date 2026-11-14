extends Node2D

## Main controller for Neon Dolphin Survivor.
## Instantiates world, player, FX, wave spawner, neon UI (4 mutually exclusive states),
## and handles the --autotest smoke test and screenshot capture.

const OCEAN_BG_SCRIPT: GDScript = preload("res://scripts/ocean_background.gd")
const PLAYER_SCRIPT: GDScript = preload("res://scripts/player.gd")
const FX_MANAGER_SCRIPT: GDScript = preload("res://scripts/fx_manager.gd")
const WAVE_SPAWNER_SCRIPT: GDScript = preload("res://scripts/wave_spawner.gd")
const XP_GEM_SCRIPT: GDScript = preload("res://scripts/xp_gem.gd")

enum GameState {
	TITLE,
	PLAYING,
	LEVEL_UP,
	PAUSE,
	GAME_OVER
}


class TitlePreviewLayer extends Node2D:
	var _t: float = 0.0
	var _creatures: Array[Dictionary] = []

	func _ready() -> void:
		z_index = 2
		_creatures = [
			{"kind": "jelly", "pos": Vector2(-430.0, -180.0), "vel": Vector2(28.0, 6.0), "col": Color("#ff4fd8"), "scale": 1.05, "phase": 0.2},
			{"kind": "jelly", "pos": Vector2(390.0, -140.0), "vel": Vector2(-24.0, 8.0), "col": Color("#00f5d4"), "scale": 0.92, "phase": 1.7},
			{"kind": "jelly", "pos": Vector2(-340.0, 210.0), "vel": Vector2(22.0, -5.0), "col": Color("#bf5af2"), "scale": 1.15, "phase": 3.1},
			{"kind": "fish", "pos": Vector2(460.0, 170.0), "vel": Vector2(-58.0, -4.0), "col": Color("#38bdf8"), "scale": 1.0, "phase": 0.8},
			{"kind": "fish", "pos": Vector2(-490.0, 40.0), "vel": Vector2(64.0, 5.0), "col": Color("#a8ff3e"), "scale": 0.9, "phase": 2.3},
			{"kind": "puffer", "pos": Vector2(320.0, 235.0), "vel": Vector2(-32.0, -6.0), "col": Color("#fee440"), "scale": 0.95, "phase": 4.0},
			{"kind": "crab", "pos": Vector2(-210.0, 275.0), "vel": Vector2(36.0, 0.0), "col": Color("#ff7b29"), "scale": 0.95, "phase": 1.1},
			{"kind": "fish", "pos": Vector2(180.0, -245.0), "vel": Vector2(-52.0, 4.0), "col": Color("#00f5d4"), "scale": 0.85, "phase": 5.0},
		]

	func _process(delta: float) -> void:
		if not visible:
			return
		_t += delta
		for c in _creatures:
			var p: Vector2 = c["pos"]
			var v: Vector2 = c["vel"]
			p += v * delta
			p.y += sin(_t * 1.8 + float(c["phase"])) * 12.0 * delta
			if p.x > 680.0:
				p.x = -680.0
			elif p.x < -680.0:
				p.x = 680.0
			if p.y > 380.0:
				p.y = -380.0
			elif p.y < -380.0:
				p.y = 380.0
			c["pos"] = p
		queue_redraw()

	func _draw() -> void:
		for c in _creatures:
			var kind: String = str(c["kind"])
			var pos: Vector2 = c["pos"]
			var vel: Vector2 = c["vel"]
			var col: Color = c["col"]
			var sc: float = float(c["scale"])
			var ph: float = float(c["phase"]) + _t * 3.8
			if kind == "jelly":
				var pulse: float = 1.0 + 0.12 * sin(ph)
				var r: float = 18.0 * sc * pulse
				draw_circle(pos, r * 1.5, Color(col, 0.14))
				var dome := PackedVector2Array()
				for i in range(9):
					var ang: float = PI + (float(i) / 8.0) * PI
					dome.append(pos + Vector2(cos(ang) * r, sin(ang) * r * 0.85))
				draw_colored_polygon(dome, Color(col, 0.48))
				draw_polyline(dome, col.lightened(0.35), 2.0, true)
				for t_i in range(-2, 3):
					var base_x: float = pos.x + float(t_i) * 5.0 * sc
					var pts := PackedVector2Array()
					pts.append(Vector2(base_x, pos.y))
					for seg in range(1, 5):
						var sway: float = sin(ph + float(seg) * 0.9 + float(t_i)) * 4.5
						pts.append(Vector2(base_x + sway, pos.y + float(seg) * 6.5 * sc))
					draw_polyline(pts, Color(col, 0.7), 1.8, true)
			elif kind == "puffer":
				var r: float = 16.0 * sc * (1.0 + 0.08 * sin(ph))
				draw_circle(pos, r * 1.45, Color(col, 0.14))
				for sp in range(10):
					var a: float = float(sp) * TAU / 10.0 + _t * 0.5
					draw_line(pos + Vector2.from_angle(a) * (r * 0.85), pos + Vector2.from_angle(a) * (r * 1.32), col, 2.0)
				draw_circle(pos, r, Color(col, 0.65))
				draw_arc(pos, r, 0.0, TAU, 24, col.lightened(0.4), 2.0)
				draw_circle(pos + Vector2(-4.0 * sc, -3.0 * sc), 2.5, Color.WHITE)
			elif kind == "crab":
				var r: float = 15.0 * sc
				draw_circle(pos, r * 1.45, Color(col, 0.13))
				for side in [-1.0, 1.0]:
					for leg in range(3):
						var lx: float = pos.x + side * (10.0 + float(leg) * 4.0) * sc
						var ly: float = pos.y + (float(leg) - 1.0) * 4.0 * sc
						var kick: float = sin(ph * 1.5 + float(leg)) * 3.0
						draw_line(Vector2(pos.x + side * 6.0, ly), Vector2(lx + side * 6.0, ly + kick + 5.0), col, 2.0)
				draw_circle(pos, r * 0.85, Color(col, 0.72))
				draw_arc(pos, r * 0.85, 0.0, TAU, 20, col.lightened(0.35), 2.0)
			else:
				var dir_x: float = 1.0 if vel.x >= 0.0 else -1.0
				var wag: float = sin(ph * 1.6) * 5.0
				var body := PackedVector2Array([
					pos + Vector2(18.0 * dir_x * sc, 0.0),
					pos + Vector2(3.0 * dir_x * sc, -9.0 * sc),
					pos + Vector2(-12.0 * dir_x * sc, -3.0 * sc),
					pos + Vector2(-12.0 * dir_x * sc, 3.0 * sc),
					pos + Vector2(3.0 * dir_x * sc, 9.0 * sc),
				])
				var tail := PackedVector2Array([
					pos + Vector2(-11.0 * dir_x * sc, 0.0),
					pos + Vector2(-21.0 * dir_x * sc, -8.0 * sc + wag),
					pos + Vector2(-21.0 * dir_x * sc, 8.0 * sc + wag),
				])
				draw_colored_polygon(tail, Color(col, 0.65))
				draw_colored_polygon(body, Color(col, 0.78))
				draw_polyline(body, col.lightened(0.4), 1.8, true)
				draw_circle(pos + Vector2(9.0 * dir_x * sc, -2.5 * sc), 2.2, Color.WHITE)


class TouchJoystick extends Control:
	var direction: Vector2 = Vector2.ZERO
	var _touch_index: int = -1
	var _base_pos: Vector2 = Vector2(125.0, 585.0)
	var _knob_pos: Vector2 = Vector2(125.0, 585.0)
	var _max_radius: float = 54.0
	var _active: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func reset_stick() -> void:
		_touch_index = -1
		_active = false
		direction = Vector2.ZERO
		var vp_h: float = get_viewport_rect().size.y
		_base_pos = Vector2(125.0, maxf(200.0, vp_h - 135.0))
		_knob_pos = _base_pos
		queue_redraw()

	func _input(event: InputEvent) -> void:
		if not visible:
			return
		var vp_size: Vector2 = get_viewport_rect().size
		if event is InputEventScreenTouch:
			var ev := event as InputEventScreenTouch
			if ev.pressed and _touch_index == -1 and ev.position.x <= vp_size.x * 0.55 and ev.position.y > 70.0:
				_touch_index = ev.index
				_active = true
				_base_pos = ev.position
				_knob_pos = ev.position
				direction = Vector2.ZERO
				queue_redraw()
			elif not ev.pressed and ev.index == _touch_index:
				reset_stick()
		elif event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if drag.index == _touch_index and _active:
				var delta_v: Vector2 = drag.position - _base_pos
				var dist: float = delta_v.length()
				if dist > _max_radius:
					delta_v = (delta_v / dist) * _max_radius
				_knob_pos = _base_pos + delta_v
				direction = delta_v / _max_radius if dist > 6.0 else Vector2.ZERO
				queue_redraw()

	func _draw() -> void:
		var vp_h: float = get_viewport_rect().size.y
		var center: Vector2 = _base_pos if _active else Vector2(125.0, maxf(200.0, vp_h - 135.0))
		var knob: Vector2 = _knob_pos if _active else center
		var alpha: float = 0.58 if _active else 0.20
		draw_circle(center, _max_radius, Color(0.02, 0.14, 0.26, alpha * 0.55))
		draw_arc(center, _max_radius, 0.0, TAU, 32, Color(0.22, 0.74, 0.97, alpha), 2.2)
		draw_circle(knob, 22.0, Color(0.0, 0.96, 0.83, alpha + 0.18))
		draw_arc(knob, 22.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, alpha + 0.25), 1.8)


var ocean_background: Node2D = null
var gem_container: Node2D = null
var projectile_container: Node2D = null
var enemy_container: Node2D = null
var player: CharacterBody2D = null
var camera: Camera2D = null
var fx_manager: Node2D = null
var wave_spawner: Node2D = null
var title_preview_layer: TitlePreviewLayer = null

var ui_layer: CanvasLayer = null
var ui_root: Control = null
var title_panel: Control = null
var hud_root: Control = null
var levelup_panel: Control = null
var pause_panel: Control = null
var gameover_panel: Control = null

var start_stage1_btn: Button = null
var start_stage2_btn: Button = null
var title_ach_label: Label = null
var xp_bar: ProgressBar = null
var xp_label: Label = null
var level_label: Label = null
var hp_bar: ProgressBar = null
var hp_label: Label = null
var stage_name_label: Label = null
var weapons_label: Label = null
var timer_label: Label = null
var kills_label: Label = null
var score_label: Label = null
var hud_ach_label: Label = null
var pause_hud_btn: Button = null
var virtual_joystick: TouchJoystick = null

var resume_btn: Button = null
var pause_restart_btn: Button = null
var pause_title_btn: Button = null

var ach_toast_panel: PanelContainer = null
var ach_toast_title: Label = null
var ach_toast_desc: Label = null
var _ach_queue: Array[Dictionary] = []
var _ach_toast_timer: float = 0.0

var hud_left_panel: PanelContainer = null
var hud_right_panel: PanelContainer = null
var level_badge_panel: PanelContainer = null

var levelup_sub_label: Label = null
var cards_hbox: HBoxContainer = null
var _current_upgrade_buttons: Array[Button] = []

var outcome_label: Label = null
var summary_stage_label: Label = null
var summary_outcome_val: Label = null
var summary_time_val: Label = null
var summary_level_val: Label = null
var summary_kills_val: Label = null
var summary_score_val: Label = null
var summary_ach_val: Label = null
var restart_btn: Button = null
var switch_stage_btn: Button = null
var title_btn: Button = null

var _ui_font: Font = null
var _ui_bold_font: Font = null
var _has_thai_font: bool = false
var _ui_theme: Theme = null

var _state: GameState = GameState.TITLE
var _title_swim_t: float = 0.0
var _last_timer_sec: int = -1
var _autotest_running: bool = false
var _autotest_suppress_levelup: bool = false
var _stage_clear_triggered: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_controller_input_map()
	_build_ui_theme()
	_setup_world()
	_setup_ui()
	_connect_signals()
	_enter_title_screen()

	var is_autotest: bool = ("--autotest" in OS.get_cmdline_args()) or ("--autotest" in OS.get_cmdline_user_args())
	if is_autotest:
		_autotest_running = true
		_run_autotest()


func _build_ui_theme() -> void:
	_ui_theme = Theme.new()
	if ResourceLoader.exists("res://fonts/LeelawUI.ttf"):
		var res_f := ResourceLoader.load("res://fonts/LeelawUI.ttf")
		if res_f is Font:
			_ui_font = res_f as Font
			_has_thai_font = _ui_font.has_char(0x0E19)
	if ResourceLoader.exists("res://fonts/LeelaUIb.ttf"):
		var res_fb := ResourceLoader.load("res://fonts/LeelaUIb.ttf")
		if res_fb is Font:
			_ui_bold_font = res_fb as Font

	if _ui_font == null:
		var font_paths := [
			"C:/Windows/Fonts/LeelawUI.ttf",
			"C:/Windows/Fonts/leelawui.ttf",
			"C:/Windows/Fonts/tahoma.ttf",
			"C:/Windows/Fonts/LeelaUIb.ttf",
		]
		for p in font_paths:
			if FileAccess.file_exists(p):
				var ff := FontFile.new()
				if ff.load_dynamic_font(p) == OK:
					_ui_font = ff
					_has_thai_font = ff.has_char(0x0E19)
					break

	if _ui_bold_font == null:
		var bold_paths := [
			"C:/Windows/Fonts/LeelaUIb.ttf",
			"C:/Windows/Fonts/tahomabd.ttf",
		]
		for p in bold_paths:
			if FileAccess.file_exists(p):
				var ffb := FontFile.new()
				if ffb.load_dynamic_font(p) == OK:
					_ui_bold_font = ffb
					break

	if _ui_bold_font == null:
		_ui_bold_font = _ui_font

	if _ui_font != null:
		_ui_theme.default_font = _ui_font
		_ui_theme.default_font_size = 16


func _setup_world() -> void:
	ocean_background = OCEAN_BG_SCRIPT.new() as Node2D
	ocean_background.name = "OceanBackground"
	ocean_background.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ocean_background)

	title_preview_layer = TitlePreviewLayer.new()
	title_preview_layer.name = "TitlePreviewLayer"
	title_preview_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(title_preview_layer)

	gem_container = Node2D.new()
	gem_container.name = "GemContainer"
	gem_container.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(gem_container)

	projectile_container = Node2D.new()
	projectile_container.name = "ProjectileContainer"
	projectile_container.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(projectile_container)

	enemy_container = Node2D.new()
	enemy_container.name = "EnemyContainer"
	enemy_container.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(enemy_container)

	player = PLAYER_SCRIPT.new() as CharacterBody2D
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)

	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.5
	camera.enabled = true
	player.add_child(camera)
	camera.make_current()

	fx_manager = FX_MANAGER_SCRIPT.new() as Node2D
	fx_manager.name = "FxManager"
	fx_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	fx_manager.set("camera_ref", camera)
	add_child(fx_manager)

	player.set("projectile_container", projectile_container)
	player.set("fx_manager", fx_manager)

	wave_spawner = WAVE_SPAWNER_SCRIPT.new() as Node2D
	wave_spawner.name = "WaveSpawner"
	wave_spawner.process_mode = Node.PROCESS_MODE_PAUSABLE
	wave_spawner.set("player", player)
	wave_spawner.set("enemy_container", enemy_container)
	wave_spawner.set("gem_container", gem_container)
	wave_spawner.set("fx_manager", fx_manager)
	add_child(wave_spawner)


func _make_panel_style(bg: Color, border: Color, corner: int = 12, border_w: int = 2, pad: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(corner)
	sb.set_content_margin_all(pad)
	sb.shadow_color = Color(border.r, border.g, border.b, 0.25)
	sb.shadow_size = 8
	return sb


func _make_button(name_str: String, text_str: String, accent: Color, min_size: Vector2, font_sz: int = 18) -> Button:
	var btn := Button.new()
	btn.name = name_str
	btn.text = text_str
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal := _make_panel_style(Color(accent.r * 0.14, accent.g * 0.18, accent.b * 0.22, 0.92), accent, 10, 2, 12)
	var hover := _make_panel_style(Color(accent.r * 0.28, accent.g * 0.34, accent.b * 0.40, 0.98), accent.lightened(0.35), 10, 2, 12)
	var pressed := _make_panel_style(Color(accent.r * 0.42, accent.g * 0.48, accent.b * 0.52, 1.0), Color.WHITE, 10, 2, 12)
	var focused := _make_panel_style(Color(accent.r * 0.32, accent.g * 0.38, accent.b * 0.44, 0.98), Color("#fee440"), 10, 3, 12)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focused)
	btn.add_theme_color_override("font_color", Color("#f0fdff"))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color("#fef08a"))
	btn.add_theme_font_size_override("font_size", font_sz)
	if _ui_bold_font != null:
		btn.add_theme_font_override("font", _ui_bold_font)
	return btn


func _style_label(lbl: Label, font_sz: int, col: Color, bold: bool = false) -> void:
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.06, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	if bold and _ui_bold_font != null:
		lbl.add_theme_font_override("font", _ui_bold_font)


func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	ui_layer.layer = 10
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)

	ui_root = Control.new()
	ui_root.name = "UIRoot"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _ui_theme != null:
		ui_root.theme = _ui_theme
	ui_layer.add_child(ui_root)

	_build_title_ui()
	_build_hud_ui()
	_build_levelup_ui()
	_build_pause_ui()
	_build_gameover_ui()
	_build_achievement_toast()


func _build_title_ui() -> void:
	title_panel = Control.new()
	title_panel.name = "TitlePanel"
	title_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(title_panel)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.04, 0.10, 0.40)
	title_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 150
	title_panel.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(680, 0)
	card.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.02, 0.08, 0.17, 0.80), Color("#00f5d4"), 18, 2, 28)
	)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "โลมานีออน ผู้พิทักษ์สมุทร"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title_lbl, 40, Color("#00f5d4"), true)
	vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "เอาชีวิตรอดใต้ทะเลนีออน 2 สมรภูมิ  |  หลบหลีก ยิงอัตโนมัติ เก็บพลังอัปเกรด"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(sub_lbl, 17, Color("#bae6fd"), false)
	vbox.add_child(sub_lbl)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	vbox.add_child(sep)

	start_stage1_btn = _make_button("StartStage1Btn", "ด่าน 1: แนวปะการังน้ำตื้น", Color("#00f5d4"), Vector2(580, 56), 20)
	start_stage1_btn.pressed.connect(_on_start_stage_pressed.bind(1))
	vbox.add_child(start_stage1_btn)

	start_stage2_btn = _make_button("StartStage2Btn", "ด่าน 2: ห้วงเหวน้ำลึก", Color("#bf5af2"), Vector2(580, 56), 20)
	start_stage2_btn.pressed.connect(_on_start_stage_pressed.bind(2))
	vbox.add_child(start_stage2_btn)

	title_ach_label = Label.new()
	title_ach_label.text = "ความสำเร็จที่ปลดล็อก: 0 / 7"
	title_ach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title_ach_label, 16, Color("#fee440"), true)
	vbox.add_child(title_ach_label)

	var hint_lbl := Label.new()
	hint_lbl.text = "ควบคุม: WASD / ปุ่มลูกศร / จอยสติ๊ก / แตะลากบนมือถือ  |  ยิงอัตโนมัติ"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(hint_lbl, 15, Color("#7dd3fc"), false)
	vbox.add_child(hint_lbl)


func _build_hud_ui() -> void:
	hud_root = Control.new()
	hud_root.name = "HUDRoot"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hud_root)

	# Top full-width XP Bar + Level badge
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 18
	top_bar.offset_right = -18
	top_bar.offset_top = 12
	top_bar.offset_bottom = 44
	top_bar.add_theme_constant_override("separation", 12)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(top_bar)

	xp_bar = ProgressBar.new()
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.custom_minimum_size = Vector2(0, 30)
	xp_bar.show_percentage = false
	xp_bar.max_value = 10.0
	xp_bar.value = 0.0
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bar.add_theme_stylebox_override("background", _make_panel_style(Color(0.02, 0.06, 0.14, 0.85), Color("#1e3a5f"), 8, 2, 0))
	xp_bar.add_theme_stylebox_override("fill", _make_panel_style(Color("#00f5d4"), Color("#a5f3fc"), 6, 1, 0))
	top_bar.add_child(xp_bar)

	xp_label = Label.new()
	xp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.text = "XP 0 / 10"
	_style_label(xp_label, 14, Color.WHITE, true)
	xp_bar.add_child(xp_label)

	level_badge_panel = PanelContainer.new()
	level_badge_panel.custom_minimum_size = Vector2(104, 30)
	level_badge_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.10, 0.20, 0.90), Color("#fee440"), 8, 2, 4))
	top_bar.add_child(level_badge_panel)

	level_label = Label.new()
	level_label.text = "เลเวล 1"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(level_label, 16, Color("#fee440"), true)
	level_badge_panel.add_child(level_label)

	# Top-left compact panel: Stage name, HP bar + numeric HP, Active weapons summary
	hud_left_panel = PanelContainer.new()
	hud_left_panel.position = Vector2(18, 54)
	hud_left_panel.custom_minimum_size = Vector2(360, 0)
	hud_left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_left_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.02, 0.06, 0.14, 0.80), Color("#00f5d4"), 12, 2, 12))
	hud_root.add_child(hud_left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 6)
	hud_left_panel.add_child(left_vbox)

	stage_name_label = Label.new()
	stage_name_label.text = "ด่าน 1: แนวปะการังน้ำตื้น"
	_style_label(stage_name_label, 16, Color("#00f5d4"), true)
	left_vbox.add_child(stage_name_label)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(332, 24)
	hp_bar.show_percentage = false
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	hp_bar.add_theme_stylebox_override("background", _make_panel_style(Color(0.10, 0.04, 0.08, 0.90), Color("#475569"), 6, 1, 0))
	hp_bar.add_theme_stylebox_override("fill", _make_panel_style(Color("#06d6a0"), Color("#a7f3d0"), 5, 1, 0))
	left_vbox.add_child(hp_bar)

	hp_label = Label.new()
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.text = "พลังชีวิต 100/100"
	_style_label(hp_label, 14, Color.WHITE, true)
	hp_bar.add_child(hp_label)

	weapons_label = Label.new()
	weapons_label.text = "อาวุธ: โซนาร์ Lv.1"
	weapons_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapons_label.custom_minimum_size = Vector2(332, 0)
	_style_label(weapons_label, 14, Color("#bae6fd"), false)
	left_vbox.add_child(weapons_label)

	# Top-right compact panel: Survival Timer, Kills, Score, Achievements
	hud_right_panel = PanelContainer.new()
	hud_right_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud_right_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud_right_panel.custom_minimum_size = Vector2(300, 0)
	hud_right_panel.offset_left = -318
	hud_right_panel.offset_right = -18
	hud_right_panel.offset_top = 54
	hud_right_panel.offset_bottom = 54
	hud_right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_right_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.02, 0.06, 0.14, 0.80), Color("#00f5d4"), 12, 2, 12))
	hud_root.add_child(hud_right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 4)
	hud_right_panel.add_child(right_vbox)

	timer_label = Label.new()
	timer_label.text = "00:00 / 01:30"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(timer_label, 22, Color("#f0fdff"), true)
	right_vbox.add_child(timer_label)

	var stats_hbox := HBoxContainer.new()
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_hbox.add_theme_constant_override("separation", 18)
	right_vbox.add_child(stats_hbox)

	kills_label = Label.new()
	kills_label.text = "สังหาร: 0"
	_style_label(kills_label, 15, Color("#ff758f"), true)
	stats_hbox.add_child(kills_label)

	score_label = Label.new()
	score_label.text = "คะแนน: 0"
	_style_label(score_label, 15, Color("#fee440"), true)
	stats_hbox.add_child(score_label)

	hud_ach_label = Label.new()
	hud_ach_label.text = "ความสำเร็จ: 0 / 7"
	hud_ach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(hud_ach_label, 13, Color("#a5f3fc"), false)
	right_vbox.add_child(hud_ach_label)

	virtual_joystick = TouchJoystick.new()
	virtual_joystick.name = "TouchJoystick"
	hud_root.add_child(virtual_joystick)

	pause_hud_btn = _make_button("PauseHudBtn", "พักเกม (Start / Esc)", Color("#38bdf8"), Vector2(180, 42), 14)
	pause_hud_btn.focus_mode = Control.FOCUS_NONE
	pause_hud_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pause_hud_btn.offset_left = -200
	pause_hud_btn.offset_right = -20
	pause_hud_btn.offset_top = -62
	pause_hud_btn.offset_bottom = -20
	pause_hud_btn.pressed.connect(_on_pause_hud_pressed)
	hud_root.add_child(pause_hud_btn)


func _build_levelup_ui() -> void:
	levelup_panel = Control.new()
	levelup_panel.name = "LevelUpPanel"
	levelup_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	levelup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(levelup_panel)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.06, 0.74)
	levelup_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	levelup_panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	var hdr := Label.new()
	hdr.text = "อัปเลเวล!"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(hdr, 44, Color("#fee440"), true)
	vbox.add_child(hdr)

	levelup_sub_label = Label.new()
	levelup_sub_label.text = "เลือกการ์ดพลัง 1 ใบ"
	levelup_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(levelup_sub_label, 18, Color("#bae6fd"), false)
	vbox.add_child(levelup_sub_label)

	cards_hbox = HBoxContainer.new()
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_theme_constant_override("separation", 22)
	vbox.add_child(cards_hbox)


func _build_pause_ui() -> void:
	pause_panel = Control.new()
	pause_panel.name = "PausePanel"
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(pause_panel)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.07, 0.76)
	pause_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 0)
	card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.02, 0.07, 0.16, 0.95), Color("#38bdf8"), 18, 2, 28))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var hdr := Label.new()
	hdr.text = "พักเกม"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(hdr, 38, Color("#38bdf8"), true)
	vbox.add_child(hdr)

	var sub := Label.new()
	sub.text = "กดปุ่ม A เพื่อเลือก  |  กด B / Start / Esc เพื่อเล่นต่อ"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(sub, 14, Color("#bae6fd"), false)
	vbox.add_child(sub)

	resume_btn = _make_button("ResumeBtn", "เล่นต่อ", Color("#00f5d4"), Vector2(360, 50), 18)
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)

	pause_restart_btn = _make_button("PauseRestartBtn", "เริ่มด่านนี้ใหม่", Color("#fee440"), Vector2(360, 50), 18)
	pause_restart_btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(pause_restart_btn)

	pause_title_btn = _make_button("PauseTitleBtn", "กลับหน้าหลัก", Color("#bf5af2"), Vector2(360, 50), 18)
	pause_title_btn.pressed.connect(_on_title_pressed)
	vbox.add_child(pause_title_btn)


func _build_gameover_ui() -> void:
	gameover_panel = Control.new()
	gameover_panel.name = "GameOverPanel"
	gameover_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameover_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(gameover_panel)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.07, 0.80)
	gameover_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameover_panel.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 0)
	card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.02, 0.07, 0.16, 0.94), Color("#00f5d4"), 18, 2, 32))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	outcome_label = Label.new()
	outcome_label.text = "จบเกม"
	outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(outcome_label, 42, Color("#ff4d6d"), true)
	vbox.add_child(outcome_label)

	summary_stage_label = Label.new()
	summary_stage_label.text = "ด่าน 1: แนวปะการังน้ำตื้น"
	summary_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(summary_stage_label, 18, Color("#7dd3fc"), false)
	vbox.add_child(summary_stage_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 48)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	summary_outcome_val = _add_stat_row(grid, "ผลลัพธ์:")
	summary_time_val = _add_stat_row(grid, "เวลาที่รอด:")
	summary_level_val = _add_stat_row(grid, "เลเวลสูงสุด:")
	summary_kills_val = _add_stat_row(grid, "กำจัดศัตรู:")
	summary_score_val = _add_stat_row(grid, "คะแนนรวม:")
	summary_ach_val = _add_stat_row(grid, "ความสำเร็จ:")

	var btn_spacer := Control.new()
	btn_spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(btn_spacer)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	restart_btn = _make_button("RestartBtn", "เล่นด่านนี้อีกครั้ง", Color("#00f5d4"), Vector2(180, 48), 16)
	restart_btn.pressed.connect(_on_restart_pressed)
	btn_row.add_child(restart_btn)

	switch_stage_btn = _make_button("SwitchStageBtn", "ไปด่าน 2", Color("#bf5af2"), Vector2(175, 48), 16)
	switch_stage_btn.pressed.connect(_on_switch_stage_pressed)
	btn_row.add_child(switch_stage_btn)

	title_btn = _make_button("TitleBtn", "กลับหน้าหลัก", Color("#38bdf8"), Vector2(165, 48), 16)
	title_btn.pressed.connect(_on_title_pressed)
	btn_row.add_child(title_btn)


func _build_achievement_toast() -> void:
	ach_toast_panel = PanelContainer.new()
	ach_toast_panel.name = "AchievementToast"
	ach_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	ach_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ach_toast_panel.offset_top = 56
	ach_toast_panel.custom_minimum_size = Vector2(360, 0)
	ach_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ach_toast_panel.visible = false
	ach_toast_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.03, 0.08, 0.18, 0.94), Color("#fee440"), 12, 2, 12)
	)
	ui_root.add_child(ach_toast_panel)

	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	ach_toast_panel.add_child(tv)

	ach_toast_title = Label.new()
	ach_toast_title.text = "ปลดล็อกความสำเร็จ!"
	ach_toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(ach_toast_title, 16, Color("#fee440"), true)
	tv.add_child(ach_toast_title)

	ach_toast_desc = Label.new()
	ach_toast_desc.text = "-"
	ach_toast_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(ach_toast_desc, 14, Color("#e0f2fe"), false)
	tv.add_child(ach_toast_desc)


func _add_stat_row(grid: GridContainer, label_text: String) -> Label:
	var key_lbl := Label.new()
	key_lbl.text = label_text
	_style_label(key_lbl, 18, Color("#94a3b8"), false)
	grid.add_child(key_lbl)

	var val_lbl := Label.new()
	val_lbl.text = "-"
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(val_lbl, 18, Color.WHITE, true)
	grid.add_child(val_lbl)
	return val_lbl


func _connect_signals() -> void:
	GameData.xp_changed.connect(_on_xp_changed)
	GameData.level_up_triggered.connect(_on_level_up_triggered)
	GameData.stats_changed.connect(_on_stats_changed)
	GameData.achievement_unlocked.connect(_on_achievement_unlocked)
	player.connect("hp_changed", _on_player_hp_changed)
	player.connect("died", _on_player_died)


func _set_state(new_state: GameState) -> void:
	_state = new_state
	title_panel.visible = (new_state == GameState.TITLE)
	hud_root.visible = (new_state == GameState.PLAYING or new_state == GameState.LEVEL_UP or new_state == GameState.PAUSE)
	levelup_panel.visible = (new_state == GameState.LEVEL_UP)
	if pause_panel != null:
		pause_panel.visible = (new_state == GameState.PAUSE)
	gameover_panel.visible = (new_state == GameState.GAME_OVER)
	if virtual_joystick != null:
		virtual_joystick.visible = (new_state == GameState.PLAYING)
		if new_state != GameState.PLAYING:
			virtual_joystick.reset_stick()
	if pause_hud_btn != null:
		pause_hud_btn.visible = (new_state == GameState.PLAYING)
	if is_instance_valid(player):
		player.set("touch_move_dir", Vector2.ZERO)
	call_deferred("_focus_default_button")


func _focus_default_button() -> void:
	if _autotest_running:
		return
	match _state:
		GameState.TITLE:
			if is_instance_valid(start_stage1_btn):
				start_stage1_btn.grab_focus()
		GameState.LEVEL_UP:
			if not _current_upgrade_buttons.is_empty() and is_instance_valid(_current_upgrade_buttons[0]):
				_current_upgrade_buttons[0].grab_focus()
		GameState.PAUSE:
			if is_instance_valid(resume_btn):
				resume_btn.grab_focus()
		GameState.GAME_OVER:
			if is_instance_valid(restart_btn):
				restart_btn.grab_focus()


func _setup_controller_input_map() -> void:
	_ensure_joy_button_action("ui_accept", JOY_BUTTON_A)
	_ensure_joy_button_action("ui_cancel", JOY_BUTTON_B)
	_ensure_joy_button_action("ui_up", JOY_BUTTON_DPAD_UP)
	_ensure_joy_button_action("ui_down", JOY_BUTTON_DPAD_DOWN)
	_ensure_joy_button_action("ui_left", JOY_BUTTON_DPAD_LEFT)
	_ensure_joy_button_action("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_ensure_joy_axis_action("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_ensure_joy_axis_action("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_ensure_joy_axis_action("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_ensure_joy_axis_action("ui_right", JOY_AXIS_LEFT_X, 1.0)


func _ensure_joy_button_action(action_name: String, btn_idx: JoyButton) -> void:
	if not InputMap.has_action(action_name):
		return
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == btn_idx:
			return
	var jb := InputEventJoypadButton.new()
	jb.button_index = btn_idx
	InputMap.action_add_event(action_name, jb)


func _ensure_joy_axis_action(action_name: String, axis_idx: JoyAxis, axis_val: float) -> void:
	if not InputMap.has_action(action_name):
		return
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventJoypadMotion:
			var jm := ev as InputEventJoypadMotion
			if jm.axis == axis_idx and signf(jm.axis_value) == signf(axis_val):
				return
	var jm := InputEventJoypadMotion.new()
	jm.axis = axis_idx
	jm.axis_value = axis_val
	InputMap.action_add_event(action_name, jm)


func _input(event: InputEvent) -> void:
	if _autotest_running:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_ESCAPE or k.keycode == KEY_P):
			if _state == GameState.PLAYING:
				_toggle_pause(true)
				get_viewport().set_input_as_handled()
			elif _state == GameState.PAUSE:
				_toggle_pause(false)
				get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if not jb.pressed:
			return
		if jb.button_index == JOY_BUTTON_START or jb.button_index == JOY_BUTTON_BACK:
			if _state == GameState.PLAYING:
				_toggle_pause(true)
				get_viewport().set_input_as_handled()
			elif _state == GameState.PAUSE:
				_toggle_pause(false)
				get_viewport().set_input_as_handled()
		elif jb.button_index == JOY_BUTTON_B and _state == GameState.PAUSE:
			_toggle_pause(false)
			get_viewport().set_input_as_handled()
		elif jb.button_index == JOY_BUTTON_A and _state != GameState.PLAYING:
			_activate_focused_button()
			get_viewport().set_input_as_handled()


func _activate_focused_button() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is Button and focused.is_visible_in_tree():
		(focused as Button).pressed.emit()
		return
	match _state:
		GameState.TITLE:
			if is_instance_valid(start_stage1_btn):
				start_stage1_btn.pressed.emit()
		GameState.LEVEL_UP:
			if not _current_upgrade_buttons.is_empty() and is_instance_valid(_current_upgrade_buttons[0]):
				_current_upgrade_buttons[0].pressed.emit()
		GameState.PAUSE:
			if is_instance_valid(resume_btn):
				resume_btn.pressed.emit()
		GameState.GAME_OVER:
			if is_instance_valid(restart_btn):
				restart_btn.pressed.emit()


func _toggle_pause(pause_on: bool) -> void:
	SoundManager.play_button()
	if pause_on and _state == GameState.PLAYING:
		get_tree().paused = true
		_set_state(GameState.PAUSE)
	elif not pause_on and _state == GameState.PAUSE:
		_set_state(GameState.PLAYING)
		get_tree().paused = false


func _on_pause_hud_pressed() -> void:
	_toggle_pause(true)


func _on_resume_pressed() -> void:
	_toggle_pause(false)


func _clear_container(container: Node) -> void:
	if not is_instance_valid(container):
		return
	var children := container.get_children()
	for child in children:
		container.remove_child(child)
		child.queue_free()


func _enter_title_screen() -> void:
	get_tree().paused = false
	_stage_clear_triggered = false
	wave_spawner.call("stop")
	_clear_container(enemy_container)
	_clear_container(projectile_container)
	_clear_container(gem_container)

	player.call("reset_player")
	var wl: Variant = player.get("weapon_levels")
	if wl is Dictionary:
		(wl as Dictionary)["sonic_pulse"] = 0
	player.global_position = Vector2.ZERO
	camera.position = Vector2(0.0, 165.0)
	camera.offset = Vector2.ZERO
	camera.reset_smoothing()

	ocean_background.call("set_stage", 1)
	ocean_background.call("set_camera_pos", camera.position)
	if title_preview_layer != null:
		title_preview_layer.visible = true
		title_preview_layer.position = camera.position

	_title_swim_t = 0.0
	if title_ach_label != null:
		title_ach_label.text = "ความสำเร็จที่ปลดล็อก: %d / %d" % [GameData.get_unlocked_count(), GameData.get_total_achievements()]
	_set_state(GameState.TITLE)


func _start_game(stage_id: int) -> void:
	get_tree().paused = false
	_stage_clear_triggered = false
	_last_timer_sec = -1
	wave_spawner.call("stop")
	_clear_container(enemy_container)
	_clear_container(projectile_container)
	_clear_container(gem_container)

	GameData.reset_run(stage_id)
	player.call("reset_player")
	player.set("autotest_move_dir", Vector2.ZERO)
	player.global_position = Vector2.ZERO
	camera.position = Vector2.ZERO
	camera.offset = Vector2.ZERO
	camera.reset_smoothing()

	ocean_background.call("set_stage", stage_id)
	ocean_background.call("set_camera_pos", Vector2.ZERO)
	if title_preview_layer != null:
		title_preview_layer.visible = false

	_apply_stage_hud_theme(stage_id)
	_set_state(GameState.PLAYING)
	_refresh_all_hud()
	wave_spawner.call("start_stage", stage_id)


func _apply_stage_hud_theme(stage_id: int) -> void:
	var stage_info: Dictionary = GameData.STAGES.get(stage_id, GameData.STAGES[1])
	var accent: Color = stage_info.get("accent", Color("#00f5d4"))
	var stage_title: String = str(stage_info.get("name", "Stage 1"))
	if _has_thai_font and stage_info.has("subtitle"):
		stage_name_label.text = "%s\n%s" % [stage_title, str(stage_info["subtitle"])]
	else:
		stage_name_label.text = stage_title
	_style_label(stage_name_label, 15, accent, true)

	hud_left_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.02, 0.06, 0.14, 0.80), accent, 12, 2, 12))
	hud_right_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.02, 0.06, 0.14, 0.80), accent, 12, 2, 12))
	xp_bar.add_theme_stylebox_override("fill", _make_panel_style(accent, accent.lightened(0.45), 6, 1, 0))


func _process(delta: float) -> void:
	if _state == GameState.TITLE:
		_title_swim_t += delta
		var swim_dir := Vector2(cos(_title_swim_t * 0.85), sin(_title_swim_t * 1.7) * 0.55).normalized()
		player.set("autotest_move_dir", swim_dir)
		# Keep idle preview dolphin near center
		if player.global_position.length() > 160.0:
			player.set("autotest_move_dir", (-player.global_position).normalized())
		var cam_pos := camera.get_screen_center_position()
		ocean_background.call("set_camera_pos", cam_pos)
		if title_preview_layer != null:
			title_preview_layer.position = cam_pos
		return

	if _state == GameState.PLAYING and not get_tree().paused:
		GameData.time_survived += delta
		if virtual_joystick != null and is_instance_valid(player):
			player.set("touch_move_dir", virtual_joystick.direction)
		var cam_pos := camera.get_screen_center_position()
		ocean_background.call("set_camera_pos", cam_pos)

		var sec_int: int = int(floor(GameData.time_survived))
		if sec_int != _last_timer_sec:
			_last_timer_sec = sec_int
			_update_timer_label()
			GameData.check_progress_achievements()

		var stage_info: Dictionary = GameData.STAGES.get(GameData.current_stage, GameData.STAGES[1])
		var duration: float = float(stage_info.get("duration", 90.0))
		if GameData.time_survived >= duration and not _stage_clear_triggered and not _autotest_running:
			_stage_clear_triggered = true
			GameData.notify_stage_clear(GameData.current_stage)
			_trigger_game_over(true)

	_update_achievement_toast(delta)


func _format_time(sec_val: float) -> String:
	var total: int = maxi(0, int(floor(sec_val)))
	var m: int = int(total / 60)
	var s: int = total % 60
	return "%02d:%02d" % [m, s]


func _update_timer_label() -> void:
	var stage_info: Dictionary = GameData.STAGES.get(GameData.current_stage, GameData.STAGES[1])
	var duration: float = float(stage_info.get("duration", 90.0))
	timer_label.text = "%s / %s" % [_format_time(GameData.time_survived), _format_time(duration)]


func _refresh_all_hud() -> void:
	_on_xp_changed(GameData.current_xp, GameData.xp_to_next, GameData.level)
	_on_stats_changed()
	var cur_hp: float = float(player.get("hp"))
	var m_hp: float = float(player.get("max_hp"))
	_on_player_hp_changed(cur_hp, m_hp)
	_update_timer_label()


func _on_xp_changed(current_xp: int, max_xp: int, lvl: int) -> void:
	xp_bar.max_value = maxf(1.0, float(max_xp))
	xp_bar.value = clampf(float(current_xp), 0.0, float(max_xp))
	xp_label.text = "XP %d / %d" % [current_xp, max_xp]
	level_label.text = "เลเวล %d" % lvl


func _on_stats_changed() -> void:
	kills_label.text = "สังหาร: %d" % GameData.kills
	score_label.text = "คะแนน: %d" % GameData.score
	if hud_ach_label != null:
		hud_ach_label.text = "ความสำเร็จ: %d / %d" % [GameData.get_unlocked_count(), GameData.get_total_achievements()]
	if title_ach_label != null:
		title_ach_label.text = "ความสำเร็จที่ปลดล็อก: %d / %d" % [GameData.get_unlocked_count(), GameData.get_total_achievements()]
	if is_instance_valid(player) and player.has_method("get_weapon_summary"):
		weapons_label.text = "อาวุธ: " + str(player.call("get_weapon_summary"))


func _on_achievement_unlocked(_ach_id: String, title: String, desc: String) -> void:
	_ach_queue.append({"title": title, "desc": desc})
	SoundManager.play_achievement()
	if ach_toast_panel != null and not ach_toast_panel.visible:
		_show_next_achievement_toast()


func _show_next_achievement_toast() -> void:
	if _ach_queue.is_empty() or ach_toast_panel == null:
		if ach_toast_panel != null:
			ach_toast_panel.visible = false
		return
	var item: Dictionary = _ach_queue.pop_front()
	ach_toast_title.text = "ปลดล็อกความสำเร็จ: %s" % str(item.get("title", ""))
	ach_toast_desc.text = str(item.get("desc", ""))
	ach_toast_panel.visible = true
	_ach_toast_timer = 3.2


func _update_achievement_toast(delta: float) -> void:
	if ach_toast_panel == null or not ach_toast_panel.visible:
		return
	_ach_toast_timer -= delta
	if _ach_toast_timer <= 0.0:
		if _ach_queue.is_empty():
			ach_toast_panel.visible = false
		else:
			_show_next_achievement_toast()


func _on_player_hp_changed(current_hp: float, max_hp_val: float) -> void:
	hp_bar.max_value = maxf(1.0, max_hp_val)
	hp_bar.value = clampf(current_hp, 0.0, max_hp_val)
	hp_label.text = "พลังชีวิต %d/%d" % [int(ceil(current_hp)), int(round(max_hp_val))]

	var ratio: float = clampf(current_hp / maxf(1.0, max_hp_val), 0.0, 1.0)
	var fill_col: Color = Color("#06d6a0")
	if ratio < 0.32:
		fill_col = Color("#ff4d6d")
	elif ratio < 0.62:
		fill_col = Color("#fbbf24")
	hp_bar.add_theme_stylebox_override("fill", _make_panel_style(fill_col, fill_col.lightened(0.35), 5, 1, 0))


func _on_level_up_triggered(new_level: int, choices: Array) -> void:
	if _autotest_suppress_levelup:
		return
	if _state != GameState.PLAYING:
		return
	SoundManager.play_level_up()
	_populate_upgrade_cards(new_level, choices)
	_set_state(GameState.LEVEL_UP)
	get_tree().paused = true


func _populate_upgrade_cards(new_level: int, choices: Array) -> void:
	_clear_container(cards_hbox)
	_current_upgrade_buttons.clear()
	levelup_sub_label.text = "ถึงเลเวล %d แล้ว — เลือกการ์ดพลัง 1 ใบ" % new_level

	for choice_var in choices:
		if not (choice_var is Dictionary):
			continue
		var choice: Dictionary = choice_var
		var upg_id: String = str(choice.get("id", ""))
		var upg_name: String = str(choice.get("name", "อัปเกรด"))
		var upg_desc: String = str(choice.get("desc", ""))
		var upg_col: Color = choice.get("color", Color("#00f5d4"))
		var max_lv: int = int(choice.get("max_level", 5))
		var cur_lv: int = int(GameData.upgrade_levels.get(upg_id, 0))

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(300, 320)
		card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.09, 0.19, 0.94), upg_col, 16, 2, 20))
		cards_hbox.add_child(card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 12)
		card.add_child(cv)

		var badge_panel := PanelContainer.new()
		badge_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(upg_col.r * 0.25, upg_col.g * 0.25, upg_col.b * 0.25, 0.9), upg_col, 8, 1, 6))
		cv.add_child(badge_panel)

		var lv_lbl := Label.new()
		if cur_lv <= 0:
			lv_lbl.text = "ใหม่!  เลเวล 1"
		elif cur_lv < max_lv:
			lv_lbl.text = "เลเวล %d  ->  %d" % [cur_lv, cur_lv + 1]
		else:
			lv_lbl.text = "โอเวอร์ไดรฟ์  เลเวล %d" % [cur_lv + 1]
		_style_label(lv_lbl, 14, upg_col.lightened(0.3), true)
		badge_panel.add_child(lv_lbl)

		var name_lbl := Label.new()
		name_lbl.text = upg_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_label(name_lbl, 24, Color.WHITE, true)
		cv.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = upg_desc
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_style_label(desc_lbl, 16, Color("#cbd5e1"), false)
		cv.add_child(desc_lbl)

		var sel_btn := _make_button("Select_" + upg_id, "เลือก", upg_col, Vector2(240, 46), 17)
		sel_btn.pressed.connect(_on_upgrade_selected.bind(upg_id))
		cv.add_child(sel_btn)
		_current_upgrade_buttons.append(sel_btn)


func _on_upgrade_selected(upgrade_id: String) -> void:
	player.call("apply_upgrade", upgrade_id)
	GameData.record_upgrade(upgrade_id)
	SoundManager.play_button()
	_set_state(GameState.PLAYING)
	get_tree().paused = false
	_refresh_all_hud()


func _on_player_died() -> void:
	if _state == GameState.GAME_OVER or _autotest_running:
		return
	_trigger_game_over(false)


func _trigger_game_over(stage_cleared: bool) -> void:
	wave_spawner.call("stop")
	get_tree().paused = true
	_set_state(GameState.GAME_OVER)

	if stage_cleared:
		SoundManager.play_stage_clear()
		outcome_label.text = "ผ่านด่านสำเร็จ!"
		_style_label(outcome_label, 42, Color("#00f5d4"), true)
		summary_outcome_val.text = "รอดชีวิต!"
		_style_label(summary_outcome_val, 18, Color("#06d6a0"), true)
	else:
		SoundManager.play_game_over()
		outcome_label.text = "จบเกม"
		_style_label(outcome_label, 42, Color("#ff4d6d"), true)
		summary_outcome_val.text = "พ่ายแพ้"
		_style_label(summary_outcome_val, 18, Color("#ff4d6d"), true)

	var stage_info: Dictionary = GameData.STAGES.get(GameData.current_stage, GameData.STAGES[1])
	var stage_name_txt: String = str(stage_info.get("name", "ด่าน 1"))
	if stage_info.has("subtitle"):
		summary_stage_label.text = "%s (%s)" % [stage_name_txt, str(stage_info["subtitle"])]
	else:
		summary_stage_label.text = stage_name_txt

	var duration: float = float(stage_info.get("duration", 90.0))
	summary_time_val.text = "%s / %s" % [_format_time(GameData.time_survived), _format_time(duration)]
	summary_level_val.text = "เลเวล %d" % GameData.level
	summary_kills_val.text = str(GameData.kills)
	summary_score_val.text = str(GameData.score)
	if summary_ach_val != null:
		summary_ach_val.text = "%d / %d" % [GameData.get_unlocked_count(), GameData.get_total_achievements()]

	switch_stage_btn.text = "ไปด่าน 2" if GameData.current_stage == 1 else "ไปด่าน 1"


func _on_start_stage_pressed(stage_id: int) -> void:
	SoundManager.play_button()
	_start_game(stage_id)


func _on_restart_pressed() -> void:
	SoundManager.play_button()
	_start_game(GameData.current_stage)


func _on_switch_stage_pressed() -> void:
	SoundManager.play_button()
	var next_stage: int = 2 if GameData.current_stage == 1 else 1
	_start_game(next_stage)


func _on_title_pressed() -> void:
	SoundManager.play_button()
	_enter_title_screen()


func _spawn_autotest_pearls() -> void:
	var offsets := [
		Vector2(150.0, 20.0),
		Vector2(-155.0, -35.0),
		Vector2(40.0, 155.0),
		Vector2(-45.0, -150.0),
		Vector2(130.0, -110.0),
	]
	for off in offsets:
		var gem := XP_GEM_SCRIPT.new() as Area2D
		gem.global_position = player.global_position + off
		gem.set("xp_value", 2)
		gem.set("gem_color", Color("#38bdf8"))
		gem.set("player_ref", player)
		gem_container.add_child(gem)


func _capture_screenshot(res_path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	if vp == null:
		return
	var tex := vp.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img != null:
		var abs_path: String = ProjectSettings.globalize_path(res_path)
		var err := img.save_png(abs_path)
		if err != OK:
			push_warning("Screenshot save failed: %s (err=%d)" % [abs_path, err])


func _run_autotest() -> void:
	# 1) Ensure screenshots directory exists
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))

	# 2) Wait ~0.45s on Title Screen -> capture 01_title.png
	await get_tree().create_timer(0.45, true).timeout
	await _capture_screenshot("res://screenshots/01_title.png")

	# 3) Start Stage 1 -> spawn burst + XP pearls -> 8-directional swim for 3.0s -> capture 02_stage1_shallow.png
	_autotest_suppress_levelup = true
	start_stage1_btn.pressed.emit()
	await get_tree().process_frame
	wave_spawner.call("spawn_wave_burst", 14, 240.0, 420.0)
	_spawn_autotest_pearls()

	var dirs := [
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0).normalized(),
		Vector2(0.0, 1.0),
		Vector2(-1.0, 1.0).normalized(),
		Vector2(-1.0, 0.0),
		Vector2(-1.0, -1.0).normalized(),
		Vector2(0.0, -1.0),
		Vector2(1.0, -1.0).normalized(),
	]
	for d in dirs:
		player.set("autotest_move_dir", d)
		await get_tree().create_timer(0.375, true).timeout
	player.set("autotest_move_dir", Vector2.ZERO)
	await _capture_screenshot("res://screenshots/02_stage1_shallow.png")
	_autotest_suppress_levelup = false

	# 4) Trigger Level Up -> wait 0.35s -> capture 03_levelup_cards.png -> select first upgrade card
	GameData.add_xp(GameData.xp_to_next)
	await get_tree().create_timer(0.35, true).timeout
	await _capture_screenshot("res://screenshots/03_levelup_cards.png")
	if not _current_upgrade_buttons.is_empty():
		_current_upgrade_buttons[0].pressed.emit()
	await get_tree().process_frame

	# 5) Start Stage 2 -> spawn burst -> walk/fight for 1.5s -> capture 04_stage2_deep.png
	_autotest_suppress_levelup = true
	start_stage2_btn.pressed.emit()
	await get_tree().process_frame
	wave_spawner.call("spawn_wave_burst", 14, 240.0, 420.0)
	var stage2_dirs := [
		Vector2(1.0, 0.3).normalized(),
		Vector2(-0.4, 1.0).normalized(),
		Vector2(-1.0, -0.3).normalized(),
		Vector2(0.4, -1.0).normalized(),
	]
	for d2 in stage2_dirs:
		player.set("autotest_move_dir", d2)
		await get_tree().create_timer(0.375, true).timeout
	player.set("autotest_move_dir", Vector2.ZERO)
	await _capture_screenshot("res://screenshots/04_stage2_deep.png")
	_autotest_suppress_levelup = false

	# 6) Trigger Stage Clear / Game Over summary -> wait 0.35s -> capture 05_gameover_summary.png
	var stage2_dur: float = float(GameData.STAGES[2]["duration"])
	GameData.time_survived = stage2_dur
	GameData.notify_stage_clear(2)
	_trigger_game_over(true)
	await get_tree().create_timer(0.35, true).timeout
	await _capture_screenshot("res://screenshots/05_gameover_summary.png")

	# 7) Print completion token and quit cleanly
	print("AUTOTEST_COMPLETED_SUCCESSFULLY")
	get_tree().quit(0)
