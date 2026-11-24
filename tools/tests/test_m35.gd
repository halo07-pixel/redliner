extends SceneTree
## M35: XP, lên cấp, màn chọn nâng cấp, kho dùng chung (chế độ Vô Tận).
##   timeout 280 godot --headless --path . -s tools/tests/test_m35.gd

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
	G.save_path = "user://test_m35.cfg"
	G.load_save()
	var RP = load("res://scripts/run_progress.gd")
	var Up = load("res://scripts/upgrades.gd")

	print("[dữ liệu kho dùng chung]")
	var pool: Dictionary = G.UPGRADES["shared"]
	_check(pool.size() == 10, "kho dùng chung có 10 thẻ")
	var data_ok: bool = true
	for id in pool:
		var c: Dictionary = pool[id]
		data_ok = data_ok and c.has_all(["name", "desc", "stat", "per", "max", "kind"]) and int(c["max"]) >= 1 and c["kind"] in ["mult", "add"]
	_check(data_ok, "mỗi thẻ đủ trường, bậc tối đa >= 1")

	print("[đường cong XP]")
	_check(RP.need_for(0) == 10 and RP.need_for(1) == 16 and RP.need_for(5) == 40, "cấp 0->1 cần 10, 1->2 cần 16, 5->6 cần 40")
	_check(RP.orb_value("swordsman") == 3 and RP.orb_value("gunner") == 3 and RP.orb_value("titan") == 40, "XP bot 3, Titan 40")
	var rp: Node = RP.new()
	root.add_child(rp)
	var lv: Array = []
	var xps: Array = []
	rp.leveled_up.connect(func(l): lv.append(l))
	rp.xp_changed.connect(func(l, x, n): xps.append([l, x, n]))
	rp.add_xp(9)
	_check(rp.level == 0 and rp.xp == 9 and lv.is_empty() and xps[0] == [0, 9, 10], "9 XP: chưa lên cấp")
	rp.add_xp(1)
	_check(rp.level == 1 and rp.xp == 0 and lv == [1] and rp.pending == 1, "đủ 10 XP: lên cấp 1, xp về 0, 1 lần chọn chờ")
	rp.add_xp(16 + 22 + 5)
	_check(rp.level == 3 and rp.xp == 5 and lv == [1, 2, 3] and rp.pending == 3, "nhiều cấp liền: phát từng cấp, XP dư giữ lại (cấp %d, dư %d)" % [rp.level, rp.xp])

	print("[rút thẻ]")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok_unique: bool = true
	for i in 50:
		var d: Array = Up.draw(["shared"], {}, 3, rng)
		var ids: Array = d.map(func(c): return c["id"])
		ok_unique = ok_unique and d.size() == 3 and ids.size() == (ids.duplicate()).filter(func(x): return ids.count(x) == 1).size()
	_check(ok_unique, "50 lần rút: luôn 3 thẻ khác nhau")
	var all_max: Dictionary = {}
	for id in pool:
		all_max[id] = int(pool[id]["max"])
	_check(Up.draw(["shared"], all_max, 3, rng).is_empty(), "mọi thẻ đạt tối đa: không rút được thẻ nào")
	var near: Dictionary = all_max.duplicate()
	near.erase("speed")
	near.erase("damage")
	var d2: Array = Up.draw(["shared"], near, 3, rng)
	_check(d2.size() == 2, "còn 2 thẻ: rút 2 thẻ (không đệm)")
	var t1: Array = Up.available(["shared"], {"damage": 2}).filter(func(c): return c["id"] == "damage")
	_check(t1[0]["tier"] == 3, "thẻ đã lấy 2 bậc: lần rút kế là bậc 3")
	var capped: Array = Up.available(["shared"], {"damage": 5}).filter(func(c): return c["id"] == "damage")
	_check(capped.is_empty(), "thẻ đạt bậc 5/5 không còn trong kho rút")

	print("[thống kê nâng cấp]")
	_check(is_equal_approx(Up.stat({}, "damage"), 1.0) and Up.stat({}, "regen") == 0.0, "chưa lấy gì: hệ số 1, cộng thẳng 0")
	_check(is_equal_approx(Up.stat({"damage": 3}, "damage"), 1.36), "sát thương 3 bậc = x1.36")
	_check(is_equal_approx(Up.stat({"max_hp": 2}, "max_hp"), 30.0) and is_equal_approx(Up.stat({"magnet": 4}, "magnet"), 10.0), "máu +30, nam châm +10 m")
	rp.taken = {"xp_gain": 5}
	var before_xp: int = rp.xp
	rp.pending = 0
	rp.add_xp(10)
	_check(rp.xp - before_xp == 15 or rp.level > 3, "Học nhanh 5 bậc: 10 XP -> 15 XP")

	print("[chọn / bỏ qua]")
	var rp2: Node = RP.new()
	root.add_child(rp2)
	var chosen: Array = []
	rp2.upgrade_chosen.connect(func(i, t): chosen.append([i, t]))
	_check(not rp2.choose("damage") and not rp2.skip(), "không có lần chọn chờ: chọn/bỏ qua đều bị từ chối")
	rp2.add_xp(10 + 16)
	_check(rp2.pending == 2, "lên 2 cấp: 2 lần chờ")
	_check(rp2.choose("damage") and rp2.choose("damage") and chosen == [["damage", 1], ["damage", 2]] and rp2.pending == 0, "chọn Đạn mạnh 2 lần: bậc 1 rồi 2")
	rp2.pending = 1
	_check(not rp2.choose("khong_co") and rp2.pending == 1, "id lạ bị từ chối, lần chờ giữ nguyên")
	rp2.taken["fire_rate"] = 5
	_check(not rp2.choose("fire_rate"), "thẻ đã tối đa bị từ chối")
	_check(rp2.skip() and rp2.pending == 0, "bỏ qua: trừ 1 lần chờ")
	rp.queue_free()
	rp2.queue_free()

	print("[viên XP]")
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.map_id = "yard"
	arena.bake_nav = false
	root.add_child(arena)
	var pl: Node3D = load("res://scenes/player.tscn").instantiate()
	root.add_child(pl)
	pl.global_position = Vector3(0.0, 0.2, 0.0)
	await _frames(10)
	_check(float(pl.pickup_magnet) == float(G.XP["magnet_base"]), "tầm hút mặc định %.1f m" % pl.pickup_magnet)
	var got: Array = []
	var far: Area3D = load("res://scripts/xp_orb.gd").spawn(root, pl.global_position + Vector3(10.0, 0.0, 0.0), 7)
	far.collected.connect(func(a): got.append(a))
	await _frames(30)
	_check(got.is_empty() and far.global_position.distance_to(pl.global_position + Vector3(10.0, 0.0, 0.0)) < 0.01, "ngoài tầm hút: đứng yên")
	pl.pickup_magnet = 12.0
	await _frames(120)
	_check(got == [7], "trong tầm hút: bay tới và nhặt đúng 1 lần (%s)" % [got])
	var old: Area3D = load("res://scripts/xp_orb.gd").spawn(root, Vector3(40.0, 0.2, 40.0), 1)
	old.age = float(G.XP["orb_lifetime"]) - 0.01
	await _frames(5)
	_check(not is_instance_valid(old) or old.is_queued_for_deletion(), "hết hạn thì tự biến mất")
	pl.queue_free()
	arena.queue_free()
	await _frames(3)

	print("[màn chọn thẻ]")
	var ui: CanvasLayer = load("res://scripts/level_up_ui.gd").new()
	root.add_child(ui)
	await _frames(2)
	var picks: Array = []
	var skips: Array = []
	ui.card_chosen.connect(func(i): picks.append(i))
	ui.skipped.connect(func(): skips.append(1))
	ui.open(4, Up.draw(["shared"], {}, 3, rng))
	_check(ui.visible and ui.card_buttons.size() == 3 and ui.card_buttons[0].text.contains("Bậc 1 / ") and ui.card_buttons[0].text.contains("●○"), "hiện 3 nút thẻ, ghi bậc")
	var LU = load("res://scripts/level_up_ui.gd")
	_check(LU.effect_text({"per": 0.12, "kind": "mult"}, 2) == "+24%" and LU.effect_text({"per": 15.0, "kind": "add"}, 2) == "+30" and LU.effect_text({"per": 0.5, "kind": "add"}, 3) == "+1.5", "chữ hiệu ứng: +24% / +30 / +1.5")
	var all_cat: bool = true
	for cid in pool:
		all_cat = all_cat and LU.CATS.has(String(pool[cid].get("cat", "")))
	_check(all_cat, "mọi thẻ có nhóm màu hợp lệ")
	await create_timer(0.5).timeout
	_check(ui.card_buttons[0].modulate.a > 0.99 and ui.card_buttons[2].scale.is_equal_approx(Vector2.ONE), "hiệu ứng trượt vào xong: thẻ hiện rõ, đúng cỡ")
	ui.card_buttons[1].pressed.emit()
	_check(picks == [ui.cards[1]["id"]], "bấm thẻ 2: phát card_chosen với đúng id")
	ui.skip_button.pressed.emit()
	_check(skips.size() == 1, "bấm Bỏ qua: phát skipped")
	var key := InputEventKey.new()
	key.keycode = KEY_3
	key.pressed = true
	ui._unhandled_input(key)
	_check(picks.size() == 2 and picks[1] == ui.cards[2]["id"], "phím 3 chọn thẻ 3")
	ui.close()
	_check(not ui.visible, "close ẩn màn")
	ui.queue_free()

	print("[tích hợp main]")
	G.set_mode("endless")
	G.start_wave = 1
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(15)
	main._start_mode()
	await _frames(3)
	_check(main.progress != null and main.level_ui != null and not main.level_ui.visible, "main: có tiến trình + màn chọn, đang ẩn")
	var combat = main.player.combat
	_check(combat.damage_mult == 1.0 and combat.mag_mult == 1.0 and main.player.speed_mult == 1.0, "chưa nâng cấp: mọi hệ số = 1")
	# bot chết -> orb XP
	var orbs0: int = 0
	for ch in main.get_children():
		if ch.get_script() == load("res://scripts/xp_orb.gd"):
			orbs0 += 1
	var fake := Node3D.new()
	fake.set("position", Vector3(30, 0.2, 30))
	main.add_child(fake)
	fake.set_script(null)
	var bot = load("res://scripts/bot.gd").new()
	bot.setup("swordsman", 1)
	bot.position = Vector3(20.0, 0.1, 20.0)
	main.arena.add_child(bot)
	main._on_bot_killed(bot, {"score": 100, "headshot": false, "kind": "test"})
	var orbs1: int = 0
	var orb_amount: int = 0
	for ch in main.get_children():
		if ch.get_script() == load("res://scripts/xp_orb.gd"):
			orbs1 += 1
			orb_amount = ch.amount
	_check(orbs1 == orbs0 + 1 and orb_amount == 3, "bot chết: rơi 1 viên XP trị giá 3")
	# lên cấp -> dừng game, hiện thẻ
	main.progress.add_xp(10)
	await _frames(3)
	_check(main.level_ui.visible and paused and main.level_ui.card_buttons.size() == 3, "lên cấp: màn chọn hiện, game pause")
	main.level_ui.card_buttons[0].pressed.emit()
	await _frames(3)
	_check(not main.level_ui.visible and not paused and main.progress.taken.size() == 1, "chọn thẻ: màn đóng, game chạy lại, ghi 1 nâng cấp")
	# áp từng loại
	for id in ["damage", "fire_rate", "mag", "reload", "speed", "stamina", "magnet", "xp_gain", "regen"]:
		main.progress.taken[id] = 2
	main.progress.taken["max_hp"] = 3
	var hp_max0: float = float(G.COMBAT["player_health"])
	main.player.hurtbox.health = 50.0
	main._apply_upgrades()
	_check(is_equal_approx(combat.damage_mult, 1.24) and is_equal_approx(combat.fire_rate_mult, 1.2), "sát thương x1.24, tốc độ bắn x1.2")
	_check(is_equal_approx(combat.mag_mult, 1.4) and is_equal_approx(combat.reload_mult, 1.3), "băng đạn x1.4, nạp x1.3")
	_check(combat.max_ammo() == roundi(float(combat.cfg()["mag"]) * 1.4), "max_ammo theo hệ số băng đạn (%d)" % combat.max_ammo())
	_check(is_equal_approx(main.player.speed_mult, 1.08) and is_equal_approx(main.player.stamina_regen_mult, 1.4), "chạy x1.08, stamina x1.4")
	_check(is_equal_approx(main.player.pickup_magnet, float(G.XP["magnet_base"]) + 5.0), "tầm hút +5 m")
	_check(is_equal_approx(main.player.hurtbox.max_health, hp_max0 + 45.0) and main.player.hurtbox.health >= 50.0 + 45.0 - 0.01, "máu tối đa +45, đồng thời hồi bằng phần tăng")
	# sát thương thật qua _hit
	var landed: Array = []
	var dummy := Node.new()
	dummy.set_script(load("res://tools/tests/m35_dummy.gd"))
	dummy.hits = landed
	combat._hit(dummy, 10.0, Vector3.FORWARD)
	_check(landed.size() == 1 and is_equal_approx(landed[0], 12.4), "_hit nhân hệ số: 10 -> 12.4 (%s)" % [landed])
	# hồi máu theo giây
	main.player.hurtbox.health = 10.0
	await create_timer(1.0).timeout
	_check(main.player.hurtbox.health > 10.9, "Tự hồi phục 2 bậc = +1 máu/giây (%.2f)" % main.player.hurtbox.health)
	# nhiều cấp liền nhau, thiếu thẻ, bỏ qua
	main.progress.taken = {}
	main.progress.add_xp(16 + 22 + 28)   # đang cấp 1: lên 3 cấp nữa
	await _frames(3)
	_check(main.level_ui.visible and main.progress.pending == 3, "3 cấp chờ: hiện màn đầu")
	main.player.hurtbox.health = 20.0
	main.level_ui.skip_button.pressed.emit()
	await _frames(3)
	_check(main.level_ui.visible and main.progress.pending == 2 and main.player.hurtbox.health > 20.0 + 24.0, "bỏ qua: hồi máu, hiện màn kế (còn 2 chờ)")
	main.level_ui.card_buttons[0].pressed.emit()
	await _frames(3)
	main.level_ui.card_buttons[0].pressed.emit()
	await _frames(3)
	_check(not main.level_ui.visible and not paused and main.progress.pending == 0, "chọn hết: màn đóng, game chạy lại")
	# hết thẻ: tự bỏ qua
	for pname in main.progress.pools:
		for id in G.UPGRADES[pname]:
			main.progress.taken[id] = int(G.UPGRADES[pname][id]["max"])
	main.progress.add_xp(300)
	await _frames(3)
	_check(not main.level_ui.visible and not paused and main.progress.pending == 0, "hết thẻ để lấy: tự bỏ qua, không kẹt pause")
	main.queue_free()
	await _frames(10)

	print("---")
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
