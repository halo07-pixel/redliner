extends Node
## Autoload "Global": hằng số layer vật lý, BẢNG SỐ CÂN BẰNG (chỉnh tại đây), input map tạo bằng code.

# Bit collision layer (khớp [layer_names] trong project.godot)
const L_WORLD: int = 1
const L_PLAYER: int = 2
const L_ENEMY: int = 4
const L_PROJECTILE: int = 8
const L_PLAYER_HURT: int = 16
const L_ENEMY_HURT: int = 32

const TEAM_PLAYER: int = 0
const TEAM_ENEMY: int = 1

## Loại bot. reaction = độ trễ phản ứng (giây), parry/dodge = xác suất, windup = thời gian báo đòn kiếm.
const BOTS: Dictionary = {
	"swordsman": {
		"color": Color(0.85, 0.2, 0.2), "health": 60.0, "speed": 7.5, "melee": true, "range": 2.0,
		"shoots": false, "shoot_interval": 0.0, "keep_range": 0.0,
		"reaction": 0.35, "parry": 0.1, "dodge": 0.2, "windup": 0.30, "attack_cd": 1.3, "score": 100,
	},
	"gunner": {
		"color": Color(0.95, 0.55, 0.1), "health": 45.0, "speed": 5.0, "melee": false, "range": 0.0,
		"shoots": true, "shoot_interval": 2.2, "keep_range": 13.0,
		"reaction": 0.5, "parry": 0.15, "dodge": 0.4, "windup": 0.30, "attack_cd": 1.5, "score": 150,
	},
	"elite": {
		"color": Color(0.6, 0.25, 0.85), "health": 90.0, "speed": 8.5, "melee": true, "range": 2.0,
		"shoots": true, "shoot_interval": 3.5, "keep_range": 0.0,
		"reaction": 0.12, "parry": 0.5, "dodge": 0.5, "windup": 0.22, "attack_cd": 1.0, "score": 300,
	},
}

## Bảng màu theo vai trò (M6.2). Vật liệu trong `materials.gd` đọc từ đây.
const PALETTE: Dictionary = {
	"floor": Color(0.2, 0.21, 0.24),
	"wall": Color(0.32, 0.34, 0.39),
	"platform": Color(0.45, 0.46, 0.52),
	"pillar": Color(0.72, 0.12, 0.12),     # cột đỏ: nguy hiểm / mốc nhìn
	"runwall": Color(0.2, 0.45, 0.85),     # tường chạy tường: xanh
	"grapple": Color(0.95, 0.72, 0.15),    # bệ đu móc: vàng, phát sáng
	"ramp": Color(0.3, 0.6, 0.35),         # dốc trượt: xanh lá
	"trim": Color(0.25, 0.85, 1.0),        # vạch sáng chân tường
}
## Độ kim loại / nhám / cường độ phát sáng theo vai trò.
const MATERIAL_PARAMS: Dictionary = {
	"floor": {"metallic": 0.1, "roughness": 0.85, "emission": 0.0, "tile": 4.0},
	"wall": {"metallic": 0.2, "roughness": 0.75, "emission": 0.0, "tile": 4.0},
	"platform": {"metallic": 0.6, "roughness": 0.4, "emission": 0.0, "tile": 2.0},
	"pillar": {"metallic": 0.7, "roughness": 0.35, "emission": 0.0, "tile": 2.0},
	"runwall": {"metallic": 0.5, "roughness": 0.45, "emission": 0.35, "tile": 2.0},
	"grapple": {"metallic": 0.4, "roughness": 0.4, "emission": 1.6, "tile": 2.0},
	"ramp": {"metallic": 0.1, "roughness": 0.8, "emission": 0.0, "tile": 2.0},
	"trim": {"metallic": 0.0, "roughness": 0.5, "emission": 2.5, "tile": 1.0},
}

## Chất lượng đồ họa (M6.3): chỉ số 0=Thấp, 1=Vừa, 2=Cao.
const QUALITY_NAMES: Array = ["Thấp", "Vừa", "Cao"]
const QUALITY: Array = [
	{"shadows": false, "shadow_dist": 40.0, "cascades": 1, "ssao": false, "glow": false, "fog": false, "msaa": 0, "scale": 0.75},
	{"shadows": true, "shadow_dist": 60.0, "cascades": 2, "ssao": false, "glow": true, "fog": true, "msaa": 0, "scale": 1.0},
	{"shadows": true, "shadow_dist": 90.0, "cascades": 4, "ssao": true, "glow": true, "fog": true, "msaa": 2, "scale": 1.0},
]
const QUALITY_DEFAULT: int = 1

## Môi trường / ánh sáng (M6.1). Chỉnh tại đây, `arena.gd` chỉ đọc.
const ENV: Dictionary = {
	"sun_rotation_deg": Vector3(-48.0, 35.0, 0.0),
	"sun_color": Color(1.0, 0.93, 0.8),
	"sun_energy": 1.3,
	"shadow_max_distance": 90.0,
	"shadow_split_1": 0.08,
	"shadow_split_2": 0.22,
	"shadow_split_3": 0.5,
	"shadow_bias": 0.04,
	"sky_top": Color(0.22, 0.36, 0.6),
	"sky_horizon": Color(0.62, 0.7, 0.8),
	"ground_horizon": Color(0.45, 0.47, 0.5),
	"ground_bottom": Color(0.12, 0.12, 0.14),
	"ambient_energy": 0.7,
	"fog_color": Color(0.6, 0.67, 0.76),
	"fog_density": 0.004,
	"fog_sky_affect": 0.4,
	"tonemap_exposure": 1.0,
	"tonemap_white": 6.0,
	"glow_intensity": 0.6,
	"glow_bloom": 0.05,
	"glow_hdr_threshold": 1.1,
}

## Hình dáng khung xương theo loại (M7.1). shoulder/bulk = hệ số rộng vai / dày thân;
## armor 0=không, 1=vai nhỏ, 2=vai lớn+ngực; weapon: "none"/"sword"/"gun"; glow = vạch sáng (emissive).
const RIG: Dictionary = {
	"dummy": {"shoulder": 1.0, "bulk": 1.0, "armor": 0, "weapon": "none", "glow": false},
	"swordsman": {"shoulder": 1.25, "bulk": 1.1, "armor": 1, "weapon": "sword", "glow": false},
	"gunner": {"shoulder": 0.85, "bulk": 0.8, "armor": 0, "weapon": "gun", "glow": false},
	"elite": {"shoulder": 1.4, "bulk": 1.3, "armor": 2, "weapon": "sword", "glow": true},
}

## Instability / Redline (cơ chế riêng của game này). Thanh đầy dần khi chạy nhanh, đánh trúng,
## parry thành công; đầy thì vào Redline: sát thương tăng, dash hồi nhanh hơn, thanh cạn dần.
const INSTABILITY: Dictionary = {
	"max": 100.0,
	"speed_threshold": 14.0,  # m/s: chạy nhanh hơn mức này thì thanh đầy dần
	"speed_gain": 8.0,        # /giây khi đang chạy nhanh
	"idle_decay": 3.0,        # /giây khi chạy chậm
	"hit_gain": 12.0,         # đòn kiếm trúng
	"parry_gain": 20.0,       # parry thành công
	"damage_loss": 15.0,      # mất khi bị đánh
	"redline_time": 6.0,      # giây
	"damage_mult": 1.5,
	"dash_recharge_mult": 2.0,
}

## Số cân bằng chiến đấu (chỉnh tại đây).
const COMBAT: Dictionary = {
	"player_health": 100.0,
	"dummy_health": 60.0,
	# Kiếm: windup -> active (gây sát thương) -> recovery
	"sword_damage": 30.0,
	"sword_windup": 0.12,
	"sword_active": 0.10,
	"sword_recovery": 0.28,
	"sword_reach": 2.4,
	"sword_stagger_when_parried": 1.0,
	"clash_range": 3.0,
	"clash_stagger": 0.5,
	"clash_knockback": 9.0,
	# Súng của người chơi (bắn tia tức thì)
	"gun_damage": 25.0,
	"gun_cooldown": 0.35,
	"gun_mag": 6,
	"gun_reload": 1.1,
	"gun_range": 80.0,
	# Đạn của địch (vật thể bay, có thể bị parry phản lại)
	"bullet_speed": 40.0,
	"bullet_damage": 15.0,
	"bullet_life": 4.0,
	"reflect_damage_mult": 2.5,
	"reflect_speed_mult": 1.3,
	# Parry
	"parry_window": 0.18,
	"parry_miss_cooldown": 0.8,
	"parry_hit_cooldown": 0.15,
	# Khác
	"respawn_time": 2.0,
	"dummy_respawn": 3.0,
	"turret_interval": 2.5,
	"turret_range": 45.0,
}

## Số di chuyển của người chơi. Không có trần tốc độ: chỉ có "wish speed" (tốc độ đi bộ)
## và ma sát mặt đất — động lượng vượt quá wish speed được giữ nguyên trên không.
const PLAYER: Dictionary = {
	"walk_speed": 9.0,       # m/s, tốc độ đích khi đi bộ
	"ground_accel": 100.0,   # m/s² trên mặt đất (đủ lớn để đạt đúng walk_speed dù có ma sát)
	"ground_friction": 8.0,  # hệ số hãm trên mặt đất
	"stop_speed": 3.0,       # dưới ngưỡng này ma sát hãm tuyến tính, dừng dứt khoát
	"air_accel": 18.0,       # m/s² trên không (cho phép air-strafe cộng thêm tốc độ)
	"gravity": 24.0,         # m/s²
	"jump_velocity": 9.0,    # m/s, nhảy cao ~1.7m
	"mouse_sens": 0.0022,    # rad/pixel
	# --- Slide ---
	"slide_min_speed": 6.0,  # phải chạy nhanh hơn mức này mới trượt được
	"slide_boost": 4.0,      # cú đẩy khi bắt đầu trượt (m/s)
	"slide_friction": 0.2,   # ma sát rất nhỏ khi trượt (tỉ lệ theo tốc độ, 1/giây)
	"slide_end_speed": 2.5,  # chậm hơn mức này thì tự đứng dậy
	"slide_steer": 5.0,      # khả năng bẻ hướng khi trượt
	# --- Dash ---
	"dash_impulse": 18.0,    # m/s cộng thêm vào vận tốc hiện tại
	"dash_max_charges": 2,
	"dash_recharge": 1.5,    # giây hồi 1 lần dash
	"dash_cooldown": 0.25,   # giây tối thiểu giữa 2 lần dash
	# --- Wallrun ---
	"wall_ray": 1.0,         # tầm dò tường hai bên (m)
	"wall_min_speed": 5.0,   # tốc độ ngang tối thiểu để bám tường
	"wall_fall": 2.0,        # tốc độ rơi khi bám tường (m/s)
	"wall_max_time": 2.5,    # bám tối đa (giây)
	"wall_lockout": 0.4,     # sau khi rời tường, chưa được bám lại trong chừng này giây
	"wall_jump_push": 9.0,   # lực bật ra khỏi tường (m/s)
	"wall_roll_deg": 12.0,   # độ nghiêng camera
	# --- Grapple ---
	"grapple_range": 60.0,
	"grapple_pull_start": 40.0,  # m/s² lúc mới móc
	"grapple_pull_max": 130.0,   # m/s² sau khi kéo đủ lâu (lực tăng dần)
	"grapple_ramp": 0.8,         # giây để lực kéo đạt mức tối đa
	"grapple_max_speed": 45.0,   # tốc độ kéo tối đa về phía điểm móc
	"grapple_stop_dist": 2.5,    # tới gần điểm móc thì thả
	"grapple_max_time": 3.0,
	"grapple_cooldown": 0.5,
}


signal quality_changed(level: int)

## Điểm cao nhất + mức đồ họa, lưu vào file để còn sau khi tắt game.
var save_path: String = "user://savegame.cfg"
var high_score: int = 0
var quality: int = QUALITY_DEFAULT


func _ready() -> void:
	_setup_input()
	load_save()


func load_save() -> void:
	high_score = 0
	quality = QUALITY_DEFAULT
	if not FileAccess.file_exists(save_path):
		return
	var cf := ConfigFile.new()
	if cf.load(save_path) == OK:
		high_score = int(cf.get_value("progress", "high_score", 0))
		quality = clampi(int(cf.get_value("graphics", "quality", QUALITY_DEFAULT)), 0, QUALITY.size() - 1)


func _write_save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "high_score", high_score)
	cf.set_value("graphics", "quality", quality)
	cf.save(save_path)


## Đổi mức đồ họa: lưu và phát Signal để arena áp dụng (call down, signal up).
func set_quality(level: int) -> void:
	level = clampi(level, 0, QUALITY.size() - 1)
	if level == quality:
		return
	quality = level
	_write_save()
	quality_changed.emit(quality)


func cycle_quality() -> void:
	set_quality((quality + 1) % QUALITY.size())


## Trả về true nếu phá kỷ lục (và đã lưu).
func submit_score(value: int) -> bool:
	if value <= high_score:
		return false
	high_score = value
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
	_add_mouse("grapple", MOUSE_BUTTON_RIGHT)
	_add_mouse("attack", MOUSE_BUTTON_LEFT)
	_add_key("shoot", KEY_E)
	_add_key("parry", KEY_F)
	_add_key("reload", KEY_R)


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
func hurt_layer(team: int) -> int:
	return L_PLAYER_HURT if team == TEAM_PLAYER else L_ENEMY_HURT


## Hitstop: làm chậm game thật ngắn khi trúng đòn (đếm bằng thời gian thực).
var _hitstop_active: bool = false


func hitstop(duration: float, scale: float = 0.05) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false
