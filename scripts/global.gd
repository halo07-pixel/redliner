extends Node
## Autoload "Global": hằng số layer vật lý, BẢNG SỐ CÂN BẰNG (chỉnh tại đây), input map tạo bằng code.

const CombatData = preload("res://scripts/data/combat_data.gd")
const BotData = preload("res://scripts/data/bot_data.gd")
const VisualData = preload("res://scripts/data/visual_data.gd")
const ModeData = preload("res://scripts/data/mode_data.gd")
const AudioData = preload("res://scripts/data/audio_data.gd")
const PlayerData = preload("res://scripts/data/player_data.gd")

# Bit collision layer (khớp [layer_names] trong project.godot)
const L_WORLD: int = 1
const L_PLAYER: int = 2
const L_ENEMY: int = 4
const L_PROJECTILE: int = 8
const L_PLAYER_HURT: int = 16
const L_ENEMY_HURT: int = 32
const L_TITAN: int = 64 # bề mặt Titan để móc grapple (Area, chỉ dùng cho tia grapple)

const TEAM_PLAYER: int = 0
const TEAM_ENEMY: int = 1

const BOT_ORDER: Array = BotData.BOT_ORDER
const BOT_NAMES: Dictionary = BotData.BOT_NAMES
const BOTS: Dictionary = BotData.BOTS
var MOTION: Dictionary = PlayerData.MOTION.duplicate(true)   # bản chỉnh sống được
const MOTION_PRESETS: Dictionary = PlayerData.MOTION_PRESETS
func apply_motion_preset(preset: String) -> bool:
	if not MOTION_PRESETS.has(preset):
		return false
	for id in MOTION_PRESETS[preset]:
		var parts: PackedStringArray = (id as String).split(".")
		set_live(parts[0], parts[1], float(MOTION_PRESETS[preset][id]))
	return true


var TITAN: Dictionary = PlayerData.TITAN.duplicate(true)   # bản chỉnh sống được
var BOT_MOVE: Dictionary = PlayerData.BOT_MOVE.duplicate(true)   # bản chỉnh sống được
const BOMB: Dictionary = BotData.BOMB
const DIFFICULTY_LEVELS: Array = BotData.DIFFICULTY_LEVELS
const DIFFICULTY_NAMES: Dictionary = BotData.DIFFICULTY_NAMES
const DIFFICULTY: Dictionary = BotData.DIFFICULTY
const PALETTE: Dictionary = VisualData.PALETTE
const LOWPOLY: Dictionary = VisualData.LOWPOLY
const MATERIAL_PARAMS: Dictionary = VisualData.MATERIAL_PARAMS
const QUALITY_NAMES: Array = VisualData.QUALITY_NAMES
const QUALITY: Array = VisualData.QUALITY
const QUALITY_DEFAULT: int = VisualData.QUALITY_DEFAULT
const ENV: Dictionary = VisualData.ENV
const RIG: Dictionary = VisualData.RIG
const SKIN_COLOR: Color = VisualData.SKIN_COLOR
const ANIM: Dictionary = VisualData.ANIM
const VIEWMODEL: Dictionary = VisualData.VIEWMODEL
const INSTABILITY: Dictionary = CombatData.INSTABILITY
const COMBAT: Dictionary = CombatData.COMBAT
const WEAPON_ORDER: Array = CombatData.WEAPON_ORDER
const WEAPONS: Dictionary = CombatData.WEAPONS
const FLAWS: Dictionary = CombatData.FLAWS
const PERKS: Dictionary = CombatData.PERKS
const GOLD: Dictionary = CombatData.GOLD
const HEAVY_SLASH: Dictionary = CombatData.HEAVY_SLASH
const FX: Dictionary = CombatData.FX
const PICKUPS: Dictionary = CombatData.PICKUPS
const BREAKABLES: Dictionary = CombatData.BREAKABLES
var PLAYER: Dictionary = PlayerData.PLAYER.duplicate(true)   # bản chỉnh sống được
signal quality_changed(level: int)
signal fx_changed(reduced: bool)
signal difficulty_changed(level: String)
signal mode_changed(mode: String)
signal settings_changed
signal bindings_changed

## Cài đặt người chơi (lưu savegame mục "settings"). mouse_mult nhân với PLAYER.mouse_sens.
const DEFAULT_SETTINGS: Dictionary = {
	"mouse_mult": 1.0, "invert_y": false, "fov": 90.0, "bob": 1.0, "cam_fx": 1.0,
	"pad_sens": 1.0, "pad_deadzone": 0.2,
	"vol_master": 1.0, "vol_sfx": 1.0, "vol_music": 0.7,
}
const SOUNDS: Dictionary = AudioData.SOUNDS
const AUDIO_BUSES: Array = AudioData.AUDIO_BUSES
const AUDIO: Dictionary = AudioData.AUDIO
## Chất liệu sàn theo vai trò (bước chân).
## Tên âm bước chân theo chất liệu sàn ("stone" mặc định).
static func step_sound(surface: String) -> String:
	match surface:
		"metal":
			return "step_metal"
		"wood":
			return "step_wood"
	return "step"


const SURFACES: Dictionary = AudioData.SURFACES
## Các hành động đổi phím được: [action, tên hiển thị].
const REMAPPABLE: Array = [
	["move_forward", "Tiến"], ["move_back", "Lùi"], ["move_left", "Trái"], ["move_right", "Phải"],
	["jump", "Nhảy"], ["slide", "Trượt"], ["dash", "Dash"], ["slam", "Đập đất"],
	["attack", "Chém"], ["heavy", "Chém rộng"], ["shoot", "Bắn"], ["parry", "Parry"],
	["grapple", "Móc"], ["reload", "Nạp đạn"], ["zoom", "Ngắm"], ["spawn_titan", "Gọi/xoá Titan (Tập luyện)"],
	["weapon_1", "Súng 1"], ["weapon_2", "Súng 2"], ["weapon_3", "Súng 3"], ["weapon_4", "Súng 4"],
]

const MODES: Array = ModeData.MODES
const MODE_NAMES: Dictionary = ModeData.MODE_NAMES
const MODE_DESCRIPTIONS: Dictionary = ModeData.MODE_DESCRIPTIONS
const XP: Dictionary = ModeData.XP
const UPGRADES: Dictionary = ModeData.UPGRADES
const ENDLESS: Dictionary = ModeData.ENDLESS
const TRAINING: Dictionary = ModeData.TRAINING
const VERSION: String = "1.0.0"
## Điểm cao nhất + mức đồ họa, lưu vào file để còn sau khi tắt game.
var save_path: String = "user://savegame.cfg"
var quality: int = QUALITY_DEFAULT
var reduced_fx: bool = false
## Bật để lớp phủ F3 hiện pha/clip hoạt ảnh viewmodel (gỡ lỗi hoạt ảnh).
var anim_debug: bool = false
var anim_debug_samples: PackedFloat32Array = PackedFloat32Array()   # đường cong kiếm (độ lệch vị trí, góc) cho bộ chỉnh hoạt ảnh
## Giá trị chỉnh lúc chơi ghi đè hằng số hoạt ảnh (khoá "v.<tên>" cho VIEWMODEL, "a.<tên>" cho ANIM). Xem anim_tuner.gd.
var tune: Dictionary = {}
var anim_debug_text: String = ""   # viewmodel ghi mỗi frame khi anim_debug bật
var difficulty: String = "normal"
var game_mode: String = "endless"
signal gold_changed(total: int)
signal start_gun_changed(id: String)
var gold: int = 0                           # vàng lưu lâu dài (M37)
var owned_guns: Array = ["pistol"]          # súng đã mở khoá
var start_gun: String = "pistol"            # súng cầm khi bắt đầu lượt Vô Tận
var _mode_scores: Dictionary = {} # "<chế_độ>_<mức>" -> điểm 
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var _default_bindings: Dictionary = {}


func _ready() -> void:
	_setup_input()
	load_save()
	_snapshot_live()
	load_live()


## Giá trị trong file save có thể bị sửa/hỏng: chỉ nhận số/chuỗi/bool, còn lại về mặc định.
static func _num(v: Variant, fallback: float) -> float:
	if v is int or v is float:
		var f: float = float(v)
		return f if is_finite(f) else fallback
	if v is String and (v as String).is_valid_float():
		return (v as String).to_float()
	return fallback


static func _flag(v: Variant, fallback: bool) -> bool:
	return bool(v) if v is bool or v is int else fallback


func load_save() -> void:
	quality = QUALITY_DEFAULT
	reduced_fx = false
	difficulty = "normal"
	game_mode = "endless"
	_mode_scores = {}
	gold = 0
	owned_guns = ["pistol"]
	start_gun = "pistol"
	settings = DEFAULT_SETTINGS.duplicate()
	if not FileAccess.file_exists(save_path):
		return
	var cf := ConfigFile.new()
	if cf.load(save_path) == OK:
		for md in MODES:
			for lv in DIFFICULTY_LEVELS:
				_mode_scores[md + "_" + lv] = maxi(int(_num(cf.get_value("progress", "high_score_%s_%s" % [md, lv], 0), 0.0)), 0)
		gold = maxi(int(_num(cf.get_value("meta", "gold", 0), 0.0)), 0)
		for g in str(cf.get_value("meta", "owned_guns", "pistol")).split(","):
			if g in WEAPON_ORDER and not owned_guns.has(g):
				owned_guns.append(g)
		var sg: String = str(cf.get_value("meta", "start_gun", "pistol"))
		start_gun = sg if owned_guns.has(sg) else "pistol"
		var gm: String = str(cf.get_value("game", "mode", "endless"))
		game_mode = gm if gm in MODES else "endless"   # savegame cũ ghi survival/timed -> Vô Tận
		var dl: String = str(cf.get_value("game", "difficulty", "normal"))
		difficulty = dl if dl in DIFFICULTY_LEVELS else "normal"
		quality = clampi(int(_num(cf.get_value("graphics", "quality", QUALITY_DEFAULT), QUALITY_DEFAULT)), 0, QUALITY.size() - 1)
		reduced_fx = _flag(cf.get_value("graphics", "reduced_fx", false), false)
		for k in DEFAULT_SETTINGS:
			var v: Variant = cf.get_value("settings", k, DEFAULT_SETTINGS[k])
			settings[k] = _flag(v, DEFAULT_SETTINGS[k]) if DEFAULT_SETTINGS[k] is bool else _num(v, float(DEFAULT_SETTINGS[k]))
		_clamp_settings()
		if cf.has_section("bindings"):
			for action in cf.get_section_keys("bindings"):
				_apply_binding_data(action, cf.get_value("bindings", action))


func _write_save() -> void:
	var cf := ConfigFile.new()
	for k in _mode_scores:
		cf.set_value("progress", "high_score_" + k, int(_mode_scores[k]))
	cf.set_value("meta", "gold", gold)
	cf.set_value("meta", "owned_guns", ",".join(owned_guns))
	cf.set_value("meta", "start_gun", start_gun)
	cf.set_value("game", "mode", game_mode)
	cf.set_value("game", "difficulty", difficulty)
	cf.set_value("graphics", "quality", quality)
	cf.set_value("graphics", "reduced_fx", reduced_fx)
	for k in settings:
		cf.set_value("settings", k, settings[k])
	for r in REMAPPABLE:
		cf.set_value("bindings", r[0], _binding_data(r[0]))
	cf.save(save_path)


## Đổi mức đồ họa: lưu và phát Signal để arena áp dụng (call down, signal up).
func set_quality(level: int) -> void:
	level = clampi(level, 0, QUALITY.size() - 1)
	if level == quality:
		return
	quality = level
	_write_save()
	quality_changed.emit(quality)


## Đổi một cài đặt (kẹp trong khoảng hợp lệ, lưu file, phát Signal).
func set_setting(key: String, value: Variant) -> void:
	if not settings.has(key):
		return
	settings[key] = bool(value) if DEFAULT_SETTINGS[key] is bool else float(value)
	_clamp_settings()
	_write_save()
	settings_changed.emit()


func reset_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	_write_save()
	settings_changed.emit()


func _clamp_settings() -> void:
	settings["mouse_mult"] = clampf(float(settings["mouse_mult"]), 0.2, 3.0)
	settings["fov"] = clampf(float(settings["fov"]), 70.0, 110.0)
	settings["bob"] = clampf(float(settings["bob"]), 0.0, 1.0)
	settings["cam_fx"] = clampf(float(settings["cam_fx"]), 0.0, 1.5)
	settings["pad_sens"] = clampf(float(settings["pad_sens"]), 0.3, 3.0)
	settings["pad_deadzone"] = clampf(float(settings["pad_deadzone"]), 0.05, 0.5)
	for k in ["vol_master", "vol_sfx", "vol_music"]:
		settings[k] = clampf(float(settings[k]), 0.0, 1.0)
	_apply_deadzone()


func _apply_deadzone() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "look_up", "look_down", "look_left", "look_right"]:
		if InputMap.has_action(a):
			InputMap.action_set_deadzone(a, float(settings["pad_deadzone"]))


# --- Đổi phím -------------------------------------------------------------

## Dạng lưu được của một sự kiện bàn phím/chuột: ["k", keycode] hoặc ["m", nút]; [] nếu không hợp lệ.
func _event_data(ev: InputEvent) -> Array:
	if ev is InputEventKey:
		return ["k", int((ev as InputEventKey).physical_keycode)]
	if ev is InputEventMouseButton:
		return ["m", int((ev as InputEventMouseButton).button_index)]
	return []


func _data_event(d: Array) -> InputEvent:
	if d.size() != 2:
		return null
	if d[0] == "k":
		var ev := InputEventKey.new()
		ev.physical_keycode = int(d[1]) as Key
		return ev
	if d[0] == "m":
		var ev := InputEventMouseButton.new()
		ev.button_index = int(d[1]) as MouseButton
		return ev
	return null


## Các phím/chuột (không tính tay cầm) đang gán cho action, dạng dữ liệu.
func _binding_data(action: String) -> Array:
	var out: Array = []
	for ev in InputMap.action_get_events(action):
		var d := _event_data(ev)
		if not d.is_empty():
			out.append(d)
	return out


func _apply_binding_data(action: String, data: Variant) -> void:
	if not InputMap.has_action(action) or not (data is Array):
		return
	var events: Array = []
	for d in data:
		var ev := _data_event(d)
		if ev != null:
			events.append(ev)
	if events.is_empty():
		return
	for old in InputMap.action_get_events(action):
		if not _event_data(old).is_empty():
			InputMap.action_erase_event(action, old)
	for ev in events:
		InputMap.action_add_event(action, ev)


## Chuỗi hiển thị phím/chuột của action ("W / Mũi tên lên").
func binding_text(action: String) -> String:
	var parts: Array = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			parts.append((ev as InputEventKey).as_text_physical_keycode())
		elif ev is InputEventMouseButton:
			var names := {1: "Chuột trái", 2: "Chuột phải", 3: "Chuột giữa", 4: "Lăn lên", 5: "Lăn xuống"}
			parts.append(names.get((ev as InputEventMouseButton).button_index, "Chuột %d" % (ev as InputEventMouseButton).button_index))
	return " / ".join(parts) if not parts.is_empty() else "(chưa gán)"


## Action khác đang dùng sự kiện này, "" nếu không trùng.
func binding_conflict(action: String, ev: InputEvent) -> String:
	var d := _event_data(ev)
	if d.is_empty():
		return ""
	for r in REMAPPABLE:
		if r[0] == action:
			continue
		if d in _binding_data(r[0]):
			return r[0]
	return ""


## Gán phím/chuột mới thay cho phím chính (cái đầu tiên) của action; tay cầm giữ nguyên.
## Trả về false nếu bị trùng với action khác hoặc sự kiện không hợp lệ.
func rebind(action: String, ev: InputEvent) -> bool:
	if _event_data(ev).is_empty() or binding_conflict(action, ev) != "":
		return false
	var current: Array = _binding_data(action)
	if _event_data(ev) in current:
		return true
	var new_data: Array = [_event_data(ev)]
	if current.size() > 1:
		new_data.append_array(current.slice(1))
	_apply_binding_data(action, new_data)
	_write_save()
	bindings_changed.emit()
	return true


func reset_bindings() -> void:
	for action in _default_bindings:
		_apply_binding_data(action, _default_bindings[action])
	_write_save()
	bindings_changed.emit()


## Chọn mức độ khó (kỷ lục Vô Tận lưu riêng từng mức). Đổi giữa trận không ảnh hưởng bot đã sinh.
func set_difficulty(level: String) -> void:
	if level not in DIFFICULTY_LEVELS or level == difficulty:
		return
	difficulty = level
	_write_save()
	difficulty_changed.emit(level)


func cycle_difficulty() -> void:
	set_difficulty(DIFFICULTY_LEVELS[(DIFFICULTY_LEVELS.find(difficulty) + 1) % DIFFICULTY_LEVELS.size()])


## Chỉ số bot ở wave n và mức `level`: {health, speed, reaction, parry, dodge, score_mult}.
## Hàm thuần (không đụng trạng thái) để test được. Đơn điệu theo wave và có trần.
func bot_stats(type_name: String, wave: int, level: String = "") -> Dictionary:
	var c: Dictionary = BOTS[type_name]
	var D: Dictionary = DIFFICULTY
	var lv: Dictionary = D["levels"][level if level in DIFFICULTY_LEVELS else difficulty]
	var w: float = float(maxi(wave - 1, 0))
	var cap: float = float(D["chance_hard_cap"])
	return {
		"health": float(c["health"]) * minf(1.0 + float(D["health_per_wave"]) * w, float(D["health_max_mult"])) * float(lv["health"]),
		"speed": float(c["speed"]) * minf(1.0 + float(D["speed_per_wave"]) * w, float(D["speed_max_mult"])) * float(lv["speed"]),
		"reaction": float(c["reaction"]) * maxf(1.0 - float(D["reaction_per_wave"]) * w, float(D["reaction_min_mult"])) * float(lv["reaction"]),
		"parry": minf(minf(float(c["parry"]) + float(D["parry_per_wave"]) * w, float(D["parry_max"])) * float(lv["parry"]), cap),
		"dodge": minf(minf(float(c["dodge"]) + float(D["dodge_per_wave"]) * w, float(D["dodge_max"])) * float(lv["dodge"]), cap),
		"score_mult": float(lv["score"]),
	}


## Công tắc giảm hiệu ứng (lưu file, phát Signal).
func set_reduced_fx(on: bool) -> void:
	if on == reduced_fx:
		return
	reduced_fx = on
	_write_save()
	fx_changed.emit(on)


func cycle_quality() -> void:
	set_quality((quality + 1) % QUALITY.size())


## Chọn chế độ chơi cho lần chơi sau (lưu file, phát Signal).
func set_mode(mode: String) -> void:
	if mode not in MODES or mode == game_mode:
		return
	game_mode = mode
	_write_save()
	mode_changed.emit(mode)


## Vàng thưởng khi qua tầng t.
static func gold_for_floor(t: int) -> int:
	return int(GOLD["floor_base"]) + int(GOLD["floor_per_floor"]) * maxi(t, 1)


## Cộng (hoặc trừ) vàng và lưu ngay. Không để âm.
func add_gold(n: int) -> void:
	if n == 0:
		return
	gold = maxi(gold + n, 0)
	_write_save()
	gold_changed.emit(gold)


func owns_gun(id: String) -> bool:
	return owned_guns.has(id)


## Mua súng: đủ vàng và chưa có thì trừ vàng, mở khoá, lưu. true nếu mua được.
func buy_gun(id: String) -> bool:
	var price: int = int(GOLD["prices"].get(id, -1))
	if price < 0 or owns_gun(id) or gold < price:
		return false
	gold -= price
	owned_guns.append(id)
	_write_save()
	gold_changed.emit(gold)
	return true


## Chọn súng khởi đầu (phải đã sở hữu).
func set_start_gun(id: String) -> bool:
	if not owns_gun(id):
		return false
	start_gun = id
	_write_save()
	start_gun_changed.emit(id)
	return true


## Xoay vòng súng khởi đầu qua các súng đã sở hữu (theo WEAPON_ORDER).
func cycle_start_gun() -> void:
	var list: Array = WEAPON_ORDER.filter(func(g): return owns_gun(g))
	set_start_gun(list[(list.find(start_gun) + 1) % list.size()])


func cycle_mode() -> void:
	set_mode(MODES[(MODES.find(game_mode) + 1) % MODES.size()])


## Kỷ lục của một chế độ + mức độ khó (mặc định: đang chọn). Tập luyện không có kỷ lục.
func best_score(mode: String = "", level: String = "") -> int:
	var m: String = mode if mode in MODES else game_mode
	var lv: String = level if level in DIFFICULTY_LEVELS else difficulty
	if m == "training":
		return 0
	return int(_mode_scores.get(m + "_" + lv, 0))


## Nộp điểm cho chế độ (mặc định: đang chọn) ở mức độ khó hiện tại. true nếu phá kỷ lục.
func submit_mode_score(value: int, mode: String = "") -> bool:
	var m: String = mode if mode in MODES else game_mode
	if m == "training":
		return false
	var key: String = m + "_" + difficulty
	if value <= int(_mode_scores.get(key, 0)):
		return false
	_mode_scores[key] = value
	_write_save()
	return true


func _setup_input() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_forward", KEY_UP)
	_add_key("move_back", KEY_S)
	_add_key("move_back", KEY_DOWN)
	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT)
	_add_key("jump", KEY_SPACE)
	_add_key("slide", KEY_CTRL)
	_add_key("dash", KEY_SHIFT)
	_add_key("slam", KEY_C)
	_add_key("heavy", KEY_Q)
	_add_key("zoom", KEY_Z)
	_add_key("spawn_titan", KEY_T)
	_add_key("weapon_1", KEY_1)
	_add_key("weapon_2", KEY_2)
	_add_key("weapon_3", KEY_3)
	_add_key("weapon_4", KEY_4)
	_add_mouse("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
	_add_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_UP)
	_add_mouse("grapple", MOUSE_BUTTON_RIGHT)
	_add_mouse("attack", MOUSE_BUTTON_LEFT)
	_add_key("shoot", KEY_E)
	_add_key("parry", KEY_F)
	_add_key("reload", KEY_R)
	_setup_gamepad()
	for r in REMAPPABLE:
		_default_bindings[r[0]] = _binding_data(r[0])
	_apply_deadzone()


## Tay cầm (kiểu Xbox): cần trái di chuyển, cần phải nhìn, nút/trigger cho hành động.
func _setup_gamepad() -> void:
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_axis("attack", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_axis("grapple", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_pad("jump", JOY_BUTTON_A)
	_add_pad("slide", JOY_BUTTON_B)
	_add_pad("dash", JOY_BUTTON_X)
	_add_pad("heavy", JOY_BUTTON_Y)
	_add_pad("shoot", JOY_BUTTON_RIGHT_SHOULDER)
	_add_pad("parry", JOY_BUTTON_LEFT_SHOULDER)
	_add_pad("slam", JOY_BUTTON_LEFT_STICK)
	_add_pad("zoom", JOY_BUTTON_RIGHT_STICK)
	_add_pad("reload", JOY_BUTTON_DPAD_LEFT)
	_add_pad("weapon_next", JOY_BUTTON_DPAD_UP)
	_add_pad("weapon_prev", JOY_BUTTON_DPAD_DOWN)
	_add_pad("ui_cancel", JOY_BUTTON_START)


func _add_axis(action: String, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _add_pad(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


## Layer hurtbox của một phe.
## ---- Chỉnh lúc chơi (M25): grapple (p), di chuyển bot (b), Titan (t). Sửa thẳng các dict PLAYER/BOT_MOVE/TITAN.
const LIVE_GROUPS: Dictionary = {"p": "PLAYER", "b": "BOT_MOVE", "t": "TITAN", "m": "MOTION"}
const LIVE_PATH: String = "user://tuning.cfg"
const TUNABLE_LIVE: Dictionary = {
	"m": ["cam_roll_time", "cam_fov_time", "cam_head_time", "accel_lean"],
	"p": ["ground_accel", "ground_friction", "stop_speed", "grapple_redirect_time", "grapple_tilt_deg", "grapple_range", "grapple_pull_start", "grapple_pull_max", "grapple_ramp", "grapple_max_speed", "grapple_stop_dist", "grapple_max_time", "grapple_assist_deg", "grapple_swing", "grapple_release_snap"],
	"b": ["accel", "decel", "turn_rate", "turn_rate_attack", "lookahead", "vault_max", "cover_chance", "cover_radius", "far_dist"],
	"t": ["health_mult", "windup_mult", "body_mult", "nape_mult", "knee_mult", "knee_threshold", "kneel_time", "stomp_windup", "stomp_damage", "stomp_radius", "swipe_windup", "swipe_damage", "swipe_reach", "parry_stagger"],
}
const TITAN_PRESETS: Dictionary = {
	"easy": {"health_mult": 0.7, "windup_mult": 1.3},
	"normal": {"health_mult": 1.0, "windup_mult": 1.0},
	"hard": {"health_mult": 1.4, "windup_mult": 0.8},
}
var _live_defaults: Dictionary = {}   # "g.key" -> giá trị gốc


func _snapshot_live() -> void:
	_live_defaults.clear()
	for g in LIVE_GROUPS:
		var d: Dictionary = live_dict(g)
		for k in TUNABLE_LIVE[g]:
			_live_defaults["%s.%s" % [g, k]] = float(d[k])


func live_dict(group: String) -> Dictionary:
	return get(LIVE_GROUPS[group])


func live_default(group: String, key: String) -> float:
	return float(_live_defaults["%s.%s" % [group, key]])


## Đổi một giá trị chỉnh được. Trả về false nếu khoá không nằm trong danh sách cho phép.
func set_live(group: String, key: String, v: float) -> bool:
	if not TUNABLE_LIVE.has(group) or not (key in TUNABLE_LIVE[group]) or not is_finite(v):
		return false
	live_dict(group)[key] = v
	return true


func live_changed() -> Dictionary:
	var out: Dictionary = {}
	for id in _live_defaults:
		var parts: PackedStringArray = (id as String).split(".")
		var cur: float = float(live_dict(parts[0])[parts[1]])
		if not is_equal_approx(cur, float(_live_defaults[id])):
			out[id] = cur
	return out


func reset_live() -> void:
	for id in _live_defaults:
		var parts: PackedStringArray = (id as String).split(".")
		live_dict(parts[0])[parts[1]] = _live_defaults[id]


func apply_titan_preset(preset: String) -> bool:
	if not TITAN_PRESETS.has(preset):
		return false
	for k in TITAN_PRESETS[preset]:
		TITAN[k] = float(TITAN_PRESETS[preset][k])
	return true


## Lưu các giá trị đã đổi vào user://tuning.cfg (chỉ lưu phần khác mặc định). Trả về số giá trị đã lưu.
func save_live() -> int:
	var ch: Dictionary = live_changed()
	var cf := ConfigFile.new()
	for id in ch:
		var parts: PackedStringArray = (id as String).split(".")
		cf.set_value(parts[0], parts[1], ch[id])
	if ch.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LIVE_PATH))
	else:
		cf.save(LIVE_PATH)
	return ch.size()


## Nạp tuning đã lưu (nếu có). Chỉ nhận khoá cho phép và giá trị số hợp lệ; file hỏng thì bỏ qua.
func load_live() -> int:
	var cf := ConfigFile.new()
	if cf.load(LIVE_PATH) != OK:
		return 0
	var n: int = 0
	for g in TUNABLE_LIVE:
		if not cf.has_section(g):
			continue
		for k in cf.get_section_keys(g):
			var v: Variant = cf.get_value(g, k)
			if (v is int or v is float) and set_live(g, k, float(v)):
				n += 1
	return n


## Giá trị hoạt ảnh có thể chỉnh lúc chơi: ưu tiên `tune`, rồi tới hằng số.
func tv(key: String) -> Variant:
	if tune.is_empty():
		return VIEWMODEL[key]
	return tune.get("v." + key, VIEWMODEL[key])


func ta(key: String) -> Variant:
	if tune.is_empty():
		return ANIM[key]
	return tune.get("a." + key, ANIM[key])


## Các khoá hoạt ảnh cho phép chỉnh trong bộ chỉnh (anim_tuner.gd).
const TUNABLE_VM: Array = ["spring_k", "spring_c", "rot_spring_k", "rot_spring_c", "sway_impulse", "state_fade", "step_impulse", "step_roll", "kick_zeta", "draw_k", "reload_k", "swing_windup_k", "swing_active_k", "swing_follow_k", "swing_recover_k", "guard_k", "guard_hold_k", "parry_fail_k", "clash_impulse", "land_impulse", "flinch_impulse", "kick_back", "kick_pitch", "grip_curl_deg", "ledge_impulse", "land_fall_gain"]
const TUNABLE_ANIM: Array = ["ac_enabled", "ac_idle", "ac_run", "ac_cover", "ac_hips", "ac_spine", "ac_head", "ac_arm", "ac_hips_y", "ac_walk_speed", "ac_jog_speed", "ac_sprint_speed", "ac_fade", "ac_xfade", "bm_back_swing", "bm_back_lean", "bm_side_hip", "bm_side_cross", "bm_turn_lead", "bm_turn_max", "bm_cover_drop", "bm_peek", "bm_stride_blend", "pf_hitstop", "pf_hitstop_bullet", "pf_cam_kick", "pf_fov_punch", "pf_spark_cone", "pf_flash_energy", "pf_tell_lean", "pf_tell_time", "pf_miss_stumble", "cam_lunge", "cam_dip_per_speed", "cam_dip_max", "cam_fx_k", "cam_fx_c", "slide_tilt_deg", "look_max_yaw", "look_max_pitch", "look_rate", "support_hand", "joint_k", "joint_c", "overlay_in", "overlay_out"]


func hurt_layer(team: int) -> int:
	return L_PLAYER_HURT if team == TEAM_PLAYER else L_ENEMY_HURT


## Hitstop: làm chậm game thật ngắn khi trúng đòn (đếm bằng thời gian thực).
var _hitstop_active: bool = false


## Thời gian khựng (s) cho parry thành công theo loại đòn ("bullet"/"melee"), đã tính giảm hiệu ứng. Chỉ phản hồi, không đổi COMBAT.
func parry_hitstop_time(kind: String) -> float:
	var t: float = float(ta("pf_hitstop_bullet")) if kind == "bullet" else float(ta("pf_hitstop"))
	return t * (float(ANIM["pf_reduced_hitstop"]) if reduced_fx else 1.0)


func hitstop(duration: float, scale: float = 0.05) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false
