extends Node

const STAGES := {
	1: {
		"id": 1,
		"name": "ด่าน 1: แนวปะการังน้ำตื้น",
		"subtitle": "แสงแดดส่องถึง ฝูงสัตว์ทะเลหลากสี",
		"duration": 90.0,
		"bg_top": Color("#053b5e"),
		"bg_bottom": Color("#03192e"),
		"accent": Color("#00f5d4")
	},
	2: {
		"id": 2,
		"name": "ด่าน 2: ห้วงเหวน้ำลึก",
		"subtitle": "ความมืดเรืองแสงและจ้าวสมุทร",
		"duration": 120.0,
		"bg_top": Color("#0b0526"),
		"bg_bottom": Color("#02010a"),
		"accent": Color("#bf5af2")
	}
}

const UPGRADE_POOL := [
	{
		"id": "sonic_pulse",
		"name": "คลื่นโซนาร์",
		"desc": "เพิ่มความแรง จำนวนคลื่น และความเร็วการยิงโซนาร์",
		"color": Color("#00f5d4"),
		"max_level": 5
	},
	{
		"id": "bubble_barrage",
		"name": "ฟองอากาศจู่โจม",
		"desc": "ปลดล็อกและอัปเกรดฟองอากาศนีออนยิงกระจาย",
		"color": Color("#38bdf8"),
		"max_level": 5
	},
	{
		"id": "hydro_orbit",
		"name": "กงจักรน้ำวน",
		"desc": "ปลดล็อกและเพิ่มลูกแก้วน้ำวนหมุนรอบตัวโลมา",
		"color": Color("#f15bb5"),
		"max_level": 5
	},
	{
		"id": "bio_lightning",
		"name": "สายฟ้าชีวภาพ",
		"desc": "ปลดล็อกและอัปเกรดคลื่นไฟฟ้าช็อตศัตรูรอบตัว",
		"color": Color("#fee440"),
		"max_level": 5
	},
	{
		"id": "speed_boost",
		"name": "ครีบเพรียวลม",
		"desc": "เพิ่มความเร็วในการว่ายน้ำ +15% หลบหลีกคล่องตัว",
		"color": Color("#4cc9f0"),
		"max_level": 5
	},
	{
		"id": "max_hp",
		"name": "พลังชีวิตแห่งสมุทร",
		"desc": "เพิ่มพลังชีวิตสูงสุด +25 และฟื้นฟู 30 หน่วยทันที",
		"color": Color("#06d6a0"),
		"max_level": 5
	},
	{
		"id": "magnet_range",
		"name": "แม่เหล็กโซนาร์",
		"desc": "เพิ่มระยะดูดไข่มุก XP +45%",
		"color": Color("#bf5af2"),
		"max_level": 5
	}
]

const ACHIEVEMENTS := [
	{
		"id": "first_blood",
		"title": "นักล่ามือใหม่",
		"desc": "กำจัดสัตว์ทะเลตัวแรกได้สำเร็จ"
	},
	{
		"id": "hunter_25",
		"title": "ผู้พิทักษ์แนวปะการัง",
		"desc": "กำจัดสัตว์ทะเลครบ 25 ตัวในรอบเดียว"
	},
	{
		"id": "level_3",
		"title": "โลมาจอมพลัง",
		"desc": "พัฒนาตัวละครจนถึงเลเวล 3"
	},
	{
		"id": "arsenal_3",
		"title": "คลังแสงใต้น้ำ",
		"desc": "ครอบครองอาวุธพร้อมกัน 3 ชนิด"
	},
	{
		"id": "survive_45",
		"title": "อึดทนน่านน้ำ",
		"desc": "เอาชีวิตรอดต่อเนื่องครบ 45 วินาที"
	},
	{
		"id": "stage1_clear",
		"title": "พิชิตน้ำตื้น",
		"desc": "ผ่านด่านที่ 1 (แนวปะการังน้ำตื้น)"
	},
	{
		"id": "stage2_clear",
		"title": "จ้าวห้วงเหวลึก",
		"desc": "ผ่านด่านที่ 2 (ห้วงเหวน้ำลึก)"
	}
]

signal xp_changed(current_xp: int, max_xp: int, level: int)
signal level_up_triggered(new_level: int, choices: Array)
signal stats_changed()
signal achievement_unlocked(ach_id: String, title: String, desc: String)

var current_stage: int = 1
var score: int = 0
var kills: int = 0
var time_survived: float = 0.0
var level: int = 1
var current_xp: int = 0
var xp_to_next: int = 10
var upgrade_levels: Dictionary = {}
var unlocked_achievements: Dictionary = {}


func _ready() -> void:
	_init_upgrade_levels()


func _init_upgrade_levels() -> void:
	upgrade_levels.clear()
	for entry in UPGRADE_POOL:
		var upg_id: String = str(entry["id"])
		upgrade_levels[upg_id] = 1 if upg_id == "sonic_pulse" else 0


func _calc_xp_requirement(target_level: int) -> int:
	return 10 + (target_level - 1) * 8 + int(floor(float(target_level * target_level) * 0.8))


func reset_run(stage_id: int = 1) -> void:
	current_stage = stage_id if STAGES.has(stage_id) else 1
	score = 0
	kills = 0
	time_survived = 0.0
	level = 1
	current_xp = 0
	xp_to_next = 10
	_init_upgrade_levels()
	xp_changed.emit(current_xp, xp_to_next, level)
	stats_changed.emit()


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	current_xp += amount
	var leveled_up: bool = false
	while current_xp >= xp_to_next:
		current_xp -= xp_to_next
		level += 1
		xp_to_next = _calc_xp_requirement(level)
		leveled_up = true
	xp_changed.emit(current_xp, xp_to_next, level)
	if leveled_up:
		stats_changed.emit()
		check_progress_achievements()
		var choices: Array = get_random_upgrades(3)
		if not choices.is_empty():
			level_up_triggered.emit(level, choices)


func register_kill(points: int = 10) -> void:
	kills += 1
	score += maxi(0, points)
	stats_changed.emit()
	check_progress_achievements()


func get_random_upgrades(count: int = 3) -> Array:
	var available: Array = []
	for entry in UPGRADE_POOL:
		var upg_id: String = str(entry["id"])
		var max_lvl: int = int(entry["max_level"])
		var cur_lvl: int = int(upgrade_levels.get(upg_id, 0))
		if cur_lvl < max_lvl:
			available.append(entry.duplicate(true))
	if available.is_empty():
		for entry in UPGRADE_POOL:
			available.append(entry.duplicate(true))
	available.shuffle()
	if available.size() > count:
		return available.slice(0, count)
	return available


func record_upgrade(upgrade_id: String) -> void:
	var cur_lvl: int = int(upgrade_levels.get(upgrade_id, 0))
	upgrade_levels[upgrade_id] = cur_lvl + 1
	stats_changed.emit()
	check_progress_achievements()


func unlock_achievement(ach_id: String) -> void:
	if bool(unlocked_achievements.get(ach_id, false)):
		return
	for entry in ACHIEVEMENTS:
		if str(entry["id"]) == ach_id:
			unlocked_achievements[ach_id] = true
			achievement_unlocked.emit(ach_id, str(entry["title"]), str(entry["desc"]))
			stats_changed.emit()
			return


func check_progress_achievements() -> void:
	if kills >= 1:
		unlock_achievement("first_blood")
	if kills >= 25:
		unlock_achievement("hunter_25")
	if level >= 3:
		unlock_achievement("level_3")
	if time_survived >= 45.0:
		unlock_achievement("survive_45")
	var active_weapons: int = 0
	for wid in ["sonic_pulse", "bubble_barrage", "hydro_orbit", "bio_lightning"]:
		if int(upgrade_levels.get(wid, 0)) > 0:
			active_weapons += 1
	if active_weapons >= 3:
		unlock_achievement("arsenal_3")


func notify_stage_clear(stage_id: int) -> void:
	if stage_id == 1:
		unlock_achievement("stage1_clear")
	elif stage_id == 2:
		unlock_achievement("stage2_clear")


func get_unlocked_count() -> int:
	return unlocked_achievements.size()


func get_total_achievements() -> int:
	return ACHIEVEMENTS.size()
