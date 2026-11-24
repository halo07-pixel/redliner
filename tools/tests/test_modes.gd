extends SceneTree
## Test headless M16: chế độ chơi (Sinh tồn / Thời gian / Tập luyện), kỷ lục theo chế độ+mức, thống kê ván,
## HUD, màn "Chuẩn bị", hướng dẫn theo phím, tổng kết đầy đủ.
##   timeout 300 godot --headless --path . -s tools/tests/test_modes.gd

var failures: int = 0
var G


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _wait(sec: float) -> void:
	await create_timer(sec, true, true, true).timeout


func _initialize() -> void:
	_run()


func _kill_bot(b, source) -> void:
	b.hurtbox.take_hit({"damage": 99999.0, "kind": "sword", "source": source, "direction": Vector3.FORWARD})


func _labels(n: Node, out: Array) -> Array:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_labels(c, out)
	return out


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://test_modes.cfg"
	G.load_save()
	var Stats = load("res://scripts/run_stats.gd")
	var ModeScript = load("res://scripts/game_mode.gd")

	print("[dữ liệu chế độ]")
	_check(G.MODES == ["survival", "timed", "training", "endless"], "4 chế độ: sinh tồn, thời gian, tập luyện, vô tận")
	var named: bool = true
	for m in G.MODES:
		named = named and G.MODE_NAMES.has(m) and G.MODE_DESCRIPTIONS.has(m)
	_check(named, "mỗi chế độ có tên và mô tả")
	_check(G.game_mode == "survival", "mặc định: sinh tồn")
	var seen: Array = []
	G.mode_changed.connect(func(m): seen.append(m))
	G.cycle_mode()
	_check(G.game_mode == "timed" and seen == ["timed"], "xoay vòng -> thời gian (phát signal)")
	G.cycle_mode()
	_check(G.game_mode == "training", "xoay vòng -> tập luyện")
	G.cycle_mode()
	_check(G.game_mode == "endless", "xoay vòng -> vô tận")
	G.cycle_mode()
	_check(G.game_mode == "survival", "xoay vòng -> về sinh tồn")
	G.set_mode("khong_co")
	_check(G.game_mode == "survival", "chế độ lạ bị bỏ qua")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.save_path))
	G.load_save()
	_check(G.game_mode == "survival", "load_save đặt lại mặc định khi chưa có file")
	G.set_mode("timed")
	var cf := ConfigFile.new()
	cf.load(G.save_path)
	_check(cf.get_value("game", "mode", "") == "timed", "chế độ được ghi vào file")
	G.game_mode = "survival"
	G.load_save()
	_check(G.game_mode == "timed", "chế độ được nạp lại")
	G.set_mode("survival")

	print("[kỷ lục theo chế độ + mức]")
	G.set_difficulty("normal")
	G.high_score = 0
	_check(G.best_score() == 0, "chưa có kỷ lục: 0")
	_check(G.submit_mode_score(500) and G.best_score() == 500 and G.high_score == 500, "sinh tồn: nộp 500 -> high_score = 500")
	_check(not G.submit_mode_score(400) and G.best_score() == 500, "điểm thấp hơn không ghi đè")
	_check(G.best_score("timed") == 0, "kỷ lục thời gian tách riêng (0)")
	_check(G.submit_mode_score(800, "timed") and G.best_score("timed") == 800, "nộp 800 cho thời gian")
	_check(G.best_score("survival") == 500, "kỷ lục sinh tồn không đổi")
	G.set_difficulty("hard")
	_check(G.best_score("timed") == 0 and G.best_score("survival") == 0, "đổi mức Khó: kỷ lục riêng")
	_check(G.best_score("timed", "normal") == 800 and G.best_score("survival", "normal") == 500, "đọc kỷ lục mức Thường khi đang ở Khó")
	_check(G.submit_mode_score(300, "timed") and G.best_score("timed") == 300, "Khó/thời gian: 300")
	_check(not G.submit_mode_score(9999, "training") and G.best_score("training") == 0, "tập luyện không có kỷ lục")
	G.game_mode = "survival"
	G.set_difficulty("normal")
	G.high_score = 0
	G._mode_scores = {}
	G.load_save()
	_check(G.best_score("timed", "normal") == 800 and G.best_score("timed", "hard") == 300, "kỷ lục thời gian được lưu và nạp lại theo mức")
	_check(G.best_score("survival", "normal") == 500, "kỷ lục sinh tồn vẫn còn sau khi nạp")
	G.set_mode("timed")
	_check(G.best_score() == 800, "best_score() theo chế độ đang chọn")
	G.set_mode("survival")

	print("[thống kê ván]")
	var st = Stats.new()
	_check(st.accuracy() == -1.0 and st.kills_total() == 0 and st.breakdown_text() == "", "ván mới: chưa có dữ liệu")
	st.record_kill("gunner")
	st.record_kill("swordsman")
	st.record_kill("swordsman")
	st.record_kill("bomber")
	_check(st.kills_total() == 4, "tổng bot hạ = 4")
	_check(st.breakdown_text() == "Lính kiếm 2, Xạ thủ 1, Pháo thủ 1", "chia theo loại, đúng thứ tự cố định (%s)" % st.breakdown_text())
	for i in 10:
		st.record_shot()
	for i in 4:
		st.record_hit(true)
	st.record_hit(false)
	_check(absf(st.accuracy() - 0.4) < 0.001, "độ chính xác 4/10 = 40%")
	st.tick(75.0)
	_check(Stats.format_time(st.time_alive) == "1:15", "định dạng thời gian 1:15")
	_check(Stats.format_time(-5.0) == "0:00" and Stats.format_time(600.0) == "10:00", "định dạng thời gian biên")
	var st2 = Stats.new()
	st2.record_shot()
	st2.record_hit(true)
	st2.record_hit(true)
	_check(st2.accuracy() <= 1.0, "độ chính xác không vượt 100%")

	print("[luật chế độ: sinh tồn / tập luyện]")
	var gm = ModeScript.new()
	root.add_child(gm)
	gm.setup("survival")
	var obj: Array = []
	gm.objective_changed.connect(func(t): obj.append(t))
	gm.start()
	_check(gm.active and obj.size() == 1 and obj[0].contains("Sống sót"), "sinh tồn: có mục tiêu")
	_check(gm.on_kill() == 0.0 and gm.kills == 1, "sinh tồn: hạ bot chỉ đếm, không cộng giờ")
	gm._physics_process(100.0)
	_check(not gm.done and gm.time_left == 0.0, "sinh tồn: không có đồng hồ, không tự kết thúc")
	_check(gm.result_score(777) == 777, "sinh tồn: điểm giữ nguyên")
	gm.setup("training")
	_check(gm.result_score(777, true) == 0, "tập luyện: không tính điểm")
	_check(gm.objective_text().contains("TẬP LUYỆN"), "tập luyện: mục tiêu nói rõ không tính điểm")
	gm.queue_free()

	print("[luật chế độ: thử thách thời gian]")
	var T: Dictionary = G.TIMED
	var tm = ModeScript.new()
	root.add_child(tm)
	tm.setup("timed")
	var fin: Array = []
	var ticks: Array = []
	var objs: Array = []
	tm.finished.connect(func(won, info): fin.append([won, info]))
	tm.time_changed.connect(func(t): ticks.append(t))
	tm.objective_changed.connect(func(t): objs.append(t))
	_check(tm.time_left == float(T["start_time"]) and tm.target == int(T["target_kills"]), "bắt đầu với %.0f giây, mục tiêu %d bot" % [T["start_time"], T["target_kills"]])
	_check(tm.on_kill() == 0.0 and tm.kills == 0, "chưa start: hạ bot không tính")
	tm.start()
	_check(ticks.size() == 1 and objs.size() == 1 and objs[0].contains("0 / %d" % T["target_kills"]), "start phát đồng hồ và mục tiêu")
	tm._physics_process(10.0)
	_check(absf(tm.time_left - (float(T["start_time"]) - 10.0)) < 0.001, "đồng hồ chạy ngược")
	var n0: int = ticks.size()
	tm._physics_process(0.01)
	tm._physics_process(0.01)
	_check(ticks.size() - n0 <= 1, "time_changed được giới hạn theo 0.1 s (không phát mỗi frame)")
	var before: float = tm.time_left
	var g1: float = tm.on_kill()
	_check(absf(g1 - float(T["kill_bonus"])) < 0.001 and absf(tm.time_left - (before + float(T["kill_bonus"]))) < 0.001, "hạ bot cộng %.0f giây" % T["kill_bonus"])
	_check(objs[objs.size() - 1].contains("1 / %d" % T["target_kills"]), "mục tiêu cập nhật 1/%d" % T["target_kills"])
	tm.time_left = float(T["max_time"]) - 1.0
	var g2: float = tm.on_kill()
	_check(tm.time_left == float(T["max_time"]) and absf(g2 - 1.0) < 0.001, "thời gian cộng có trần %.0f giây" % T["max_time"])
	tm.time_left = 40.0
	while tm.kills < tm.target - 1:
		tm.on_kill()
		tm.time_left = 40.0
	_check(fin.is_empty() and not tm.done, "còn thiếu 1 bot: chưa thắng")
	tm.on_kill()
	_check(fin.size() == 1 and fin[0][0] == true and tm.done and not tm.active, "đủ bot: THẮNG và kết thúc")
	_check(fin[0][1]["kills"] == tm.target and fin[0][1]["mode"] == "timed", "thông tin kết thúc có số bot và chế độ")
	_check(tm.on_kill() == 0.0 and tm.kills == tm.target, "sau khi xong không đếm thêm")
	tm._physics_process(5.0)
	_check(fin.size() == 1, "sau khi xong đồng hồ không phát kết thúc lần nữa")
	tm.time_left = 20.4
	_check(tm.result_score(1000, true) == 1000 + 20 * int(T["win_bonus_per_sec"]), "thắng: cộng thưởng theo giây còn lại (làm tròn)")
	_check(tm.result_score(1000, false) == 1000, "thua: không có thưởng giờ")
	tm.setup("timed")
	tm.start()
	tm._physics_process(float(T["start_time"]) + 1.0)
	_check(tm.done and tm.time_left == 0.0, "hết giờ: kết thúc, thời gian không âm")
	_check(fin.size() == 2 and fin[1][0] == false, "hết giờ: THUA")
	tm.queue_free()

	print("[wave manager: bot theo loại, bot tập]")
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = G.L_WORLD
	var fc := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(80, 1, 80)
	fc.shape = fs
	floor_body.add_child(fc)
	floor_body.position = Vector3(0, -0.5, 0)
	world.add_child(floor_body)
	var WM = load("res://scripts/wave_manager.gd").new()
	root.add_child(WM)
	WM.setup(world, [Vector3(0, 0.1, -20), Vector3(5, 0.1, -20)])
	WM.wave = 3
	WM._next_wave()
	var total: int = 0
	for k in WM.alive_types:
		total += int(WM.alive_types[k])
	_check(total == WM.composition(4).size() - 0 or total == WM.composition(WM.wave).size(), "alive_types đếm đủ bot của wave (%s)" % [WM.alive_types])
	var one = null
	for b in get_nodes_in_group("bots"):
		one = b
		break
	var tn: String = one.type_name
	var cnt0: int = int(WM.alive_types[tn])
	_kill_bot(one, null)
	await _frames(2)
	_check(int(WM.alive_types[tn]) == cnt0 - 1, "bot chết: alive_types giảm")
	for b in get_nodes_in_group("bots"):
		b.queue_free()
	await _frames(2)
	WM.stop()
	var prac: Array = []
	WM.practice_bot_killed.connect(func(b, i): prac.append(b))
	var pb = WM.spawn_practice("rusher", 1)
	await _frames(2)
	_check(pb.type_name == "rusher" and pb.is_inside_tree(), "sinh bot tập đúng loại")
	_check(WM._alive == WM._alive, "bot tập không đụng tới đếm wave")
	var alive_before: int = WM._alive
	_kill_bot(pb, null)
	await _frames(2)
	_check(prac.size() == 1 and WM._alive == alive_before, "bot tập chết: có signal riêng, không kết thúc wave")
	WM.queue_free()
	world.queue_free()
	await _frames(2)

	print("[HUD]")
	var hud = load("res://scripts/hud.gd").new()
	root.add_child(hud)
	await _frames(2)
	hud.set_objective("Hạ 25 bot:  3 / 25")
	_check(hud._objective_label.text == "Hạ 25 bot:  3 / 25", "HUD hiện mục tiêu")
	_check(not hud._timer_label.visible, "đồng hồ ẩn khi chưa dùng")
	hud.set_timer(75.0)
	_check(hud._timer_label.visible and hud._timer_label.text == "1:15", "đồng hồ 75 s -> 1:15")
	hud.set_timer(9.34)
	_check(hud._timer_label.text == "9.3", "dưới 10 s hiện số lẻ (9.3)")
	_check(hud._timer_label.get_theme_color("font_color").r > 0.9 and hud._timer_label.get_theme_color("font_color").g < 0.5, "dưới 10 s chữ đỏ")
	hud.set_timer(30.0)
	_check(hud._timer_label.get_theme_color("font_color").g > 0.9, "trên 10 s chữ trắng lại")
	hud.set_enemy_types({"gunner": 1, "swordsman": 3, "bomber": 0})
	_check(hud._types_label.text == "Lính kiếm 3   Xạ thủ 1", "HUD hiện cơ cấu bot còn lại (%s)" % hud._types_label.text)
	hud.set_enemy_types({})
	_check(hud._types_label.text == "", "hết bot: dòng cơ cấu trống")
	hud.set_mode_layout("training")
	_check(not hud._wave_label.visible and not hud._score_label.visible, "tập luyện: ẩn wave và điểm")
	hud.set_mode_layout("timed")
	_check(hud._wave_label.visible and hud._score_label.visible, "chế độ khác: hiện lại")
	hud.queue_free()

	print("[màn tổng kết]")
	var go = load("res://scripts/game_over.gd").new()
	root.add_child(go)
	await _frames(2)
	go.show_result({"title": "CHIẾN THẮNG!", "won": true, "lines": ["a", "b"], "record": "KỶ LỤC MỚI!"})
	_check(go.visible and go.title_label.text == "CHIẾN THẮNG!" and go.summary_label.text == "a\nb" and go.record_label.text == "KỶ LỤC MỚI!", "show_result hiện tiêu đề, các dòng, kỷ lục")
	_check(go.title_label.get_theme_color("font_color").g > go.title_label.get_theme_color("font_color").r, "thắng: tiêu đề xanh")
	go.show_result({"title": "HẾT GIỜ", "won": false, "lines": [], "record": ""})
	_check(go.title_label.get_theme_color("font_color").r > go.title_label.get_theme_color("font_color").g and go.record_label.text == "", "thua: tiêu đề đỏ, không có dòng kỷ lục")
	go.queue_free()

	print("[menu: màn Chuẩn bị]")
	G.set_mode("survival")
	G.set_difficulty("normal")
	G.high_score = 700
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await _frames(2)
	_check(menu.setup_panel != null and not menu.setup_panel.visible, "màn Chuẩn bị ẩn lúc đầu")
	menu.play_button.pressed.emit()
	_check(menu.setup_panel.visible, "bấm Chơi -> mở màn Chuẩn bị (chưa vào game)")
	_check(menu.mode_button.text.contains("Sinh tồn") and menu.map_button != null and menu.difficulty_button != null, "có nút chế độ / bản đồ / độ khó")
	_check(menu.best_label.text.contains("700") and menu.mode_desc_label.text == G.MODE_DESCRIPTIONS["survival"], "hiện kỷ lục và mô tả chế độ sinh tồn")
	menu.mode_button.pressed.emit()
	_check(G.game_mode == "timed" and menu.mode_button.text.contains("Thử thách thời gian"), "bấm nút chế độ -> thời gian")
	_check(menu.mode_desc_label.text == G.MODE_DESCRIPTIONS["timed"] and menu.best_label.text.contains("800"), "mô tả + kỷ lục đổi theo chế độ (800)")
	menu.difficulty_button.pressed.emit()
	_check(menu.best_label.text.contains("300") and menu.best_label.text.contains("Khó"), "đổi độ khó: kỷ lục theo (thời gian, Khó) = 300")
	menu.mode_button.pressed.emit()
	_check(G.game_mode == "training" and menu.best_label.text.contains("Không tính điểm"), "tập luyện: ghi rõ không tính điểm")
	_check(menu.start_button != null and menu.setup_back_button != null, "có nút Bắt đầu và Quay lại")
	menu.setup_back_button.pressed.emit()
	_check(not menu.setup_panel.visible, "Quay lại -> đóng màn Chuẩn bị")
	var help_text: String = "\n".join(PackedStringArray(_labels(menu.help_panel, [])))
	_check(help_text.contains(G.binding_text("dash")) and help_text.contains(G.binding_text("parry")), "hướng dẫn lấy tên phím từ cài đặt hiện tại")
	menu.queue_free()
	G.set_mode("survival")
	G.set_difficulty("normal")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_J
	G.rebind("dash", ev) if G.has_method("rebind") else null
	var menu2 = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu2)
	await _frames(2)
	var help2: String = "\n".join(PackedStringArray(_labels(menu2.help_panel, [])))
	_check(help2.contains(G.binding_text("dash")), "đổi phím Dash: hướng dẫn cập nhật (%s)" % G.binding_text("dash"))
	menu2.queue_free()
	G.reset_bindings()

	print("[game: thời gian]")
	G.set_mode("timed")
	G.set_difficulty("normal")
	G.selected_map = "yard"
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(6)
	main.player.use_input = false
	_check(main.mode.mode == "timed" and main.waves.break_time == float(G.TIMED["break_time"]), "vào game: chế độ thời gian, nghỉ giữa wave ngắn")
	_check(main.hud._objective_label.text.contains("Hạ"), "HUD hiện mục tiêu chế độ")
	main._start_mode()
	await _frames(3)
	_check(main.mode.active and main.waves.wave == 1 and main.hud._timer_label.visible, "bắt đầu: wave 1 chạy, đồng hồ hiện")
	var bot0 = get_nodes_in_group("bots")[0]
	var tl0: float = main.mode.time_left
	_kill_bot(bot0, main.player)
	await _frames(2)
	_check(main.mode.kills == 1 and main.mode.time_left > tl0 and main.kills == 1, "hạ bot: đếm + cộng giờ")
	_check(main.stats.kills_total() == 1, "thống kê ghi nhận bot hạ theo loại")
	_check(main.hud._types_label.text != "", "HUD hiện cơ cấu bot còn lại (%s)" % main.hud._types_label.text)
	var t_before: float = main.stats.time_alive
	await _frames(30)
	_check(main.stats.time_alive > t_before, "thời gian ván được tính")
	# thắng: còn thiếu 1 bot
	main.mode.kills = main.mode.target - 1
	main.mode.time_left = 33.0
	var best_before: int = G.best_score()
	main.score.score = 1000
	main.player.combat.shot_fired.emit(Vector3.ZERO, Vector3.ONE)
	main.player.combat.hit_confirmed.emit(true)
	var bot1 = get_nodes_in_group("bots")[0]
	_kill_bot(bot1, main.player)
	await _frames(2)
	_check(main._over and main.mode.done, "đủ bot: ván kết thúc")
	await _wait(1.0)
	_check(main.game_over.visible and main.game_over.title_label.text == "CHIẾN THẮNG!", "hiện màn CHIẾN THẮNG")
	var txt: String = main.game_over.summary_label.text
	_check(txt.contains("Thử thách thời gian") and txt.contains("Điểm:") and txt.contains("Độ chính xác") and txt.contains("100%") and txt.contains("Thời gian:"), "tổng kết có chế độ, điểm, độ chính xác 100%, thời gian")
	var won_score: int = G.best_score()
	_check(won_score > best_before and won_score >= main.score.score + 30 * int(G.TIMED["win_bonus_per_sec"]), "điểm thắng = điểm bot + thưởng thời gian còn lại (%d)" % won_score)
	_check(main.game_over.record_label.text == "KỶ LỤC MỚI!", "phá kỷ lục thời gian")
	_check(G.high_score == 700 or G.best_score("survival") == G.high_score, "kỷ lục sinh tồn không bị đổi bởi chế độ thời gian")
	paused = false
	main.queue_free()
	await _frames(3)

	print("[game: hết giờ]")
	var main2 = load("res://scenes/main.tscn").instantiate()
	main2.autostart_waves = false
	root.add_child(main2)
	await _frames(6)
	main2.player.use_input = false
	main2._start_mode()
	await _frames(3)
	main2.mode.time_left = 0.05
	await _frames(8)
	_check(main2._over, "hết giờ: ván kết thúc")
	await _wait(1.0)
	_check(main2.game_over.visible and main2.game_over.title_label.text == "HẾT GIỜ", "hiện màn HẾT GIỜ")
	_check(main2.game_over.record_label.text == "" and main2.game_over.summary_label.text.contains("Kỷ lục:"), "thua: so sánh với kỷ lục, không có KỶ LỤC MỚI")
	paused = false
	main2.queue_free()
	await _frames(3)

	print("[game: sinh tồn]")
	G.set_mode("survival")
	var main3 = load("res://scenes/main.tscn").instantiate()
	main3.autostart_waves = false
	root.add_child(main3)
	await _frames(6)
	main3.player.use_input = false
	_check(main3.mode.mode == "survival" and main3.mode.objective_text().contains("Sống sót"), "sinh tồn: mục tiêu sống sót")
	main3._start_mode()
	await _frames(3)
	_check(main3.waves.wave == 1 and not main3.hud._timer_label.visible, "sinh tồn: wave chạy, không có đồng hồ")
	main3.stats.record_kill("swordsman")
	main3.stats.record_kill("rusher")
	main3.kills = 2
	main3.score.score = 450
	var r: Dictionary = main3.build_result("BẠN ĐÃ GỤC", false, 450, 300, true)
	var joined: String = "\n".join(PackedStringArray(r["lines"]))
	_check(joined.contains("Wave đạt được: 1") and joined.contains("Lính kiếm 1, Lao nhanh 1") and joined.contains("Kỷ lục cũ: 300"), "tổng kết sinh tồn: wave, bot theo loại, kỷ lục cũ")
	_check(r["record"] == "KỶ LỤC MỚI!" and r["won"] == false, "cờ kỷ lục / thắng")
	var r2: Dictionary = main3.build_result("BẠN ĐÃ GỤC", false, 100, 300, false)
	_check("\n".join(PackedStringArray(r2["lines"])).contains("còn thiếu 200"), "không phá kỷ lục: hiện còn thiếu bao nhiêu")
	main3.queue_free()
	await _frames(3)

	print("[game: tập luyện]")
	G.set_mode("training")
	var main4 = load("res://scenes/main.tscn").instantiate()
	main4.autostart_waves = false
	root.add_child(main4)
	await _frames(6)
	main4.player.use_input = false
	_check(main4.mode.mode == "training" and not main4.hud._wave_label.visible, "tập luyện: ẩn wave/điểm")
	main4._start_mode()
	await _frames(5)
	var bots: Array = get_nodes_in_group("bots")
	_check(bots.size() == 1 and bots[0].type_name == G.TRAINING["types"][0] and main4.waves.wave == 0, "có đúng 1 bot tập, không có wave")
	main4.player.hurtbox.take_hit({"damage": 60.0, "kind": "hitscan", "source": null, "direction": Vector3.ZERO})
	_check(main4.player.hurtbox.health == main4.player.hurtbox.max_health and not main4.player.dead, "bất tử: bị đánh vẫn đầy máu")
	main4.player.hurtbox.take_hit({"damage": 99999.0, "kind": "hitscan", "source": null, "direction": Vector3.ZERO})
	_check(not main4.player.dead and not main4._over, "đòn chí mạng cũng không gục")
	main4.player.combat.switch_to("shotgun")
	main4.player.combat._shot_cd = 0.0
	var mag: int = main4.player.combat.max_ammo()
	main4.player.combat._shoot()
	_check(main4.player.combat.ammo == mag, "đạn vô hạn: bắn xong băng vẫn đầy")
	_kill_bot(bots[0], main4.player)
	await _frames(2)
	_check(main4.stats.kills_total() == 1 and main4.kills == 0, "bot tập chết: thống kê ghi nhận, không tính điểm/wave")
	_check(not main4.mode.done and main4.score.score == 0, "tập luyện: không có điểm")
	await _wait(float(G.TRAINING["respawn_time"]) + 0.6)
	var after: Array = get_nodes_in_group("bots").filter(func(b): return not b.dead)
	_check(after.size() == 1 and after[0].type_name == G.TRAINING["types"][1], "bot tập kế tiếp sinh ra (%s)" % (after[0].type_name if after.size() > 0 else "-"))
	var prev: int = G.best_score("survival")
	main4.score.score = 5000
	main4._go_menu()
	_check(G.best_score("survival") == prev and G.best_score("training") == 0, "thoát tập luyện: không nộp điểm nào")
	await _frames(2)

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_modes.cfg"))
	G.set_mode("survival")
	print("----", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
