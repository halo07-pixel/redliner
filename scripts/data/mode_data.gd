extends RefCounted
## Chế độ chơi, XP, kho thẻ nâng cấp, Vô Tận, thời gian, tập luyện (dữ liệu thuần).
## Chỉ là dữ liệu: `Global` nạp lại các hằng này nên mã khác vẫn dùng `Global.TÊN`. Không tham chiếu Global ở đây.

## Chế độ chơi (M41: chỉ còn hai). Vô Tận: tầng vô hạn trên bản đồ lưới. Tập luyện: cùng bản đồ Vô Tận (tầng 1, hạt giống cố định),
## bất tử, đạn vô hạn, khu thử bot gần chỗ xuất phát, không tính điểm / XP / vàng.
const MODES: Array = ["endless", "training"]

const MODE_NAMES: Dictionary = {"training": "Tập luyện", "endless": "Vô Tận"}

const MODE_DESCRIPTIONS: Dictionary = {
	"training": "Bất tử, đạn vô hạn, mở khoá đủ 4 súng + kiếm. Gần chỗ xuất phát có khu thử bot (cận chiến, xạ thủ, pháo thủ bom); phím T gọi / xoá một Titan. Không tính điểm.",
	"endless": "Vô Tận: bản đồ rất rộng, mỗi tầng một bản đồ mới. Hạ đủ bot để mở cổng, chạy tới cột sáng để sang tầng sau. Cứ 5 tầng có Titan.",
}

## Kinh nghiệm / lên cấp chế độ Vô Tận (M35). Cấp n -> n+1 cần need_base + need_per_level*n XP (n bắt đầu từ 0).
## orb = XP một bot rơi (theo loại, "default" cho loại khác). skip_heal = tỉ lệ máu hồi khi bấm Bỏ qua.
const XP: Dictionary = {
	"need_base": 10, "need_per_level": 6, "choices": 3, "skip_heal": 0.25,
	"orb": {"default": 3, "titan": 40}, "orb_lifetime": 45.0, "magnet_base": 3.0, "orb_speed": 16.0,
}

## Kho nâng cấp. Khoá = tên kho: "shared" (dùng chung); M38/M39 thêm "gun:<id>" và "sword".
## Mỗi thẻ: cat ("gun"/"survive"/"util": màu + nhãn trên thẻ), stat (khoá thống kê), per (giá trị mỗi bậc), max (số bậc tối đa), kind ("mult": cộng vào hệ số 1+x; "add": cộng thẳng).
const UPGRADES: Dictionary = {
	"gun:pistol": {
		"pistol_steady": {"name": "Nhịp ổn định", "cat": "gun", "desc": "-20% độ lệch cộng thêm mỗi phát (lỗi Giật theo nhịp)", "stat": "rhythm_per_shot", "per": -0.2, "max": 3, "kind": "mult"},
		"pistol_recover": {"name": "Hồi tay", "cat": "gun", "desc": "+30% tốc độ giảm lệch (lỗi Giật theo nhịp)", "stat": "rhythm_recover", "per": 0.3, "max": 3, "kind": "mult"},
		"pistol_pierce": {"name": "Đạn xuyên", "cat": "gun", "desc": "Đạn súng lục xuyên thêm 1 mục tiêu (còn 70% sát thương)", "stat": "pistol_pierce", "per": 1.0, "max": 2, "kind": "add"},
		"pistol_heavy": {"name": "Nòng nặng", "cat": "gun", "desc": "+20% sát thương súng lục", "stat": "pistol_damage", "per": 0.2, "max": 3, "kind": "mult"},
	},
	# M38: thẻ riêng của shotgun / bắn tỉa / pháo, đổi cách chơi (không chỉ cộng %). "effect" = chữ hiện thay cho "+x%".
	# Khoá stat có tiền tố id súng; main chép mọi stat của kho "gun:*" vào combat.weapon_mods. Thẻ không gỡ lỗi gốc.
	"sword": {
		"sword_pierce": {"name": "Mũi nhọn xuyên giáp", "cat": "sword", "desc": "Chém trúng bot đang đỡ đòn: bot vẫn nhận 50% sát thương mỗi bậc (lỗi dội lại vẫn xảy ra)", "stat": "sword_pierce", "per": 0.5, "max": 2, "kind": "add", "effect": "+50% xuyên đỡ"},
		"sword_riposte": {"name": "Nhịp phản đòn", "cat": "sword", "desc": "Parry thành công: cú chém kế tiếp trong 2 s gây +80% sát thương và không bị dội", "stat": "sword_riposte", "per": 1.0, "max": 1, "kind": "add", "effect": "Phản đòn +80%"},
		"sword_lunge": {"name": "Lưỡi kiếm lao", "cat": "sword", "desc": "Giữ chém: lao tới bot gần nhất trong 6 m phía trước rồi chém. Hồi 3 s, lao xong hở 0.3 s", "stat": "sword_lunge", "per": 1.0, "max": 1, "kind": "add", "effect": "Lao tới 6 m"},
		"sword_whirl": {"name": "Vòng chém", "cat": "sword", "desc": "Cú chém thứ ba liên tiếp quét cả vòng 360 độ trong 2.5 m, 60% sát thương, hất lùi bot trúng", "stat": "sword_whirl", "per": 1.0, "max": 1, "kind": "add", "effect": "Quét 360 độ"},
	},
	"gun:shotgun": {
		"shotgun_airkick": {"name": "Cú đá đôi", "cat": "gun", "desc": "Phát bắn khi đang bay trên không: +25% sát thương mỗi bậc (bắn xuống đất để bật lên rồi bắn tiếp)", "stat": "shotgun_airkick", "per": 0.25, "max": 3, "kind": "add", "effect": "+25% khi bay"},
		"shotgun_shockwave": {"name": "Sóng xung kích", "cat": "gun", "desc": "Mỗi phát bắn hất lùi mọi bot trong 4 m phía trước", "stat": "shotgun_shockwave", "per": 1.0, "max": 1, "kind": "add", "effect": "Hất lùi bot"},
		"shotgun_ricochet": {"name": "Đạn dội", "cat": "gun", "desc": "Mảnh đạn trúng tường nảy một lần, gây 60% sát thương", "stat": "shotgun_ricochet", "per": 1.0, "max": 1, "kind": "add", "effect": "Nảy 1 lần"},
		"shotgun_airreload": {"name": "Nạp bằng cú nhảy", "cat": "gun", "desc": "Cứ mỗi 2 s bay trên không thì tự nạp 1 viên", "stat": "shotgun_airreload", "per": 1.0, "max": 1, "kind": "add", "effect": "+1 viên / 2 s bay"},
	},
	"gun:sniper": {
		"sniper_overcharge": {"name": "Nạp thêm", "cat": "gun", "desc": "Giữ thêm 0.6 s sau khi đủ nạp: siêu đạn +100% sát thương, xuyên mọi mục tiêu. Thả sau khi đủ nạp vẫn nổ phát thường", "stat": "sniper_overcharge", "per": 1.0, "max": 1, "kind": "add", "effect": "Siêu đạn"},
		"sniper_mark": {"name": "Tia đánh dấu", "cat": "gun", "desc": "Bot bị tia laser quét trúng lúc nạp bị đánh dấu: +40% sát thương từ mọi nguồn trong 5 s", "stat": "sniper_mark", "per": 1.0, "max": 1, "kind": "add", "effect": "+40% sát thương nhận"},
		"sniper_chain": {"name": "Săn liên hoàn", "cat": "gun", "desc": "Hạ gục bot bằng bắn tỉa: 3 s sau đó phát kế tiếp nổ ngay, không cần nạp ngắm", "stat": "sniper_chain", "per": 1.0, "max": 1, "kind": "add", "effect": "Bắn liền 3 s"},
		"sniper_slide": {"name": "Nạp trượt", "cat": "gun", "desc": "Khi đang trượt: không bị chậm lúc nạp và nạp nhanh hơn 15% mỗi bậc", "stat": "sniper_slide", "per": 0.15, "max": 2, "kind": "add", "effect": "Nạp trượt nhanh hơn"},
	},
	"gun:launcher": {
		"launcher_jump": {"name": "Nhảy nổ", "cat": "gun", "desc": "Vụ nổ hất chính bạn mạnh gấp 1.8 lần (rocket jump), sát thương tự chịu giữ nguyên", "stat": "launcher_jump", "per": 1.0, "max": 1, "kind": "add", "effect": "Hất bản thân x1.8"},
		"launcher_cluster": {"name": "Chùm ba", "cat": "gun", "desc": "Mỗi phát bắn ra 3 tên lửa tỏa ra, mỗi quả 45% sát thương và 70% bán kính nổ", "stat": "launcher_cluster", "per": 1.0, "max": 1, "kind": "add", "effect": "3 tên lửa"},
		"launcher_sticky": {"name": "Mìn dính", "cat": "gun", "desc": "Tên lửa trúng bot thì dính vào rồi nổ sau 1 s", "stat": "launcher_sticky", "per": 1.0, "max": 1, "kind": "add", "effect": "Dính, nổ sau 1 s"},
		"launcher_chain": {"name": "Nổ dây chuyền", "cat": "gun", "desc": "Bot chết vì vụ nổ nổ thêm một vụ nhỏ (50% sát thương, 50% bán kính), tối đa 3 lần liên tiếp", "stat": "launcher_chain", "per": 1.0, "max": 1, "kind": "add", "effect": "Nổ lan"},
	},
	"shared": {
		"damage": {"name": "Đạn mạnh", "cat": "gun", "desc": "+12% sát thương súng mỗi bậc", "stat": "damage", "per": 0.12, "max": 5, "kind": "mult"},
		"fire_rate": {"name": "Bắn nhanh", "cat": "gun", "desc": "+10% tốc độ bắn mỗi bậc", "stat": "fire_rate", "per": 0.10, "max": 5, "kind": "mult"},
		"mag": {"name": "Băng đạn lớn", "cat": "gun", "desc": "+20% cỡ băng đạn mỗi bậc", "stat": "mag", "per": 0.20, "max": 4, "kind": "mult"},
		"reload": {"name": "Nạp nhanh", "cat": "gun", "desc": "+15% tốc độ nạp mỗi bậc", "stat": "reload", "per": 0.15, "max": 4, "kind": "mult"},
		"max_hp": {"name": "Giáp dày", "cat": "survive", "desc": "+15 máu tối đa mỗi bậc", "stat": "max_hp", "per": 15.0, "max": 5, "kind": "add"},
		"regen": {"name": "Tự hồi phục", "cat": "survive", "desc": "+0.5 máu mỗi giây mỗi bậc", "stat": "regen", "per": 0.5, "max": 4, "kind": "add"},
		"speed": {"name": "Chân nhanh", "cat": "survive", "desc": "+4% tốc độ chạy mỗi bậc", "stat": "speed", "per": 0.04, "max": 4, "kind": "mult"},
		"magnet": {"name": "Nam châm XP", "cat": "util", "desc": "+2.5 m tầm hút XP mỗi bậc", "stat": "magnet", "per": 2.5, "max": 4, "kind": "add"},
		"xp_gain": {"name": "Học nhanh", "cat": "util", "desc": "+10% XP nhận được mỗi bậc", "stat": "xp_gain", "per": 0.10, "max": 5, "kind": "mult"},
		"stamina": {"name": "Dẻo dai", "cat": "util", "desc": "+20% tốc độ hồi stamina dash mỗi bậc", "stat": "stamina", "per": 0.20, "max": 3, "kind": "mult"},
	},
}

## Chế độ Vô Tận (M34). Bản đồ lưới `grid`x`grid` ô vuông `cell` m (6x50 = 300 m, gấp ~5 lần Khu phố về diện tích).
## Chỉ tiêu hạ bot mỗi tầng = quota_base + quota_per_floor*(tầng-1). Số bot sống cùng lúc = cap_base + cap_per_floor*(tầng-1), tối đa cap_max.
## Bot sinh ở vòng `band` m quanh người chơi; xa hơn `despawn_dist` m thì bị gỡ (không tính hạ). Mọi con số đo/chỉnh ở đây.
const ENDLESS: Dictionary = {
	"cell": 50.0, "grid": 6, "inset": 8.0, "nav_cell": 0.5,
	"building_h_min": 12.0, "building_h_max": 30.0,
	"quota_base": 15, "quota_per_floor": 5,
	"cap_base": 6, "cap_per_floor": 1, "cap_max": 14,
	"spawn_interval": 1.2, "band": Vector2(40.0, 80.0), "despawn_dist": 130.0, "prune_interval": 1.0,
	"titan_every": 5, "heal_on_floor": 0.3, "portal_radius": 4.0, "start_clear": 35.0,
}

## Tập luyện (M41) trên bản đồ Vô Tận tầng `floor`. Khu thử: các ô `slots` = [loại bot, độ lệch (x, z) so với chỗ xuất phát]; bot chết thì
## hồi sinh đúng chỗ cũ sau `respawn_time` giây. Titan (phím T) đặt ở `titan_offset`. Người chơi chết thì hồi sinh ở chỗ xuất phát sau `player_respawn` giây.
const TRAINING: Dictionary = {
	"floor": 1, "respawn_time": 2.0, "player_respawn": 1.5, "bot_wave": 1,
	"slots": [["swordsman", Vector2(-8.0, 14.0)], ["gunner", Vector2(0.0, 16.0)], ["bomber", Vector2(8.0, 14.0)]],
	"titan_offset": Vector2(0.0, 24.0),
}
