extends RefCounted
## Dữ liệu gốc của người chơi, chuyển động, Titan và di chuyển của bot. `Global` giữ bản sao có thể chỉnh sống (tuning.cfg),
## nên ở đây chỉ để đọc. Không tham chiếu Global ở đây.

## Chuyển động chung (M26): thời gian đáp ứng camera + độ nghiêng theo gia tốc; preset "smooth" / "fast" đổi cả PLAYER, BOT_MOVE, MOTION.
const MOTION: Dictionary = {
	"cam_roll_time": 0.14, "cam_fov_time": 0.22, "cam_head_time": 0.10, # giây gần tới đích (lò xo tắt dần tới hạn)
	"accel_lean": 0.5,   # nghiêng thân theo gia tốc (0 = tắt): ~0,125 độ mỗi m/s²
}

const MOTION_PRESETS: Dictionary = {
	"smooth": {"p.ground_accel": 70.0, "p.ground_friction": 7.0, "p.stop_speed": 2.5, "p.grapple_redirect_time": 0.15, "p.grapple_tilt_deg": 3.0,
		"b.accel": 55.0, "b.decel": 55.0, "m.cam_roll_time": 0.14, "m.cam_fov_time": 0.22, "m.cam_head_time": 0.10, "m.accel_lean": 0.5},
	"fast": {"p.ground_accel": 100.0, "p.ground_friction": 8.0, "p.stop_speed": 3.0, "p.grapple_redirect_time": 0.0, "p.grapple_tilt_deg": 0.0,
		"b.accel": 30.0, "b.decel": 60.0, "m.cam_roll_time": 0.10, "m.cam_fov_time": 0.17, "m.cam_head_time": 0.07, "m.accel_lean": 0.0},
}

## Titan (M24). Nhân sát thương theo vùng: thân chỉ trầy, gáy rất đau, gối làm quỵ. Chỉ chạy ở map có `titans`.
## (var: chỉnh được lúc chơi qua bộ chỉnh F4, xem set_live)
const TITAN: Dictionary = {
	"scale": 6.0,                  # cỡ hình nhân (cao ~11 m)
	"body_mult": 0.1, "nape_mult": 6.0, "knee_mult": 0.5,   # nhân sát thương lên máu Titan theo vùng
	"knee_threshold": 120.0,       # sát thương thô vào gối để Titan quỵ
	"kneel_time": 4.0, "kneel_height": 0.7, # thời gian quỵ, tỉ lệ chiều cao khi quỵ
	"speed_accel": 5.0, "turn_rate": 1.4,
	"stomp_range": 13.0, "stomp_radius": 8.0, "stomp_damage": 40.0, "stomp_windup": 1.6, "stomp_recovery": 1.2, "stomp_cd": 4.0, "stomp_push": 13.0, "stomp_max_height": 3.0,
	"swipe_range": 15.0, "swipe_reach": 13.0, "swipe_width": 8.0, "swipe_damage": 55.0, "swipe_windup": 1.2, "swipe_active": 0.3, "swipe_recovery": 1.0, "swipe_cd": 3.0, "swipe_push": 16.0,
	"parry_stagger": 3.0,          # bị parry đòn: choáng chừng này giây
	"anim_speed_mult": 3.0,        # tốc độ hoạt ảnh chạy = tốc độ thật / cỡ * hệ số này (sải bước dài, nặng)
	"step_interval": 0.9, "shake_range": 45.0,
	"agent_radius": 2.0, "body_radius": 1.8, "body_height": 11.0,
	"first_wave": 5, "every": 5, "max_alive": 2,
	"health_mult": 1.0, "windup_mult": 1.0,   # độ khó Titan: nhân máu / thời gian báo đòn
}

## Di chuyển bot (M23): gia tốc, xoay thân, nhìn trước trên đường đi, nhảy leo, nấp, tính đường thưa ở xa.
## (var: chỉnh được lúc chơi qua bộ chỉnh F4, xem set_live)
const BOT_MOVE: Dictionary = {
	"accel": 55.0, "decel": 55.0,        # m/s^2 khi tăng tốc / phanh (cùng cỡ với người chơi: preset "smooth")
	"turn_rate": 16.0, "turn_rate_attack": 40.0, # rad/s xoay thân (khi ra đòn xoay nhanh hơn)
	"lookahead": 8.0,                    # m: bỏ qua điểm ngoặt nếu thấy thẳng được điểm xa hơn trong tầm này
	"vault_max": 3.0, "vault_cd": 0.8, "vault_push": 4.5, # nhảy leo tối đa (m), thời gian chờ, lực đẩy tiến
	"cover_chance": 0.6, "cover_radius": 9.0,  # xạ thủ/pháo thủ nấp sau mỗi lần bắn
	"far_dist": 60.0, "far_path_interval": 1.0, "path_interval": 0.3, # bot xa người chơi tính đường thưa hơn
	"unstick_time": 0.6,
}

## (var: chỉnh được lúc chơi qua bộ chỉnh F4, xem set_live)
const PLAYER: Dictionary = {
	"walk_speed": 9.0,       # m/s, tốc độ đích khi đi bộ
	"ground_accel": 70.0,    # m/s² trên mặt đất (preset "smooth"; "fast" = 100; cân bằng với ma sát nên cần > walk_speed * friction)
	"ground_friction": 7.0,  # hệ số hãm trên mặt đất
	"stop_speed": 2.5,       # dưới ngưỡng này ma sát hãm tuyến tính, dừng dứt khoát
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
	"grapple_range": 90.0,
	"grapple_pull_start": 40.0,  # m/s² lúc mới móc
	"grapple_pull_max": 130.0,   # m/s² sau khi kéo đủ lâu (lực tăng dần)
	"grapple_ramp": 0.8,         # giây để lực kéo đạt mức tối đa
	"grapple_max_speed": 45.0,   # tốc độ kéo tối đa về phía điểm móc
	"grapple_stop_dist": 2.5,    # tới gần điểm móc thì ngừng kéo (vẫn bám nếu còn giữ chuột)
	"grapple_max_time": 6.0,
	"grapple_assist_deg": 6.0,   # hỗ trợ ngắm: nón (độ) quanh tâm ngắm để tìm điểm móc khi tia chính không trúng
	"grapple_swing": 1.0,        # 1 = dây căng thì đu như con lắc (không bị kéo xa hơn độ dài dây), 0 = tắt
	"grapple_release_snap": 4.0, # + m/s khi nhả lúc dây đang căng (bắn ra theo hướng nhìn)
	"grapple_cooldown": 0.5,
	"grapple_soft_cap": 38.0,      # M33: tốc độ ngang trên mức này bị hãm dần (không chặn cứng); boost nhả móc cũng giảm về 0 tại mức này
	"grapple_cap_drag": 2.5,       # 1/giây: phần vượt trần giảm theo hàm mũ
	"grapple_chain_free": 2.0,     # số lần móc liên tiếp không bị phạt cooldown
	"grapple_chain_cd": 0.15,      # + giây cooldown cho mỗi lần móc liên tiếp quá mức trên
	"grapple_chain_cd_max": 0.6,   # trần cooldown cộng thêm
	"grapple_chain_recover": 0.5,  # chuỗi giảm bấy nhiêu lần/giây khi không móc
	"fov_speed_max": 11.0,         # M33: FOV nở tối đa theo tốc độ (độ); trước đây 18
	"grapple_redirect_blend": 0.7, # nhả móc: tỉ lệ vận tốc được xoay theo hướng nhìn (giữ nguyên độ lớn)
	"grapple_release_boost": 3.0,  # + m/s dọc hướng nhìn khi nhả móc (redirect)
	"grapple_redirect_time": 0.15, # giây xoay dần vận tốc khi nhả móc (0 = tức thì)
	"grapple_tilt_deg": 3.0,       # camera nghiêng về phía điểm móc khi đang kéo
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
