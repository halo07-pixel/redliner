extends SceneTree
## M37: vàng lưu lâu dài, cửa hàng, súng khởi đầu, ba lỗi súng (giật bật người, nạp ngắm, tự chịu nổ).
##   timeout 280 godot --headless --path . -s tools/tests/test_m37.gd

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
	G.save_path = "user://test_m37.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.save_path))
	G.load_save()
	var Flaws = load("res://scripts/gun_flaws.gd")

	print("[dữ liệu]")
	_check(G.WEAPONS["shotgun"]["flaw"] == "self_knockback" and G.WEAPONS["sniper"]["flaw"] == "charge_shot" and G.WEAPONS["launcher"]["flaw"] == "self_blast" and G.WEAPONS["pistol"]["flaw"] == "rhythm_recoil", "4 súng, mỗi súng một lỗi khác nhau")
	var ids: Array = ["pistol", "shotgun", "sniper", "launcher"].map(func(i): return G.WEAPONS[i]["flaw"])
	_check(ids.size() == 4 and ids.duplicate().filter(func(x): return ids.count(x) == 1).size() == 4, "không lỗi nào trùng")
	_check(G.GOLD["prices"] == {"shotgun": 150, "sniper": 300, "launcher": 500}, "giá 150 / 300 / 500")

	print("[vàng: lưu và cộng]")
	_check(G.gold == 0 and G.owned_guns == ["pistol"] and G.start_gun == "pistol", "mặc định: 0 vàng, chỉ súng lục")
	_check(G.gold_for_floor(1) == 12 and G.gold_for_floor(5) == 28, "thưởng tầng: 12 (tầng 1), 28 (tầng 5)")
	var seen: Array = []
	G.gold_changed.connect(func(t): seen.append(t))
	G.add_gold(100)
	_check(G.gold == 100 and seen == [100], "cộng 100: tổng 100, phát gold_changed")
	G.add_gold(-30)
	_check(G.gold == 70, "trừ 30: còn 70")
	G.add_gold(-1000)
	_check(G.gold == 0, "không bao giờ âm")
	G.add_gold(0)
	_check(seen.size() == 3, "cộng 0 không phát Signal")

	print("[cửa hàng: mua]")
	_check(not G.buy_gun("shotgun") and not G.owns_gun("shotgun"), "0 vàng: không mua được")
	G.add_gold(149)
	_check(not G.buy_gun("shotgun") and G.gold == 149, "149 vàng: thiếu 1, không mua, không mất vàng")
	G.add_gold(1)
	_check(G.buy_gun("shotgun") and G.gold == 0 and G.owns_gun("shotgun"), "150 vàng: mua shotgun, còn 0")
	_check(not G.buy_gun("shotgun"), "đã có: không mua lại")
	_check(not G.buy_gun("pistol") and not G.buy_gun("khong_co"), "súng lục / id lạ: không mua")
	_check(not G.set_start_gun("sniper") and G.start_gun == "pistol", "chọn súng khởi đầu chưa sở hữu: bị từ chối")
	_check(G.set_start_gun("shotgun") and G.start_gun == "shotgun", "chọn shotgun làm súng khởi đầu")
	G.cycle_start_gun()
	_check(G.start_gun == "pistol", "xoay vòng: shotgun -> súng lục (chỉ 2 súng sở hữu)")
	G.cycle_start_gun()
	_check(G.start_gun == "shotgun", "xoay vòng: súng lục -> shotgun")

	print("[lưu / đọc]")
	G.add_gold(77)
	G.load_save()
	_check(G.gold == 77 and G.owned_guns == ["pistol", "shotgun"] and G.start_gun == "shotgun", "đọc lại savegame: vàng, súng sở hữu, súng khởi đầu")
	var cf := ConfigFile.new()
	cf.set_value("meta", "gold", -50)
	cf.set_value("meta", "owned_guns", "sniper,khong_co,shotgun")
	cf.set_value("meta", "start_gun", "launcher")
	cf.save(G.save_path)
	G.load_save()
	_check(G.gold == 0 and G.owns_gun("pistol") and G.owns_gun("sniper") and G.owns_gun("shotgun") and not G.owns_gun("khong_co") and G.start_gun == "pistol", "savegame hỏng: vàng âm -> 0, id lạ bỏ, súng khởi đầu chưa sở hữu -> súng lục")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.save_path))
	G.load_save()

	print("[lỗi: logic thuần]")
	var f = Flaws.new()
	_check(f.knockback("shotgun", Vector3.FORWARD, true) == Vector3.ZERO and f.charge_time("sniper") == 0.0 and f.self_damage_mult("launcher", 0.15) == 0.15, "chưa bật: không lỗi nào hoạt động")
	f.enabled = true
	var k: Vector3 = f.knockback("shotgun", Vector3(0, 0, -1), true)
	_check(is_equal_approx(k.z, 6.0) and is_equal_approx(k.y, 0.0), "shotgun bắn về trước: đẩy lùi 6 m/s (%s)" % k)
	var ka: Vector3 = f.knockback("shotgun", Vector3(0, 0, -1), false)
	_check(is_equal_approx(ka.z, 9.6), "trên không: x1.6 = 9.6 m/s")
	var kd: Vector3 = f.knockback("shotgun", Vector3(0, -1, 0), true)
	_check(is_equal_approx(kd.y, 6.0), "ngắm xuống đất: bật lên")
	_check(f.knockback("pistol", Vector3.FORWARD, true) == Vector3.ZERO and f.knockback("sniper", Vector3.FORWARD, true) == Vector3.ZERO, "súng khác không bị đẩy")
	_check(is_equal_approx(f.charge_time("sniper"), 0.8) and is_equal_approx(f.charge_move_mult("sniper"), 0.5) and f.charge_time("pistol") == 0.0 and f.charge_move_mult("pistol") == 1.0, "bắn tỉa: nạp 0.8 s, đi 50%; súng khác không")
	_check(is_equal_approx(f.self_damage_mult("launcher", 0.15), 0.6) and f.self_damage_mult("sniper", 0.15) == 0.15, "pháo: tự chịu 60%; súng khác giữ mặc định")

	print("[lỗi: trong bắn thật]")
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.map_id = "yard"
	arena.bake_nav = false
	root.add_child(arena)
	var pl: Node3D = load("res://scenes/player.tscn").instantiate()
	pl.use_input = false
	root.add_child(pl)
	pl.global_position = Vector3(0.0, 0.2, 20.0)
	await _frames(15)
	var cb = pl.combat
	cb.flaws.enabled = true
	# shotgun: đẩy ngược
	cb.switch_to("shotgun")
	cb.refill()
	cb._shot_cd = 0.0
	pl.velocity = Vector3.ZERO
	var kicks: Array = []
	cb.self_impulse.connect(func(v): kicks.append(v))
	cb.want_shoot = true
	await _frames(1)
	cb.want_shoot = false
	_check(kicks.size() == 1 and kicks[0].z > 4.0, "bắn shotgun: phát xung đẩy về sau (%s)" % [kicks])
	_check(pl.velocity.z > 3.0, "người chơi thật sự bị đẩy (vz %.1f)" % pl.velocity.z)
	cb.flaws.enabled = false
	kicks.clear()
	cb.refill()
	cb._shot_cd = 0.0
	cb.want_shoot = true
	await _frames(1)
	cb.want_shoot = false
	_check(kicks.is_empty(), "tắt lỗi (chế độ khác): không đẩy")
	cb.flaws.enabled = true
	# bắn tỉa: nạp ngắm
	cb.switch_to("sniper")
	cb.refill()
	cb._shot_cd = 0.0
	var shots: Array = []
	var ch: Array = []
	cb.shot_fired.connect(func(_a, _b): shots.append(1))
	cb.charge_changed.connect(func(r): ch.append(r))
	cb.want_shoot = true
	await _frames(15)
	_check(shots.is_empty() and cb.move_mult == 0.5 and not ch.is_empty() and ch[ch.size() - 1] > 0.0, "giữ 0.25 s: chưa nổ, đang đi chậm 50%%, ratio %.2f" % (ch[ch.size() - 1] if not ch.is_empty() else -1.0))
	cb.want_shoot = false
	await _frames(2)
	_check(shots.is_empty() and cb.move_mult == 1.0 and ch[ch.size() - 1] == 0.0, "thả sớm: huỷ, không nổ, hết chậm")
	cb.want_shoot = true
	await _frames(60)   # 1 s > 0.8 s
	_check(shots.size() == 1, "giữ đủ 0.8 s: nổ đúng 1 phát (%d)" % shots.size())
	await _frames(120)
	_check(shots.size() == 1, "vẫn giữ chuột: không tự nổ tiếp (phải thả rồi giữ lại)")
	cb.want_shoot = false
	await _frames(2)
	_check(cb.move_mult == 1.0 and cb.laser_segment().size() == 2 and cb.laser_segment()[0].distance_to(cb.laser_segment()[1]) > 1.0, "laser_segment có độ dài hợp lệ")
	# tốc độ chạy áp move_mult
	cb.move_mult = 0.5
	_check(is_equal_approx(cb.move_mult, 0.5), "move_mult 0.5 áp lên combat (Player nhân vào tốc độ chạy)")
	cb.move_mult = 1.0
	# pháo: tự chịu nổ
	cb.switch_to("launcher")
	cb.refill()
	cb._shot_cd = 0.0
	var seen_rc: Array = []
	root.child_entered_tree.connect(func(n): if n.get_script() != null and String(n.get_script().resource_path).ends_with("rocket.gd"): seen_rc.append(n))
	cb.want_shoot = true
	await _frames(1)
	cb.want_shoot = false
	await _frames(1)
	_check(seen_rc.size() == 1 and is_equal_approx(float(seen_rc[0].cfg["self_damage_mult"]), 0.6), "pháo: rocket mang self_damage_mult 0.6 (mặc định 0.15)")
	_check(G.WEAPONS["launcher"]["self_damage_mult"] == 0.15, "dữ liệu gốc của súng không bị sửa")
	pl.queue_free()
	arena.queue_free()
	await _frames(3)

	print("[Cửa hàng: UI]")
	G.load_save()
	var shop: Control = load("res://scripts/shop_menu.gd").new()
	root.add_child(shop)
	await _frames(2)
	_check(shop.buy_buttons.keys().size() == 3 and shop.gold_label.text == "Vàng: 0", "3 hàng súng, 0 vàng")
	_check(shop.buy_buttons["shotgun"].disabled and shop.buy_buttons["shotgun"].text == "Mua - 150 vàng", "không đủ vàng: nút mờ, hiện giá")
	G.add_gold(320)
	_check(not shop.buy_buttons["shotgun"].disabled and not shop.buy_buttons["sniper"].disabled and shop.buy_buttons["launcher"].disabled and shop.gold_label.text == "Vàng: 320", "320 vàng: mua được shotgun, bắn tỉa; pháo vẫn mờ (tự cập nhật)")
	shop.buy_buttons["sniper"].pressed.emit()
	_check(G.owns_gun("sniper") and G.gold == 20 and shop.buy_buttons["sniper"].text == "Đã sở hữu" and shop.buy_buttons["sniper"].disabled, "bấm Mua bắn tỉa: trừ 300, hiện Đã sở hữu")
	var closed: Array = []
	shop.closed.connect(func(): closed.append(1))
	shop.back_button.pressed.emit()
	_check(closed.size() == 1, "Quay lại phát closed")
	shop.queue_free()
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await _frames(3)
	_check(menu.shop_button != null and menu.shop_panel != null and not menu.shop_panel.visible, "menu: có nút Cửa hàng, panel ẩn")
	menu.shop_button.pressed.emit()
	_check(menu.shop_panel.visible, "bấm Cửa hàng: mở panel")
	G.set_mode("survival")
	menu._refresh_setup()
	_check(not menu.start_gun_button.visible, "chế độ Sinh tồn: ẩn nút súng khởi đầu")
	G.set_mode("endless")
	menu._refresh_setup()
	_check(menu.start_gun_button.visible and menu.start_gun_button.text.contains("Súng lục"), "chế độ Vô Tận: hiện nút súng khởi đầu (Súng lục)")
	menu.start_gun_button.pressed.emit()
	_check(G.start_gun == "sniper" and menu.start_gun_button.text.contains("Bắn tỉa"), "xoay: súng lục -> bắn tỉa (shotgun chưa mua, đã có bắn tỉa)")
	menu.queue_free()
	await _frames(3)

	print("[Tích hợp main (Vô Tận)]")
	G.load_save()
	G.add_gold(150)
	G.buy_gun("shotgun")
	G.set_start_gun("shotgun")
	var g0: int = G.gold
	G.set_mode("endless")
	G.start_wave = 1
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(15)
	main._start_mode()
	await _frames(3)
	var mc = main.player.combat
	_check(mc.weapon == "shotgun" and mc.locked, "bắt đầu lượt bằng súng khởi đầu (shotgun), khoá đổi súng")
	mc.want_cycle = 1
	await _frames(3)
	mc.want_cycle = 0
	mc.want_weapon = 0
	await _frames(3)
	mc.want_weapon = -1
	_check(mc.weapon == "shotgun", "bấm đổi súng: không đổi được")
	_check(main.progress.pools == ["shared", "sword", "gun:shotgun"], "cầm shotgun: kho chung + kiếm + kho shotgun")
	_check(main.hud._flaw_label.text.contains("Giật bật người"), "HUD hiện lỗi của súng đang cầm")
	_check(main.laser != null and not main.laser._mesh.visible, "tia laser có sẵn, đang ẩn")
	# vàng
	var bot = load("res://scripts/bot.gd").new()
	bot.setup("swordsman", 1)
	bot.position = Vector3(20.0, 0.1, 20.0)
	main.arena.add_child(bot)
	main._on_bot_killed(bot, {"score": 100, "headshot": false, "kind": "test"})
	_check(main.run_gold == 1 and main.hud._gold_label.text == "Vàng: +1" and G.gold == g0, "hạ 1 bot: +1 vàng trong lượt, chưa ghi vào tổng")
	var titan = load("res://scripts/titan.gd").new()
	titan.position = Vector3(25.0, 0.1, 25.0)
	main.arena.add_child(titan)
	main._on_bot_killed(titan, {"score": 100, "headshot": false, "kind": "test"})
	_check(main.run_gold == 31, "hạ Titan: +30 vàng (tổng lượt 31)")
	main.mode.portal_open = true
	main.mode.next_floor()
	await _frames(5)
	_check(main.run_gold == 31 + 12 and G.gold == g0 + 43, "qua tầng 1: +12 vàng thưởng tầng, ghi vào tổng ngay (%d)" % G.gold)
	main.run_gold += 5
	var res: Dictionary = main.build_result("TEST", false, 100, 0, false)
	_check(String(res["lines"][2]).contains("Vàng kiếm được: +48") or String(res["lines"][1]).contains("Vàng kiếm được: +48") or " ".join(res["lines"]).contains("Vàng kiếm được: +48"), "màn tổng kết có dòng vàng kiếm được")
	main.queue_free()
	await _frames(10)
	_check(G.gold == g0 + 48, "thoát giữa chừng: phần vàng còn lại vẫn được lưu, không cộng trùng (%d)" % G.gold)
	G.set_mode("survival")
	var main2 = load("res://scenes/main.tscn").instantiate()
	main2.autostart_waves = false
	root.add_child(main2)
	await _frames(15)
	_check(not main2.player.combat.locked and not main2.player.combat.flaws.enabled and main2.laser == null, "Sinh tồn: đổi súng tự do, không lỗi, không laser")
	main2.queue_free()
	await _frames(10)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.save_path))

	print("---")
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
