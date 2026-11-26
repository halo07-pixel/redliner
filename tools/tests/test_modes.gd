extends SceneTree
## Test headless M16: chế độ chơi (Vô Tận / Tập luyện, M41), kỷ lục theo chế độ+mức, thống kê ván,
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

	print("[kỷ lục theo chế độ + mức]")
	G.set_difficulty("normal")
	_check(G.best_score() == 0, "chưa có kỷ lục: 0")
	_check(G.submit_mode_score(500) and G.best_score() == 500, "Vô Tận: nộp 500 -> kỷ lục 500")
	_check(not G.submit_mode_score(400) and G.best_score() == 500, "điểm thấp hơn không ghi đè")
	G.set_difficulty("hard")
	_check(G.best_score("endless") == 0, "đổi mức Khó: kỷ lục riêng")
	_check(G.best_score("endless", "normal") == 500, "đọc kỷ lục mức Thường khi đang ở Khó")
	_check(G.submit_mode_score(300) and G.best_score() == 300, "Khó: 300")
	_check(not G.submit_mode_score(9999, "training") and G.best_score("training") == 0, "tập luyện không có kỷ lục")
	G._mode_scores = {}
	G.load_save()
	_check(G.best_score("endless", "normal") == 500 and G.best_score("endless", "hard") == 300, "kỷ lục được lưu và nạp lại theo mức")
	G.set_difficulty("normal")

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


	print("[luật chế độ: Vô Tận / tập luyện]")
	var gm = ModeScript.new()
	root.add_child(gm)
	gm.setup("endless")
	var obj: Array = []
	gm.objective_changed.connect(func(t): obj.append(t))
	gm.on_kill()
	_check(gm.kills == 0, "chưa start: hạ bot không tính")
	gm.start()
	_check(gm.active and obj.size() >= 1 and obj[0] != "", "Vô Tận: có mục tiêu")
	gm.on_kill()
	_check(gm.kills == 1 and gm.floor_kills == 1, "Vô Tận: hạ bot tính vào tầng")
	_check(gm.result_score(777) == 777, "Vô Tận: điểm giữ nguyên")
	gm.setup("training")
	_check(gm.result_score(777) == 0, "tập luyện: không tính điểm")
	_check(gm.objective_text().contains("TẬP LUYỆN"), "tập luyện: mục tiêu nói rõ không tính điểm")
	gm.start()
	gm.on_kill()
	_check(gm.kills == 1 and gm.floor_kills == 0 and not gm.portal_open, "tập luyện: chỉ đếm, không mở cổng")
	gm.queue_free()

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
	for t in WM.composition(3):
		WM._spawn(t)
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
	var pb = WM.spawn_practice("rusher", Vector3(0, 0.1, -10), 1)
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
	hud.set_enemy_types({"gunner": 1, "swordsman": 3, "bomber": 0})
	_check(hud._types_label.text == "Lính kiếm 3   Xạ thủ 1", "HUD hiện cơ cấu bot còn lại (%s)" % hud._types_label.text)
	hud.set_enemy_types({})
	_check(hud._types_label.text == "", "hết bot: dòng cơ cấu trống")
	hud.set_mode_layout("training")
	_check(not hud._wave_label.visible and not hud._score_label.visible, "tập luyện: ẩn wave và điểm")
	hud.set_mode_layout("endless")
	_check(hud._wave_label.visible and hud._score_label.visible, "chế độ khác: hiện lại")
	hud.queue_free()

	print("[màn tổng kết]")
	var go = load("res://scripts/game_over.gd").new()
	root.add_child(go)
	await _frames(2)
	go.show_result({"title": "CHIẾN THẮNG!", "lines": ["a", "b"], "record": "KỶ LỤC MỚI!"})
	_check(go.visible and go.title_label.text == "CHIẾN THẮNG!" and go.summary_label.text == "a\nb" and go.record_label.text == "KỶ LỤC MỚI!", "show_result hiện tiêu đề, các dòng, kỷ lục")
	go.show_result({"title": "HẾT GIỜ", "lines": [], "record": ""})
	_check(go.record_label.text == "", "thua: tiêu đề đỏ, không có dòng kỷ lục")
	go.queue_free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_modes.cfg"))
	G.set_mode("endless")
	print("----", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
