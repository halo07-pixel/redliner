extends SceneTree
## M36: khung lỗi riêng của súng + lỗi "giật theo nhịp" của súng lục + kho thẻ riêng súng lục.
##   timeout 280 godot --headless --path . -s tools/tests/test_m36.gd

var failures: int = 0
var G


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://test_m36.cfg"
	G.load_save()
	var Flaws = load("res://scripts/gun_flaws.gd")
	var F: Dictionary = G.FLAWS["rhythm_recoil"]

	print("[khung lỗi: dữ liệu]")
	_check(G.WEAPONS["pistol"]["flaw"] == "rhythm_recoil" and G.FLAWS.has("rhythm_recoil"), "súng lục có lỗi Giật theo nhịp")
	_check(F["per_shot_deg"] == 0.6 and F["max_deg"] == 6.0 and F["recover_deg_per_s"] == 8.0, "số liệu 0.6° / tối đa 6° / hồi 8°/s")
	var all_have: bool = true
	for id in G.WEAPONS:
		var fid: String = String(G.WEAPONS[id].get("flaw", ""))
		all_have = all_have and (fid == "" or G.FLAWS.has(fid))
	_check(all_have, "mọi lỗi được tham chiếu đều có dữ liệu")

	print("[lỗi giật theo nhịp: logic thuần]")
	var fl = Flaws.new()
	fl.rng.seed = 11
	_check(fl.flaw_of("pistol") == "" and fl.spread("pistol") == 0.0, "chưa bật (enabled=false): không có lỗi")
	fl.on_shot("pistol")
	_check(fl.spread("pistol") == 0.0 and fl.aim("pistol", Vector3.FORWARD) == Vector3.FORWARD, "chưa bật: bắn không cộng lệch, hướng nguyên")
	fl.enabled = true
	_check(fl.flaw_of("pistol") == "rhythm_recoil" and fl.flaw_of("shotgun") == "self_knockback", "bật: súng lục có lỗi giật theo nhịp, shotgun có lỗi giật bật người (M37)")
	_check(fl.aim("pistol", Vector3.FORWARD) == Vector3.FORWARD, "phát đầu: chính xác tuyệt đối")
	for i in 3:
		fl.on_shot("pistol")
	_check(is_equal_approx(fl.spread("pistol"), 1.8), "3 phát liên tiếp: lệch 1.8° (%.2f)" % fl.spread("pistol"))
	for i in 30:
		fl.on_shot("pistol")
	_check(is_equal_approx(fl.spread("pistol"), 6.0) and is_equal_approx(fl.max_spread("pistol"), 6.0), "spam: kẹt ở mức tối đa 6°")
	fl.tick(0.5)
	_check(is_equal_approx(fl.spread("pistol"), 2.0), "hồi 0.5 s: giảm 4° còn 2°")
	fl.tick(5.0)
	_check(fl.spread("pistol") == 0.0, "nghỉ đủ lâu: về 0, không âm")
	# phân bố hướng lệch: trong nón, và thực sự lệch
	for i in 10:
		fl.on_shot("pistol")
	var worst: float = 0.0
	var moved: int = 0
	var s0: float = fl.spread("pistol")
	for i in 400:
		var d: Vector3 = fl.aim("pistol", Vector3(0.3, 0.2, -1.0).normalized())
		var ang: float = rad_to_deg(d.angle_to(Vector3(0.3, 0.2, -1.0).normalized()))
		worst = maxf(worst, ang)
		if ang > 0.2:
			moved += 1
		_check_unit(d)
	_check(worst <= s0 + 0.01, "400 phát: không lệch quá %.1f° (tệ nhất %.2f°)" % [s0, worst])
	_check(moved > 300, "đa số phát lệch thấy được (%d/400 > 0.2°)" % moved)

	print("[nâng cấp làm nhẹ lỗi]")
	var fm = Flaws.new()
	fm.enabled = true
	fm.mods = {"rhythm_per_shot_mult": 0.4, "rhythm_recover_mult": 1.9}
	fm.on_shot("pistol")
	_check(is_equal_approx(fm.spread("pistol"), 0.24), "Nhịp ổn định x3: mỗi phát +0.24°")
	fm.tick(0.01)
	_check(is_equal_approx(fm.spread("pistol"), 0.24 - 8.0 * 1.9 * 0.01), "Hồi tay x3: hồi nhanh x1.9")
	var fz = Flaws.new()
	fz.enabled = true
	fz.mods = {"rhythm_per_shot_mult": 0.4}
	for i in 100:
		fz.on_shot("pistol")
	_check(fz.spread("pistol") > 0.0 and is_equal_approx(fz.spread("pistol"), 6.0), "dù nâng cấp tối đa, spam vẫn lên mức tối đa: lỗi không bị gỡ")

	print("[kho thẻ súng lục]")
	var Up = load("res://scripts/upgrades.gd")
	var pool: Dictionary = G.UPGRADES["gun:pistol"]
	_check(pool.size() == 4, "kho gun:pistol có 4 thẻ")
	var LU = load("res://scripts/level_up_ui.gd")
	_check(LU.effect_text(pool["pistol_steady"], 2) == "-40%" and LU.effect_text(pool["pistol_recover"], 1) == "+30%", "chữ thẻ: giảm hiện -40%, tăng hiện +30%")
	var rp: Node = load("res://scripts/run_progress.gd").new()
	root.add_child(rp)
	_check(rp.pools == ["shared", "sword", "gun:pistol"], "mặc định: kho chung + súng lục")
	rp.set_weapon_pool("shotgun")
	_check(rp.pools == ["shared", "sword", "gun:shotgun"], "cầm shotgun (M38 có kho riêng): kho chung + kiếm + kho shotgun")
	rp.set_weapon_pool("khong_co")
	_check(rp.pools == ["shared", "sword"], "súng không có kho: kho chung + kiếm")
	rp.set_weapon_pool("pistol")
	_check(rp.pools == ["shared", "sword", "gun:pistol"], "cầm lại súng lục: kho súng lục quay lại")
	var avail: Array = Up.available(rp.pools, {}).map(func(c): return c["id"])
	_check(avail.has("pistol_steady") and avail.has("damage") and avail.size() == 18, "rút từ 18 thẻ (10 chung + 4 kiếm + 4 súng lục)")
	rp.taken = {"pistol_pierce": 2, "pistol_steady": 3}
	_check(not Up.available(rp.pools, rp.taken).map(func(c): return c["id"]).has("pistol_pierce"), "thẻ đạt tối đa không còn để rút")
	_check(is_equal_approx(rp.stat("rhythm_per_shot"), 0.4) and rp.stat("pistol_pierce") == 2.0 and is_equal_approx(rp.stat("pistol_damage"), 1.0), "thống kê: 0.4 / +2 / x1")
	rp.queue_free()

	print("[Combat: lỗi trong bắn thật]")
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.map_id = "yard"
	arena.bake_nav = false
	root.add_child(arena)
	var pl: Node3D = load("res://scenes/player.tscn").instantiate()
	pl.use_input = false
	root.add_child(pl)
	pl.global_position = Vector3(0.0, 0.2, 20.0)
	await _frames(15)
	var combat = pl.combat
	var sp_log: Array = []
	combat.flaw_changed.connect(func(d, m): sp_log.append([d, m]))
	_check(not combat.flaws.enabled, "mặc định (ngoài Vô Tận): lỗi tắt, bắn như cũ")
	combat.flaws.enabled = true
	combat.weapon_mods = {}
	combat.switch_to("pistol")
	combat.refill()
	var shots: Array = []
	combat.shot_fired.connect(func(from, to): shots.append([from, to]))
	for i in 4:
		combat._shot_cd = 0.0
		combat.want_shoot = true
		await _frames(1)
		combat.want_shoot = false
		await _frames(6)   # bắn dồn: nghỉ ngắn nên lệch dồn dần
	_check(shots.size() >= 3, "bắn được %d phát" % shots.size())
	_check(sp_log.size() >= 3 and sp_log[sp_log.size() - 1][1] == 6.0, "flaw_changed phát khi lệch đổi (%d lần, max 6°)" % sp_log.size())
	var peak: float = 0.0
	for e in sp_log:
		peak = maxf(peak, e[0])
	_check(peak > 0.5, "độ lệch dồn lên khi bắn dồn (đỉnh %.2f°)" % peak)
	await create_timer(1.0).timeout
	_check(combat.flaws.spread("pistol") < 0.1, "nghỉ 1 s: lệch hồi về ~0")
	# hệ số riêng theo súng
	combat.weapon_mods = {"pistol_damage_mult": 1.4, "pistol_pierce": 2.0}
	_check(is_equal_approx(combat._wmod("damage_mult", 1.0), 1.4) and combat._wmod("pierce", 0.0) == 2.0, "weapon_mods theo súng lục đang cầm")
	combat.switch_to("shotgun")
	await _frames(2)
	if combat.weapon == "shotgun":
		_check(combat._wmod("damage_mult", 1.0) == 1.0, "đổi sang shotgun: hệ số súng lục không áp")
		_check(not sp_log.is_empty() and sp_log[sp_log.size() - 1] == [0.0, 0.0], "shotgun không có độ lệch: flaw_changed về 0/0 để HUD ẩn vòng")
	# Đạn xuyên + sát thương thật: 2 bia thẳng hàng trước mặt
	combat.switch_to("pistol")
	combat.flaws.enabled = false   # tách lỗi lệch khỏi phép đo sát thương
	var d1: Node = load("res://scripts/enemy_dummy.gd").new()
	var d2: Node = load("res://scripts/enemy_dummy.gd").new()
	d1.position = Vector3(0.0, 0.0, 20.0 - 8.0)
	d2.position = Vector3(0.0, 0.0, 20.0 - 14.0)
	d1.rotation.y = PI
	d2.rotation.y = PI
	arena.add_child(d1)
	arena.add_child(d2)
	await _frames(5)
	d1.hurtbox.setup(G.TEAM_ENEMY, 1000.0, d1.parry)
	d2.hurtbox.setup(G.TEAM_ENEMY, 1000.0, d2.parry)
	combat.refill()
	combat.weapon_mods = {}
	combat._shot_cd = 0.0
	combat._shoot()
	await _frames(2)
	var base1: float = 1000.0 - d1.hurtbox.health
	_check(base1 > 1.0 and is_equal_approx(d2.hurtbox.health, 1000.0), "không thẻ: đạn trúng bia gần, không xuyên (%.0f dmg)" % base1)
	d1.hurtbox.health = 1000.0
	combat.weapon_mods = {"pistol_damage_mult": 1.2, "pistol_pierce": 1.0}
	combat._shot_cd = 0.0
	combat._shoot()
	await _frames(2)
	var dm1: float = 1000.0 - d1.hurtbox.health
	var dm2: float = 1000.0 - d2.hurtbox.health
	_check(is_equal_approx(dm1, base1 * 1.2), "Nòng nặng: bia gần nhận x1.2 (%.1f)" % dm1)
	_check(dm2 > 0.0 and is_equal_approx(dm2, dm1 * 0.7), "Đạn xuyên: bia xa nhận 70%% (%.1f / %.1f)" % [dm2, dm1])
	pl.queue_free()
	arena.queue_free()
	await _frames(3)

	print("[Tích hợp main (Vô Tận)]")
	G.set_mode("endless")
	G.start_wave = 1
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(15)
	main._start_mode()
	await _frames(3)
	_check(main.player.combat.flaws.enabled, "Vô Tận: lỗi súng bật")
	main.progress.taken = {"pistol_steady": 2, "pistol_recover": 1, "pistol_pierce": 1, "pistol_heavy": 2}
	main._apply_upgrades()
	var cm = main.player.combat
	_check(is_equal_approx(cm.flaws.mods["rhythm_per_shot_mult"], 0.6) and is_equal_approx(cm.flaws.mods["rhythm_recover_mult"], 1.3), "áp thẻ: 0.6 / 1.3 lên lỗi")
	_check(is_equal_approx(cm.weapon_mods["pistol_damage_mult"], 1.4) and cm.weapon_mods["pistol_pierce"] == 1.0, "áp thẻ: sát thương x1.4, xuyên +1")
	cm._shot_cd = 0.0
	cm._shoot()
	await _frames(3)
	_check(main.hud._spread_ring != null and main.hud._flaw_label.text.contains("Giật theo nhịp"), "HUD: có vòng độ lệch + chữ tên lỗi")
	main.player.hurtbox.health = main.player.hurtbox.max_health
	main.queue_free()
	await _frames(10)
	G.set_mode("survival")
	var main2 = load("res://scenes/main.tscn").instantiate()
	main2.autostart_waves = false
	root.add_child(main2)
	await _frames(15)
	_check(not main2.player.combat.flaws.enabled and main2.hud._spread_ring == null, "Sinh tồn: không có lỗi súng, không có vòng")
	main2.queue_free()
	await _frames(10)

	print("---")
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)


func _check_unit(d: Vector3) -> void:
	if absf(d.length() - 1.0) > 0.001:
		failures += 1
		printerr("  FAIL  hướng không chuẩn hoá: ", d)
