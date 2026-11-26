extends RefCounted
## Bảng màu, chất lượng đồ hoạ, môi trường, dáng người và hoạt ảnh (dữ liệu thuần).
## Chỉ là dữ liệu: `Global` nạp lại các hằng này nên mã khác vẫn dùng `Global.TÊN`. Không tham chiếu Global ở đây.

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
	# M42: màu vật liệu của model low poly (Blender dùng đúng các giá trị này, xem tools/blender/make_sword.py)
	"steel": Color(0.75, 0.78, 0.84),
	"steel_dark": Color(0.4875, 0.507, 0.546),
	"gold": Color(0.8, 0.65, 0.25),
	"leather": Color(0.28, 0.17, 0.1),
	"gun_metal": Color(0.17, 0.18, 0.21),
	"gun_metal_light": Color(0.3194, 0.3276, 0.3522),
	"wood": Color(0.32, 0.2, 0.1),
	"red": Color(0.7, 0.15, 0.1),
	"scope_dark": Color(0.08, 0.08, 0.1),
}

## M42 "Chuẩn low poly": model dựng trong Blender (.glb). `enabled` = false -> quay về khối/FBX cũ. Chuẩn đầy đủ: docs/ASSETS.md.
const LOWPOLY: Dictionary = {
	"enabled": true,
	"sword": "res://assets/weapons/lowpoly/sword.glb",
	# M43: súng cầm tay (gốc = bàn tay cầm, nòng -Z; phần cử động Mag/Pump/Cap/Bolt; Empty `muzzle`)
	"guns": {
		"pistol": "res://assets/weapons/lowpoly/pistol.glb",
		"shotgun": "res://assets/weapons/lowpoly/shotgun.glb",
		"launcher": "res://assets/weapons/lowpoly/launcher.glb",
		"sniper": "res://assets/weapons/lowpoly/sniper.glb",
	},
	# Ngân sách tam giác tối đa mỗi loại (đếm theo mesh trong .glb)
	"budget": {"bot": 1500, "weapon": 600, "prop": 1200},
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
	# M42: model low poly (màu phẳng, không lưới họa tiết)
	"steel": {"metallic": 0.0, "roughness": 0.6, "emission": 0.0, "tile": 1.0},
	"steel_dark": {"metallic": 0.0, "roughness": 0.6, "emission": 0.0, "tile": 1.0},
	"gold": {"metallic": 0.0, "roughness": 0.6, "emission": 0.0, "tile": 1.0},
	"leather": {"metallic": 0.0, "roughness": 0.6, "emission": 0.0, "tile": 1.0},
	"gun_metal": {"metallic": 0.0, "roughness": 0.6, "emission": 0.0, "tile": 1.0},
	"gun_metal_light": {"metallic": 0.0, "roughness": 0.6, "emission": 0.0, "tile": 1.0},
	"wood": {"metallic": 0.0, "roughness": 0.6, "emission": 0.0, "tile": 1.0},
	"red": {"metallic": 0.0, "roughness": 0.6, "emission": 0.0, "tile": 1.0},
	"scope_dark": {"metallic": 0.0, "roughness": 0.6, "emission": 0.0, "tile": 1.0},
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
	"titan": {"shoulder": 1.3, "bulk": 1.2, "armor": 0, "weapon": "none", "glow": false, "style": "none"},
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
	# Chuyển động bot theo hướng/tình huống (M30), chỉ hình ảnh. bm_* nhân với giảm hiệu ứng ở phần thân (không tắt dáng đi).
	"bm_back_swing": 0.75,   # độ vung chân khi lùi (nhân)
	"bm_back_lean": 7.0,     # ngả người ra sau khi lùi (độ)
	"bm_side_hip": 22.0,     # hông xoay về hướng đi ngang, vai giữ hướng nhìn (độ)
	"bm_side_cross": 10.0,   # chân bắt chéo khi đi ngang (độ)
	"bm_turn_lead": 0.045,   # độ thân dẫn trước khi quay người, mỗi độ/giây
	"bm_turn_max": 22.0,     # tối đa thân dẫn (độ)
	"bm_cover_drop": 0.3,    # hạ hông khi núp (m)
	"bm_peek": 0.2,          # nhô lên khi ló ra bắn (m)
	"bm_stride_blend": 0.1,  # thời gian đổi chiều bước chân (s)
	# Clip hoạt ảnh CC0 (M32): trộn lên tư thế sinh bằng code cho bot glTF. Đòn đánh/parry/bắn vẫn do code (thời gian không đổi).
	"ac_enabled": 1.0,       # 0 = tắt hẳn clip (chạy toàn bằng code như trước M32)
	"ac_idle": 0.85,         # trọng số clip khi đứng yên
	"ac_run": 0.9,           # trọng số clip khi chạy (tự giảm khi lùi/đi ngang vì clip chỉ có chạy tiến)
	"ac_cover": 0.7,         # trọng số clip khi núp
	"ac_hips": 0.8,          # trọng số theo khớp: hông
	"ac_spine": 0.7,         # thân
	"ac_head": 0.5,          # đầu
	"ac_arm": 0.0,           # tay (mặc định 0: tay do code lo để cầm vũ khí/IK; thử 0.3-0.6 nếu muốn tay đánh theo clip)
	"ac_hips_y": 0.9,        # biên độ nhấp nhô hông của clip (nhân)
	"ac_walk_speed": 1.6,    # tốc độ (m/s) clip Walk khớp 1:1 (tốc độ phát = tốc độ bot / giá trị này)
	"ac_jog_speed": 4.8,     # clip Jog
	"ac_sprint_speed": 7.5,  # clip Sprint
	"ac_walk_max": 3.0,      # dưới mức này dùng Walk
	"ac_sprint_min": 7.0,    # trên mức này dùng Sprint
	"ac_fade": 0.12,         # thời gian vào/ra lớp clip (s)
	"ac_xfade": 0.2,         # thời gian trộn khi đổi clip (s)
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
	# Cảm giác parry (M28): chỉ phản hồi, KHÔNG đổi cửa sổ/phạt trong COMBAT. Camera nhân với "cam_fx"; reduced_fx giảm hitstop.
	"pf_hitstop": 0.08,        # khựng khi đỡ đòn kiếm thành công (s, thời gian thực)
	"pf_hitstop_bullet": 0.05, # khựng khi phản đạn
	"pf_hitstop_scale": 0.05,  # time_scale trong lúc khựng
	"pf_clash_hitstop": 0.08,  # khựng khi clash (giữ như cũ)
	"pf_reduced_hitstop": 0.5, # hệ số khựng khi giảm hiệu ứng
	"pf_cam_kick": 2.5,        # camera giật theo hướng đòn bị đỡ (độ)
	"pf_fov_punch": 4.0,       # FOV nảy ngắn (độ)
	"pf_spark_cone": 50.0,     # độ loe chùm tia lửa quanh hướng đòn (độ)
	"pf_flash_energy": 2.5,    # chớp sáng trên lưỡi kiếm khi bật
	"pf_tell_lean": 12.0,      # bot ngả người báo đòn đầu windup (độ)
	"pf_tell_time": 0.3,       # thời lượng gồng báo đòn (s)
	"pf_tell_range": 14.0,     # tiếng báo đòn / chớp sáng chỉ khi bot gần hơn mức này (m)
	"pf_miss_stumble": 1.5,    # nhân biên độ loạng choạng khi parry hụt (bot)
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
	# M29 - riêng từng súng. Giật: nhân với kick_back/kick_pitch; "time" nhân kick_time (hồi chậm hơn = nặng hơn).
	"weapon_kick": {
		"pistol": {"back": 1.0, "pitch": 1.0, "time": 1.0},
		"shotgun": {"back": 1.5, "pitch": 1.7, "time": 1.2},
		"launcher": {"back": 1.9, "pitch": 1.4, "time": 1.5},
		"sniper": {"back": 1.4, "pitch": 2.0, "time": 1.6},
	},
	# Rút súng: tư thế bắt đầu (lệch so với tư thế nghỉ), vượt quá một chút ("over") rồi về. Thời gian = WEAPONS[id]["draw"].
	"weapon_draw": {
		"pistol": {"pos": Vector3(0.0, -0.3, 0.1), "rot": Vector3(-35.0, 0.0, 0.0), "over": Vector3(0.0, 0.015, -0.02)},
		"shotgun": {"pos": Vector3(0.12, -0.36, 0.14), "rot": Vector3(-50.0, 10.0, 18.0), "over": Vector3(0.0, 0.02, -0.03)},
		"launcher": {"pos": Vector3(0.2, -0.4, 0.2), "rot": Vector3(-60.0, 20.0, 25.0), "over": Vector3(0.0, 0.03, -0.04)},
		"sniper": {"pos": Vector3(0.0, -0.45, 0.25), "rot": Vector3(-70.0, 0.0, 8.0), "over": Vector3(0.0, 0.01, -0.05)},
	},
	"grip_curl_deg": 28.0,     # độ bóp của ngón khi bắn / chém
	"ledge_impulse": 1.0,      # nhấc vũ khí khi leo gờ
	"land_fall_gain": 1.2,     # tiếp đất mạnh theo vận tốc rơi: xung nhân (1 + fall/12 * gain)
	"flinch_impulse": 1.0,     # vận tốc giật khi bị đánh (m/s)
	"sleeve": Color(0.16, 0.36, 0.55),
	"glove": Color(0.62, 0.52, 0.42),
	"steel": Color(0.82, 0.86, 0.95),
	"gun_metal": Color(0.17, 0.18, 0.21),
}
