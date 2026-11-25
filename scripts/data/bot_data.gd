extends RefCounted
## Bot, bom, độ khó (dữ liệu thuần). Titan / BOT_MOVE nằm ở player_data vì chỉnh sống được.
## Chỉ là dữ liệu: `Global` nạp lại các hằng này nên mã khác vẫn dùng `Global.TÊN`. Không tham chiếu Global ở đây.

## Loại bot. reaction = độ trễ phản ứng (giây), parry/dodge = xác suất, windup = thời gian báo đòn kiếm.
## Thứ tự và tên hiển thị các loại bot (HUD / tổng kết).
const BOT_ORDER: Array = ["swordsman", "rusher", "gunner", "bomber", "elite", "titan"]

const BOT_NAMES: Dictionary = {"swordsman": "Lính kiếm", "rusher": "Lao nhanh", "gunner": "Xạ thủ", "bomber": "Pháo thủ", "elite": "Tinh nhuệ", "titan": "Titan"}

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
	"rusher": {
		"color": Color(0.95, 0.85, 0.2), "health": 35.0, "speed": 11.5, "melee": true, "range": 1.8,
		"shoots": false, "shoot_interval": 0.0, "keep_range": 0.0, "flank": true,
		"reaction": 0.3, "parry": 0.05, "dodge": 0.35, "windup": 0.18, "attack_cd": 0.8, "score": 120,
	},
	"bomber": {
		"color": Color(0.2, 0.75, 0.85), "health": 50.0, "speed": 4.5, "melee": false, "range": 0.0,
		"shoots": false, "shoot_interval": 0.0, "keep_range": 16.0, "bombs": true,
		"reaction": 0.5, "parry": 0.0, "dodge": 0.2, "windup": 0.3, "attack_cd": 1.5, "score": 200,
	},
	"titan": {
		"color": Color(0.72, 0.5, 0.4), "health": 600.0, "speed": 4.0, "melee": false, "range": 0.0,
		"shoots": false, "shoot_interval": 0.0, "keep_range": 0.0,
		"reaction": 1.0, "parry": 0.0, "dodge": 0.0, "windup": 1.2, "attack_cd": 3.0, "score": 1000,
	},
	"elite": {
		"color": Color(0.6, 0.25, 0.85), "health": 90.0, "speed": 8.5, "melee": true, "range": 2.0,
		"shoots": true, "shoot_interval": 3.5, "keep_range": 0.0,
		"reaction": 0.12, "parry": 0.5, "dodge": 0.5, "windup": 0.22, "attack_cd": 1.0, "score": 300,
	},
}

## Đạn nổ vòng cung của pháo thủ (dùng Rocket; bay tới người chơi, không hại phe bot).
const BOMB: Dictionary = {
	"interval": 3.2, "min_range": 7.0, "max_range": 40.0,
	"projectile_speed": 18.0, "gravity": 9.0, "life": 5.0,
	"damage": 25.0, "blast_radius": 3.2, "min_falloff": 0.4, "knockback": 9.0,
	"self_damage_mult": 0.0, "stagger": 0.4,
}

## Độ khó (M14). Chỉ số bot = chỉ số gốc (BOTS) x đường cong theo wave x hệ số mức chọn.
## Mỗi wave: máu/tốc độ tăng, phản ứng nhanh hơn, parry/né nhiều hơn (đều có trần).
const DIFFICULTY_LEVELS: Array = ["easy", "normal", "hard"]

const DIFFICULTY_NAMES: Dictionary = {"easy": "Dễ", "normal": "Thường", "hard": "Khó"}

const DIFFICULTY: Dictionary = {
	"levels": {
		"easy": {"health": 0.8, "speed": 0.9, "reaction": 1.3, "parry": 0.7, "dodge": 0.7, "score": 0.8},
		"normal": {"health": 1.0, "speed": 1.0, "reaction": 1.0, "parry": 1.0, "dodge": 1.0, "score": 1.0},
		"hard": {"health": 1.25, "speed": 1.1, "reaction": 0.75, "parry": 1.3, "dodge": 1.3, "score": 1.3},
	},
	"health_per_wave": 0.08, "health_max_mult": 4.0,
	"speed_per_wave": 0.02, "speed_max_mult": 1.6,
	"reaction_per_wave": 0.06, "reaction_min_mult": 0.5,
	"parry_per_wave": 0.03, "parry_max": 0.8,
	"dodge_per_wave": 0.02, "dodge_max": 0.7,
	"chance_hard_cap": 0.95,
	# Chiến thuật nhóm
	"max_melee_attackers": 3, "ring_radius": 5.0,
	# Khi người chơi Destabilized: bot cận chiến báo đòn nhanh hơn, xạ thủ bắn ngay
	"punish_windup_mult": 0.6, "punish_speed_mult": 1.25, "punish_attack_cd": 0.2, "punish_shoot_delay": 0.4,
	"retreat_time": 0.6, # lùi một nhịp sau khi bị parry / thua clash
}
