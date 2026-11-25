extends RefCounted
## Số cân bằng chiến đấu, vũ khí, lỗi súng, thẻ-hiệu ứng, vàng, vật nhặt (dữ liệu thuần).
## Chỉ là dữ liệu: `Global` nạp lại các hằng này nên mã khác vẫn dùng `Global.TÊN`. Không tham chiếu Global ở đây.

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
		"range": 80.0, "recoil": 1.0, "draw": 0.25, "sfx": "shot", "flaw": "rhythm_recoil"},
	"shotgun": {"name": "Shotgun", "kind": "pellets", "mag": 2, "cooldown": 0.6, "reload": 1.8, "damage": 12.0,
		"pellets": 8, "spread_deg": 5.0, "falloff_range": 18.0, "min_falloff": 0.2,
		"range": 40.0, "recoil": 3.0, "draw": 0.4, "sfx": "shotgun", "flaw": "self_knockback"},
	"launcher": {"name": "Pháo nổ", "kind": "explosive", "mag": 2, "cooldown": 0.9, "reload": 2.2, "damage": 60.0,
		"projectile_speed": 38.0, "gravity": 6.0, "blast_radius": 4.5, "min_falloff": 0.4,
		"knockback": 16.0, "self_damage_mult": 0.15, "stagger": 0.6, "life": 4.0,
		"range": 80.0, "recoil": 0.0, "draw": 0.5, "sfx": "launcher", "flaw": "self_blast"},
	"sniper": {"name": "Bắn tỉa", "kind": "hitscan", "mag": 3, "cooldown": 1.1, "reload": 2.2, "damage": 80.0,
		"headshot_mult": 2.0, "headshot_height": 1.5, "pierce": 1, "pierce_mult": 0.6,
		"range": 200.0, "recoil": 1.5, "draw": 0.5, "zoom_fov": 35.0, "sfx": "sniper", "flaw": "charge_shot"},
}

## Lỗi riêng của từng súng (M36; chỉ bật ở Vô Tận). Mỗi súng trong WEAPONS có "flaw": id; con số + chữ hiện trên HUD ở đây.
## Nâng cấp chỉ làm nhẹ lỗi (hệ số trên các số này), không bao giờ gỡ hẳn.
## rhythm_recoil (súng lục): mỗi phát cộng per_shot_deg độ lệch (tối đa max_deg), hồi recover_deg_per_s độ/giây: bắn thong thả thì chuẩn, bắn dồn thì lệch.
const FLAWS: Dictionary = {
	"rhythm_recoil": {"name": "Giật theo nhịp", "hint": "Bắn dồn thì tia đạn lệch; bắn thong thả mới chuẩn",
		"per_shot_deg": 0.6, "max_deg": 6.0, "recover_deg_per_s": 8.0},
	"self_knockback": {"name": "Giật bật người", "hint": "Mỗi phát bắn đẩy bạn ngược hướng ngắm",
		"speed": 6.0, "air_mult": 1.6},
	"charge_shot": {"name": "Nạp ngắm", "hint": "Giữ chuột 0.8 s mới nổ, đi chậm và lộ tia laser",
		"charge_time": 0.8, "move_mult": 0.5},
	"self_blast": {"name": "Tự chịu nổ", "hint": "Vụ nổ gây 60% sát thương lên chính bạn",
		"self_damage_mult": 0.6},
	# Lỗi của kiếm (M39): chém trúng bot đang đỡ đòn thì kiếm bị dội lại. Chỉ bật ở Vô Tận, chỉ áp lên người chơi.
	"guard_rebound": {"name": "Phá thế đỡ", "hint": "Chém trúng bot đang đỡ: kiếm bị dội, khựng thêm 0.4 s và bạn bị đẩy lùi",
		"extra_stagger": 0.4, "push": 6.0},
}

## Thông số thẻ riêng của súng (M38; chỉnh tại đây).
const PERKS: Dictionary = {
	"shockwave_range": 4.0, "shockwave_push": 10.0, "shockwave_cone": 0.5,   # cone = cos góc, 0.5 ~ 60 độ
	"ricochet_mult": 0.6,
	"airreload_secs": 2.0,
	"overcharge_extra": 0.6, "overcharge_damage": 2.0,
	"mark_mult": 1.4, "mark_time": 5.0, "chain_window": 3.0,
	"launcher_jump_mult": 1.8,
	"cluster_count": 3, "cluster_spread_deg": 7.0, "cluster_damage": 0.45, "cluster_radius": 0.7,
	"sticky_fuse": 1.0,
	"chain_damage": 0.5, "chain_radius": 0.5, "chain_depth": 3,
	# Kiếm (M39)
	"riposte_window": 2.0, "riposte_mult": 1.8,
	"lunge_range": 6.0, "lunge_cd": 3.0, "lunge_exposed": 0.3, "lunge_stop": 1.6, "lunge_cone": 0.3,
	"whirl_every": 3, "whirl_radius": 2.5, "whirl_damage": 0.6, "whirl_push": 8.0, "combo_window": 1.5,
}

## Vàng (M37): tiền meta giữ lại giữa các lượt (lưu trong savegame). Qua tầng t: floor_base + floor_per_floor*t; mỗi bot hạ: per_kill; Titan: titan.
## prices: giá mở khoá súng ở cửa hàng (súng lục miễn phí).
const GOLD: Dictionary = {
	"floor_base": 8, "floor_per_floor": 4, "per_kill": 1, "titan": 30,
	"prices": {"shotgun": 150, "sniper": 300, "launcher": 500},
}

## self_knockback (shotgun): mỗi phát đẩy người chơi ngược hướng ngắm `speed` m/s (x`air_mult` khi đang trên không; ngắm xuống thì bật lên).
## charge_shot (bắn tỉa): giữ `charge_time` s mới nổ, thả sớm thì huỷ; trong lúc nạp đi chậm còn `move_mult` và hiện tia laser.
## self_blast (pháo nổ): vụ nổ gây `self_damage_mult` sát thương lên chính người chơi (mặc định súng là 0.15).
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
