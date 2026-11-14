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


## Điểm cao nhất, lưu vào file để còn sau khi tắt game.
var save_path: String = "user://savegame.cfg"
var high_score: int = 0


func _ready() -> void:
	_setup_input()
	load_save()


func load_save() -> void:
	high_score = 0
	if not FileAccess.file_exists(save_path):
		return
	var cf := ConfigFile.new()
	if cf.load(save_path) == OK:
		high_score = int(cf.get_value("progress", "high_score", 0))


## Trả về true nếu phá kỷ lục (và đã lưu).
func submit_score(value: int) -> bool:
	if value <= high_score:
		return false
	high_score = value
	var cf := ConfigFile.new()
	cf.set_value("progress", "high_score", high_score)
	cf.save(save_path)
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
