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
## Thứ tự và tên hiển thị các loại bot (HUD / tổng kết).
const BOT_ORDER: Array = ["swordsman", "rusher", "gunner", "bomber", "elite"]
const BOT_NAMES: Dictionary = {"swordsman": "Lính kiếm", "rusher": "Lao nhanh", "gunner": "Xạ thủ", "bomber": "Pháo thủ", "elite": "Tinh nhuệ"}
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
	"dummy": {"shoulder": 1.0, "bulk": 1.0, "armor": 0, "weapon": "none", "glow": false, "style": "none"},
	"swordsman": {"shoulder": 1.25, "bulk": 1.1, "armor": 1, "weapon": "sword", "glow": false, "style": "ronin"},
	"gunner": {"shoulder": 0.85, "bulk": 0.8, "armor": 0, "weapon": "gun", "glow": false, "style": "ranger"},
	"elite": {"shoulder": 1.4, "bulk": 1.3, "armor": 2, "weapon": "sword", "glow": true, "style": "guard"},
	"rusher": {"shoulder": 0.9, "bulk": 0.85, "armor": 0, "weapon": "sword", "glow": true, "style": "ronin"},
	"bomber": {"shoulder": 1.1, "bulk": 1.25, "armor": 1, "weapon": "gun", "glow": false, "style": "ranger"},
}
## Màu da dùng chung cho đầu, cổ, bàn tay (thân/quần áo lấy màu theo loại bot).
const SKIN_COLOR: Color = Color(0.84, 0.68, 0.57)

## Hoạt ảnh thân (M7.2). Góc tính bằng độ; +x của khớp = vung về phía trước (-Z).
const ANIM: Dictionary = {
	"stride_rate": 1.3,      # rad pha chạy trên mỗi mét đi được
	"run_min_speed": 0.6,    # dưới ngưỡng này coi là đứng yên
	"leg_swing": 45.0,
	"knee_bend": 70.0,
	"arm_swing": 40.0,
	"lean_per_speed": 0.8,   # độ nghiêng thân mỗi m/s
	"lean_max": 12.0,
	# Lò xo cho mỗi khớp: k = độ cứng, c = giảm chấn (c = 2*sqrt(k)*zeta; zeta < 1 thì có nảy nhẹ).
	"joint_k": 260.0,
	"joint_c": 25.0,
	"hip_bob": 0.035,        # hông nhún lên xuống theo bước chạy (m)
	"hip_twist": 7.0,        # hông xoay theo bước (độ)
	"spine_twist": 11.0,     # thân xoay ngược hông (độ)
	"lunge": 0.14,           # lao tới khi chém (m, chỉ hiển thị)
	"anticip_drop": 0.09,    # hạ người trước khi chém (m)
	"idle_look": 12.0,       # góc quay đầu nhìn quanh khi đứng yên (độ)
	"dash_time": 0.3,        # thời gian giữ tư thế dash
	"slide_drop": 0.38,      # hạ hông khi trượt (m)
	# Hoạt ảnh chiến đấu chồng lên di chuyển (M7.3). Thời lượng tính bằng giây.
	"overlay_in": 0.06,      # pha vào / ra của overlay (pha trộn với hoạt ảnh nền)
	"overlay_out": 0.12,
	"shoot_time": 0.25,
	"hurt_time": 0.25,
	"parry_time": 0.28,      # giữ tư thế chắn: cửa sổ parry + một nhịp
	"parry_miss_time": 0.6,
	"die_time": 0.45,
	# Camera hỗ trợ hoạt ảnh (M19), đều nhân với hệ số Cài đặt "cam_fx".
	"cam_lunge": 0.9,        # xung lao tới khi chém (m/s, lò xo kéo về)
	"cam_dip_min_fall": 6.0, # rơi chậm hơn mức này (m/s) thì không đập camera
	"cam_dip_per_speed": 0.012, # m/s xung đập mỗi m/s rơi vượt ngưỡng
	"cam_dip_max": 0.35,
	"cam_fx_k": 160.0,       # độ cứng/giảm chấn lò xo camera (c < 2*sqrt(k) thì nảy nhẹ)
	"cam_fx_c": 16.0,
	"slide_tilt_deg": 2.5,   # camera nghiêng khi lướt (độ)
	# Bot (M20): IK + tiếp xúc.
	"look_max_yaw": 60.0,    # giới hạn quay đầu/thân nhìn mục tiêu (độ)
	"look_max_pitch": 30.0,
	"look_rate": 8.0,        # tốc độ bám mục tiêu nhìn (1/s)
	"support_hand": 0.9,     # trọng số IK tay trái đỡ báng súng của xạ thủ
	"clash_time": 0.5,       # trùng clash_stagger
	"parry_hit_time": 0.3,
	"head_zone": 1.45,       # trúng cao hơn mức này (m so với chân) = đầu
	"leg_zone": 0.85,        # thấp hơn mức này = chân
}

## Tay + vũ khí góc nhìn thứ nhất (M7.4). Chỉ là hiển thị, không ảnh hưởng vật lý. Vị trí tính theo mét, góc theo độ.
const VIEWMODEL: Dictionary = {
	"sword_pos": Vector3(0.34, -0.55, -0.6),
	"gun_pos": Vector3(-0.3, -0.26, -0.5),
	"bob_freq": 0.4545,        # chu kỳ trên mỗi mét = 1 / PLAYER.step_stride: nhịp nhún khớp nhịp bước chân
	"bob_amp": 0.03,          # biên độ nhún lên xuống (m) ở tốc độ bob_speed_ref
	"bob_side": 0.02,
	"bob_speed_ref": 10.0,
	# Lò xo (đàn hồi, hồi về có nảy nhẹ): k = độ cứng, c = giảm chấn (c < 2*sqrt(k) thì có nảy).
	"spring_k": 140.0,
	"spring_c": 13.0,
	"rot_spring_k": 110.0,
	"rot_spring_c": 11.0,
	"sway_impulse": 18.0,      # vận tốc xoay (độ/s) thêm vào mỗi pixel chuột
	"sway_max": 7.0,           # giới hạn độ lệch xoay (độ)
	"state_blend": 10.0,
	# Tư thế kiếm/súng theo trạng thái (M18): vị trí cộng thêm (m) và góc xoay tuyệt đối (độ).
	"strafe_roll": 9.0,        # nghiêng tay khi đi ngang (độ ở vận tốc ngang tối đa)
	"idle_sway": 1.6,          # độ lắc thở khi đứng yên (độ)
	"sprint_lean": 12.0,       # kiếm hạ về trước khi chạy nhanh (độ pitch)
	"sword_pose_blend": 9.0,
	"sword_pose": {
		"slide": {"pos": Vector3(-0.06, 0.02, -0.02), "rot": Vector3(50.0, -14.0, -30.0)},
		"dash": {"pos": Vector3(0.0, 0.1, 0.0), "rot": Vector3(52.0, 10.0, -16.0)},
		"wallrun": {"pos": Vector3(0.0, 0.02, 0.0), "rot": Vector3(76.0, 0.0, -32.0)},
		"grapple": {"pos": Vector3(0.0, 0.02, 0.0), "rot": Vector3(60.0, 0.0, -24.0)},
	},
	"gun_pose": {
		"grapple": {"pos": Vector3(0.05, 0.22, -0.08), "rot": Vector3(-12.0, 0.0, -6.0)},
		"slide": {"pos": Vector3(0.03, -0.02, 0.03), "rot": Vector3(-12.0, 0.0, -18.0)},
		"dash": {"pos": Vector3(0.0, 0.03, 0.06), "rot": Vector3(-8.0, 0.0, 0.0)},
		"wallrun": {"pos": Vector3(0.0, 0.0, 0.0), "rot": Vector3(0.0, 0.0, 10.0)},
	},
	# Tư thế của CẢ viewmodel theo trạng thái (M19): pos (m) + rot (độ pitch, yaw, roll), cross-fade theo trọng số trạng thái.
	"body_pose": {
		"slide": {"pos": Vector3(0.0, -0.09, 0.05), "rot": Vector3(4.0, 0.0, 12.0)},
		"dash": {"pos": Vector3(0.0, -0.03, 0.14), "rot": Vector3(-6.0, 0.0, 0.0)},
		"wallrun": {"pos": Vector3.ZERO, "rot": Vector3(0.0, 0.0, 8.0)},
	},
	"state_fade": 0.14,        # giây để trọng số một trạng thái trượt 0 -> 1 (cross-fade, không đổi tức thì)
	"step_impulse": 0.3,       # nhún mỗi bước chân (m/s xung), đồng bộ âm bước chân
	"step_roll": 2.2,          # nghiêng luân phiên trái/phải mỗi bước (độ)
	"kick_zeta": 0.6,          # giảm chấn lò xo giật súng (< 1 = nảy nhẹ)
	"draw_k": 160.0,
	"reload_k": 220.0,
	# Độ cứng lò xo theo pha clip (k lớn = bám đích sát/nhanh; k nhỏ = trễ, mềm).
	"clash_impulse": 1.4,      # xung đẩy lùi viewmodel khi hai kiếm chạm nhau (m/s)
	"swing_windup_k": 520.0,
	"swing_active_k": 1500.0,  # chém: bám sát đích để "tăng tốc mạnh rồi dừng đột ngột"
	"swing_follow_k": 700.0,
	"swing_recover_k": 600.0,
	"guard_k": 1800.0,         # đỡ: bật rất nhanh
	"guard_hold_k": 600.0,
	"parry_fail_k": 260.0,
	# Cánh tay hai khớp (IK): vai trong không gian viewmodel (ngoài màn hình), độ dài hai đoạn (m).
	"sword_shoulder": Vector3(0.28, -0.55, 0.15),
	"gun_shoulder": Vector3(-0.26, -0.5, 0.15),
	"upper_arm": 0.6,
	"fore_arm": 0.6,
	# Tư thế đỡ đòn: lưỡi kiếm nằm ngang chắn trước mặt (yaw ~80 độ quét lưỡi sang trái).
	"guard_pos": Vector3(0.2, -0.2, -0.62),
	"guard_rot": Vector3(12.0, 82.0, 8.0),
	"guard_in": 0.06,
	"flash_light": 3.0,
	"land_impulse": 0.8,       # vận tốc nảy xuống khi tiếp đất (m/s)
	"kick_back": 0.09,         # súng giật lùi (m)
	"kick_pitch": 9.0,         # hất nòng (độ)
	"kick_time": 0.14,
	"flash_time": 0.05,
	"reload_down_time": 0.2,
	"reload_up_time": 0.2,
	"flinch_impulse": 1.0,     # vận tốc giật khi bị đánh (m/s)
	"sleeve": Color(0.16, 0.36, 0.55),
	"glove": Color(0.62, 0.52, 0.42),
	"steel": Color(0.82, 0.86, 0.95),
	"gun_metal": Color(0.17, 0.18, 0.21),
}

## Instability "mất thế" (Destabilized). Thanh tăng khi mất thế trong giao đấu (thua clash, parry hụt,
## bị parry); đầy thì Destabilized vài giây: không tấn công/parry/bắn, stamina dash về 0. Áp dụng cả bot.
const INSTABILITY: Dictionary = {
	"max": 100.0,
	"clash_loss": 30.0,        # thua clash (nhân 0.6..1.4 theo thanh hiện tại: càng mất thế càng dễ thua)
	"parried_loss": 40.0,      # đòn bị người kia parry
	"parry_miss_loss": 25.0,   # parry hụt
	"parry_relief": 20.0,      # parry thành công: bớt mất thế
	"hit_relief": 8.0,         # đòn kiếm trúng: bớt mất thế
	"decay_delay": 1.5,        # giây không bị cộng thêm thì thanh mới tự giảm
	"decay": 8.0,              # /giây
	"destabilized_time": 3.0,  # giây
	"immunity_time": 1.5,      # giây sau khi hồi phục không bị cộng thanh (tránh khóa liên tục)
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
## Kho vũ khí của người chơi. Súng lục = số trong COMBAT (gun_*). kind: hitscan | pellets | explosive.
const WEAPON_ORDER: Array = ["pistol", "shotgun", "launcher", "sniper"]
const WEAPONS: Dictionary = {
	"pistol": {"name": "Súng lục", "kind": "hitscan", "mag": 6, "cooldown": 0.35, "reload": 1.1, "damage": 25.0,
		"range": 80.0, "recoil": 1.0, "draw": 0.25, "sfx": "shot"},
	"shotgun": {"name": "Shotgun", "kind": "pellets", "mag": 2, "cooldown": 0.6, "reload": 1.8, "damage": 12.0,
		"pellets": 8, "spread_deg": 5.0, "falloff_range": 18.0, "min_falloff": 0.2,
		"range": 40.0, "recoil": 3.0, "draw": 0.4, "sfx": "shotgun"},
	"launcher": {"name": "Pháo nổ", "kind": "explosive", "mag": 2, "cooldown": 0.9, "reload": 2.2, "damage": 60.0,
		"projectile_speed": 38.0, "gravity": 6.0, "blast_radius": 4.5, "min_falloff": 0.4,
		"knockback": 16.0, "self_damage_mult": 0.15, "stagger": 0.6, "life": 4.0,
		"range": 80.0, "recoil": 0.0, "draw": 0.5, "sfx": "launcher"},
	"sniper": {"name": "Bắn tỉa", "kind": "hitscan", "mag": 3, "cooldown": 1.1, "reload": 2.2, "damage": 80.0,
		"headshot_mult": 2.0, "headshot_height": 1.5, "pierce": 1, "pierce_mult": 0.6,
		"range": 200.0, "recoil": 1.5, "draw": 0.5, "zoom_fov": 35.0, "sfx": "sniper"},
}
## Chém rộng (phím Q): quét rộng và xa hơn, chậm và để hở lâu hơn, sát thương cao hơn.
const HEAVY_SLASH: Dictionary = {
	"windup_mult": 1.7, "active_mult": 1.5, "recovery_mult": 1.8,
	"width_mult": 1.9, "reach_mult": 1.5, "damage_mult": 1.4,
}

## Hiệu ứng (M12). reduced_fx = true: tắt vệt kiếm + sóng parry, hạt còn 1/3, rung camera yếu đi.
const FX: Dictionary = {
	"trail_life": 0.26, "trail_max_points": 20, "trail_color": Color(0.8, 0.95, 1.0, 1.0),
	"heavy_trail_color": Color(1.0, 0.7, 0.35, 0.85),
	"ring_time": 0.3, "ring_radius": 2.2,
	"reduced_particles": 0.33, "reduced_shake": 0.4,
	"scorch_time": 8.0,
}
## Vật nhặt: rơi khi bot chết (drop_chance) hoặc thùng vỡ; weight = tỉ lệ chọn loại.
const PICKUPS: Dictionary = {
	"drop_chance": 0.25, "crate_drop_chance": 0.4, "lifetime": 12.0, "blink_time": 3.0,
	"kinds": {
		"health": {"weight": 3.0, "heal": 30.0, "color": Color(0.35, 0.95, 0.4), "label": "+30 MÁU"},
		"ammo": {"weight": 3.0, "color": Color(1.0, 0.8, 0.25), "label": "ĐẠN ĐẦY"},
		"stamina": {"weight": 2.0, "color": Color(0.4, 0.75, 1.0), "label": "STAMINA ĐẦY"},
	},
}
## Vật thể phá được. Thùng nổ dùng cùng khoá với vụ nổ pháo (Rocket.explode).
const BREAKABLES: Dictionary = {
	"barrel": {"health": 20.0, "explosive": true, "damage": 50.0, "blast_radius": 5.0, "min_falloff": 0.3,
		"knockback": 14.0, "self_damage_mult": 1.0, "stagger": 0.8},
	"crate": {"health": 10.0, "explosive": false},
}

const PLAYER: Dictionary = {
	"walk_speed": 9.0,       # m/s, tốc độ đích khi đi bộ
	"ground_accel": 100.0,   # m/s² trên mặt đất (đủ lớn để đạt đúng walk_speed dù có ma sát)
	"ground_friction": 8.0,  # hệ số hãm trên mặt đất
	"stop_speed": 3.0,       # dưới ngưỡng này ma sát hãm tuyến tính, dừng dứt khoát
	"air_accel": 18.0,       # m/s² trên không (cho phép air-strafe cộng thêm tốc độ)
	"gravity": 24.0,         # m/s²
	"jump_velocity": 9.0,    # m/s, nhảy cao ~1.7m
	"mouse_sens": 0.0022,    # rad/pixel
	# --- Cảm giác điều khiển (M13) ---
	"coyote_time": 0.1,      # giây còn nhảy được sau khi rời mép sàn
	"jump_buffer": 0.12,     # giây nhớ lệnh nhảy bấm sớm trước khi chạm đất
	"ledge_min_height": 0.9, # m: bệ thấp hơn mức này (tính từ chân) thì khỏi trèo
	"ledge_max_height": 2.3, # m: bệ cao hơn thì không với tới
	"ledge_reach": 0.8,      # m: khoảng dò tường phía trước
	"ledge_up_time": 0.16,   # giây kéo người lên dọc mép
	"ledge_over_time": 0.12, # giây bước qua mặt bệ
	"ledge_cooldown": 0.4,   # giây không trèo lại sau khi trèo xong
	"ledge_max_rise_speed": 4.0, # chỉ trèo khi đang rơi / gần đỉnh nhảy (vận tốc đứng <= mức này)
	"step_stride": 2.2,      # m mỗi bước chân
	"bob_amplitude": 0.035,  # m, biên độ lắc đầu khi chạy
	"bob_frequency": 1.15,   # chu kỳ lắc / m quãng đường
	"strafe_roll_deg": 1.5,  # độ nghiêng camera khi di chuyển ngang
	"gamepad_look_speed": 3.2, # rad/s ở độ nhạy 1.0
	# --- Slide ---
	"slide_min_speed": 6.0,  # phải chạy nhanh hơn mức này mới trượt được
	"slide_boost": 4.0,      # cú đẩy khi bắt đầu trượt (m/s)
	"slide_boost_cooldown": 1.0, # giây tối thiểu giữa 2 cú đẩy (chống spam trượt)
	"slide_hop_boost": 2.5,  # nhảy ngay lúc đang trượt: cộng thêm tốc độ ngang (m/s)
	"slide_hop_max_speed": 26.0, # slide hop không cộng nếu đã nhanh hơn mức này
	"slide_friction": 0.2,   # ma sát rất nhỏ khi trượt (tỉ lệ theo tốc độ, 1/giây)
	"slide_end_speed": 2.5,  # chậm hơn mức này thì tự đứng dậy
	"slide_steer": 5.0,      # khả năng bẻ hướng khi trượt
	# --- Dash ---
	"dash_impulse": 18.0,    # m/s cộng thêm vào vận tốc hiện tại
	"dash_stamina_max": 100.0, # dash dùng thanh stamina; 1 charge hiển thị = dash_cost stamina
	"dash_cost": 50.0,
	"dash_max_charges": 2,   # = dash_stamina_max / dash_cost (dùng cho HUD)
	"dash_regen": 50.0,      # stamina/giây
	"dash_regen_delay": 0.25, # giây sau mỗi cú dash thanh mới bắt đầu hồi
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
	"grapple_redirect_blend": 0.7, # nhả móc: tỉ lệ vận tốc được xoay theo hướng nhìn (giữ nguyên độ lớn)
	"grapple_release_boost": 3.0,  # + m/s dọc hướng nhìn khi nhả móc (redirect)
	# --- Ground slam ---
	"slam_min_height": 2.0,  # phải cách mặt đất ít nhất chừng này mới slam được
	"slam_speed": 42.0,      # tốc độ lao xuống
	"slam_radius": 5.0,
	"slam_damage": 25.0,
	"slam_stagger": 1.0,     # giây địch bị choáng
	"slam_bounce": 0.25,     # tỉ lệ vận tốc rơi chuyển thành nảy lên
	"slam_bounce_max": 11.0,
	"slam_cooldown": 1.0,
	"slam_air_steer": 2.0,
	# --- Recoil movement ---
	"recoil_impulse": 6.0,   # bắn trên không đẩy ngược hướng nòng (m/s)
	"recoil_max_speed": 30.0, # không cộng nếu đã nhanh hơn mức này
}


signal quality_changed(level: int)
signal map_changed(id: String)

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
## Âm thanh (M15). Mỗi âm: vol_db gốc, pitch_var (±tỉ lệ), voices (tối đa phát cùng lúc), bus.
## Âm 3D (Sfx.play_at) giảm dần theo khoảng cách: unit_size / max_distance.
const SOUNDS: Dictionary = {
	"slash": {"vol_db": -8.0, "pitch_var": 0.12, "voices": 4, "bus": "SFX"},
	"shot": {"vol_db": -7.0, "pitch_var": 0.06, "voices": 4, "bus": "SFX"},
	"shotgun": {"vol_db": -4.0, "pitch_var": 0.05, "voices": 2, "bus": "SFX"},
	"launcher": {"vol_db": -5.0, "pitch_var": 0.05, "voices": 3, "bus": "SFX"},
	"sniper": {"vol_db": -3.0, "pitch_var": 0.03, "voices": 2, "bus": "SFX"},
	"explosion": {"vol_db": -2.0, "pitch_var": 0.08, "voices": 3, "bus": "SFX"},
	"hit": {"vol_db": -8.0, "pitch_var": 0.1, "voices": 4, "bus": "SFX"},
	"hurt": {"vol_db": -5.0, "pitch_var": 0.05, "voices": 2, "bus": "SFX"},
	"clash": {"vol_db": -4.0, "pitch_var": 0.1, "voices": 3, "bus": "SFX"},
	"parry": {"vol_db": -4.0, "pitch_var": 0.03, "voices": 2, "bus": "SFX"},
	"step": {"vol_db": -14.0, "pitch_var": 0.15, "voices": 2, "bus": "SFX"},
	"step_metal": {"vol_db": -12.0, "pitch_var": 0.12, "voices": 2, "bus": "SFX"},
	"step_wood": {"vol_db": -12.0, "pitch_var": 0.12, "voices": 2, "bus": "SFX"},
	"jump": {"vol_db": -12.0, "pitch_var": 0.08, "voices": 2, "bus": "SFX"},
	"ledge": {"vol_db": -9.0, "pitch_var": 0.05, "voices": 1, "bus": "SFX"},
	"dash": {"vol_db": -7.0, "pitch_var": 0.06, "voices": 2, "bus": "SFX"},
	"slide": {"vol_db": -9.0, "pitch_var": 0.05, "voices": 1, "bus": "SFX"},
	"wall": {"vol_db": -9.0, "pitch_var": 0.05, "voices": 1, "bus": "SFX"},
	"grapple": {"vol_db": -7.0, "pitch_var": 0.05, "voices": 1, "bus": "SFX"},
	"reload": {"vol_db": -8.0, "pitch_var": 0.04, "voices": 1, "bus": "SFX"},
	"switch": {"vol_db": -10.0, "pitch_var": 0.06, "voices": 1, "bus": "SFX"},
	"crate": {"vol_db": -6.0, "pitch_var": 0.1, "voices": 3, "bus": "SFX"},
	"bot_die": {"vol_db": -6.0, "pitch_var": 0.12, "voices": 3, "bus": "SFX"},
	"pickup": {"vol_db": -6.0, "pitch_var": 0.0, "voices": 2, "bus": "SFX"},
	"wave": {"vol_db": -4.0, "pitch_var": 0.0, "voices": 1, "bus": "UI"},
	"destabilized": {"vol_db": -4.0, "pitch_var": 0.0, "voices": 1, "bus": "SFX"},
	"recover": {"vol_db": -8.0, "pitch_var": 0.0, "voices": 1, "bus": "SFX"},
	"ui_click": {"vol_db": -8.0, "pitch_var": 0.03, "voices": 2, "bus": "UI"},
	"game_over": {"vol_db": -4.0, "pitch_var": 0.0, "voices": 1, "bus": "UI"},
}
const AUDIO_BUSES: Array = ["SFX", "Music", "UI"]
const AUDIO: Dictionary = {
	"voices_2d": 8, "voices_3d": 14, "unit_size": 9.0, "max_distance": 70.0,
	"music_fade": 1.2,          # giây đổi lớp nhạc theo cường độ
	"intensity_enemies": 8,     # số bot tạo cường độ tối đa
	"intensity_low_hp": 0.4,    # dưới tỉ lệ máu này nhạc dồn thêm
}
## Chất liệu sàn theo vai trò (bước chân).
## Tên âm bước chân theo chất liệu sàn ("stone" mặc định).
static func step_sound(surface: String) -> String:
	match surface:
		"metal":
			return "step_metal"
		"wood":
			return "step_wood"
	return "step"


const SURFACES: Dictionary = {"platform": "metal", "grapple": "metal", "runwall": "metal", "ramp": "metal"}
## Các hành động đổi phím được: [action, tên hiển thị].
const REMAPPABLE: Array = [
	["move_forward", "Tiến"], ["move_back", "Lùi"], ["move_left", "Trái"], ["move_right", "Phải"],
	["jump", "Nhảy"], ["slide", "Trượt"], ["dash", "Dash"], ["slam", "Đập đất"],
	["attack", "Chém"], ["heavy", "Chém rộng"], ["shoot", "Bắn"], ["parry", "Parry"],
	["grapple", "Móc"], ["reload", "Nạp đạn"], ["zoom", "Ngắm"],
	["weapon_1", "Súng 1"], ["weapon_2", "Súng 2"], ["weapon_3", "Súng 3"], ["weapon_4", "Súng 4"],
]

## Chế độ chơi (M16). Sinh tồn: wave vô hạn. Thời gian: hạ `target_kills` bot trước khi hết giờ, mỗi bot hạ
## cộng `kill_bonus` giây (tối đa `max_time`); thắng được cộng `win_bonus_per_sec` điểm cho mỗi giây còn lại.
## Tập luyện: bất tử, đạn vô hạn, bot tập sinh lần lượt, không tính điểm.
const MODES: Array = ["survival", "timed", "training"]
const MODE_NAMES: Dictionary = {"survival": "Sinh tồn", "timed": "Thử thách thời gian", "training": "Tập luyện"}
const MODE_DESCRIPTIONS: Dictionary = {
	"survival": "Chống lại các wave bot ngày càng mạnh cho tới khi gục. Điểm cao nhất được lưu.",
	"timed": "Hạ đủ số bot trước khi hết giờ. Mỗi bot hạ được cộng thêm giây. Thắng càng sớm điểm càng cao.",
	"training": "Bất tử, đạn vô hạn, có bot tập để thử vũ khí và di chuyển. Không tính điểm.",
}
const TIMED: Dictionary = {
	"start_time": 90.0, "kill_bonus": 3.0, "max_time": 150.0, "target_kills": 25,
	"win_bonus_per_sec": 10, "break_time": 1.5, "urgent_below": 10.0,
}
const TRAINING: Dictionary = {"respawn_time": 2.0, "bot_wave": 1, "types": ["swordsman", "gunner", "rusher", "elite", "bomber"]}

const VERSION: String = "1.0.0"
const MAP_IDS: Array = ["yard", "alley", "tower"]
const MAP_NAMES: Dictionary = {"yard": "Sân tập", "alley": "Hẻm tường", "tower": "Tháp"}

## Điểm cao nhất + mức đồ họa, lưu vào file để còn sau khi tắt game.
var save_path: String = "user://savegame.cfg"
var high_score: int = 0
var quality: int = QUALITY_DEFAULT
var selected_map: String = "yard"
var reduced_fx: bool = false
## Bật để lớp phủ F3 hiện pha/clip hoạt ảnh viewmodel (gỡ lỗi hoạt ảnh).
var anim_debug: bool = false
var anim_debug_samples: PackedFloat32Array = PackedFloat32Array()   # đường cong kiếm (độ lệch vị trí, góc) cho bộ chỉnh hoạt ảnh
## Giá trị chỉnh lúc chơi ghi đè hằng số hoạt ảnh (khoá "v.<tên>" cho VIEWMODEL, "a.<tên>" cho ANIM). Xem anim_tuner.gd.
var tune: Dictionary = {}
var anim_debug_text: String = ""   # viewmodel ghi mỗi frame khi anim_debug bật
var difficulty: String = "normal"
var game_mode: String = "survival"
var _scores: Dictionary = {}
var _mode_scores: Dictionary = {} # "<chế_độ>_<mức>" -> điểm (sinh tồn dùng _scores/high_score như cũ)
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var _default_bindings: Dictionary = {}


func _ready() -> void:
	_setup_input()
	load_save()


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
	high_score = 0
	quality = QUALITY_DEFAULT
	selected_map = "yard"
	reduced_fx = false
	difficulty = "normal"
	game_mode = "survival"
	_scores = {}
	_mode_scores = {}
	settings = DEFAULT_SETTINGS.duplicate()
	if not FileAccess.file_exists(save_path):
		return
	var cf := ConfigFile.new()
	if cf.load(save_path) == OK:
		var legacy: int = maxi(int(_num(cf.get_value("progress", "high_score", 0), 0.0)), 0)
		for lv in DIFFICULTY_LEVELS:
			_scores[lv] = maxi(int(_num(cf.get_value("progress", "high_score_" + lv, legacy if lv == "normal" else 0), 0.0)), 0)
		for md in MODES:
			if md == "survival":
				continue
			for lv in DIFFICULTY_LEVELS:
				_mode_scores[md + "_" + lv] = maxi(int(_num(cf.get_value("progress", "high_score_%s_%s" % [md, lv], 0), 0.0)), 0)
		var gm: String = str(cf.get_value("game", "mode", "survival"))
		game_mode = gm if gm in MODES else "survival"
		var dl: String = str(cf.get_value("game", "difficulty", "normal"))
		difficulty = dl if dl in DIFFICULTY_LEVELS else "normal"
		high_score = int(_scores.get(difficulty, 0))
		quality = clampi(int(_num(cf.get_value("graphics", "quality", QUALITY_DEFAULT), QUALITY_DEFAULT)), 0, QUALITY.size() - 1)
		var m: String = str(cf.get_value("game", "map", "yard"))
		selected_map = m if m in MAP_IDS else "yard"
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
	_scores[difficulty] = high_score
	for lv in DIFFICULTY_LEVELS:
		cf.set_value("progress", "high_score_" + lv, int(_scores.get(lv, 0)))
	cf.set_value("progress", "high_score", int(_scores.get("normal", 0)))
	for k in _mode_scores:
		cf.set_value("progress", "high_score_" + k, int(_mode_scores[k]))
	cf.set_value("game", "mode", game_mode)
	cf.set_value("game", "difficulty", difficulty)
	cf.set_value("graphics", "quality", quality)
	cf.set_value("game", "map", selected_map)
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


## Chọn mức độ khó (điểm cao lưu riêng từng mức). Đổi giữa trận không ảnh hưởng bot đã sinh.
func set_difficulty(level: String) -> void:
	if level not in DIFFICULTY_LEVELS or level == difficulty:
		return
	_scores[difficulty] = high_score
	difficulty = level
	high_score = int(_scores.get(level, 0))
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


## Chọn đấu trường cho lần chơi sau (lưu file, phát Signal).
func set_map(id: String) -> void:
	if id not in MAP_IDS or id == selected_map:
		return
	selected_map = id
	_write_save()
	map_changed.emit(id)


func cycle_map() -> void:
	set_map(MAP_IDS[(MAP_IDS.find(selected_map) + 1) % MAP_IDS.size()])


func cycle_quality() -> void:
	set_quality((quality + 1) % QUALITY.size())


## Chọn chế độ chơi cho lần chơi sau (lưu file, phát Signal).
func set_mode(mode: String) -> void:
	if mode not in MODES or mode == game_mode:
		return
	game_mode = mode
	_write_save()
	mode_changed.emit(mode)


func cycle_mode() -> void:
	set_mode(MODES[(MODES.find(game_mode) + 1) % MODES.size()])


## Kỷ lục của một chế độ + mức độ khó (mặc định: đang chọn). Tập luyện không có kỷ lục.
func best_score(mode: String = "", level: String = "") -> int:
	var m: String = mode if mode in MODES else game_mode
	var lv: String = level if level in DIFFICULTY_LEVELS else difficulty
	match m:
		"survival":
			return high_score if lv == difficulty else int(_scores.get(lv, 0))
		"training":
			return 0
	return int(_mode_scores.get(m + "_" + lv, 0))


## Nộp điểm cho chế độ (mặc định: đang chọn) ở mức độ khó hiện tại. true nếu phá kỷ lục.
func submit_mode_score(value: int, mode: String = "") -> bool:
	var m: String = mode if mode in MODES else game_mode
	match m:
		"survival":
			return submit_score(value)
		"training":
			return false
	var key: String = m + "_" + difficulty
	if value <= int(_mode_scores.get(key, 0)):
		return false
	_mode_scores[key] = value
	_write_save()
	return true


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
	_add_key("slam", KEY_C)
	_add_key("heavy", KEY_Q)
	_add_key("zoom", KEY_Z)
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
const TUNABLE_VM: Array = ["spring_k", "spring_c", "rot_spring_k", "rot_spring_c", "sway_impulse", "state_fade", "step_impulse", "step_roll", "kick_zeta", "draw_k", "reload_k", "swing_windup_k", "swing_active_k", "swing_follow_k", "swing_recover_k", "guard_k", "guard_hold_k", "parry_fail_k", "clash_impulse", "land_impulse", "flinch_impulse", "kick_back", "kick_pitch"]
const TUNABLE_ANIM: Array = ["cam_lunge", "cam_dip_per_speed", "cam_dip_max", "cam_fx_k", "cam_fx_c", "slide_tilt_deg", "look_max_yaw", "look_max_pitch", "look_rate", "support_hand", "joint_k", "joint_c", "overlay_in", "overlay_out"]


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
