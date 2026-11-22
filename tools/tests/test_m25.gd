extends SceneTree
## M25: chỉnh lúc chơi - grapple / bot / Titan qua Global.set_live, bộ chỉnh F4, lưu và nạp, preset Titan, dòng F3.
##   timeout 120 godot --headless --path . -s tools/tests/test_m25.gd

var failures: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var G: Node = root.get_node("Global")
	var tuning_path: String = ProjectSettings.globalize_path(G.LIVE_PATH)
	if FileAccess.file_exists(G.LIVE_PATH):
		DirAccess.remove_absolute(tuning_path)
	G.reset_live()

	print("[áp dụng giá trị]")
	_check(G.live_changed().is_empty(), "mặc định: chưa đổi gì (không đổi hành vi khi không dùng bộ chỉnh)")
	var d0: float = G.live_default("p", "grapple_range")
	_check(G.set_live("p", "grapple_range", 120.0) and is_equal_approx(float(G.PLAYER["grapple_range"]), 120.0), "đổi tầm móc áp vào Global.PLAYER")
	_check(G.set_live("b", "accel", 50.0) and is_equal_approx(float(G.BOT_MOVE["accel"]), 50.0), "đổi gia tốc bot áp vào Global.BOT_MOVE")
	_check(G.set_live("t", "nape_mult", 9.0) and is_equal_approx(float(G.TITAN["nape_mult"]), 9.0), "đổi hệ số gáy Titan áp vào Global.TITAN")
	_check(not G.set_live("p", "gravity", 1.0) and not G.set_live("x", "a", 1.0), "khoá ngoài danh sách bị từ chối")
	_check(not G.set_live("p", "grapple_range", NAN), "giá trị không hợp lệ bị từ chối")
	_check(G.live_changed().size() == 3, "live_changed liệt kê đúng 3 giá trị")

	print("[hành vi theo giá trị mới]")
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = G.L_WORLD
	var fc := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(400, 1, 400)
	fc.shape = fs
	floor_body.add_child(fc)
	floor_body.position = Vector3(0, -0.5, 0)
	world.add_child(floor_body)
	var wall := StaticBody3D.new()
	wall.collision_layer = G.L_WORLD
	var wc := CollisionShape3D.new()
	var ws := BoxShape3D.new()
	ws.size = Vector3(40, 30, 1)
	wc.shape = ws
	wall.add_child(wc)
	wall.position = Vector3(0, 14, -80)
	world.add_child(wall)
	var player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = Vector3(0, 1.0, 0)
	await _frames(3)
	player.head.rotation.x = deg_to_rad(10.0)
	G.set_live("p", "grapple_range", 50.0)
	_check(player._find_grapple_point().is_empty(), "tầm 50 m: tường 80 m không móc được")
	G.set_live("p", "grapple_range", 120.0)
	_check(not player._find_grapple_point().is_empty(), "tầm 120 m: móc được")
	G.set_live("t", "health_mult", 2.0)
	var t = load("res://scripts/titan.gd").new()
	t.setup("titan", 1)
	_check(is_equal_approx(t.max_health, 1200.0), "health_mult 2 -> máu Titan 1200")
	t.free()

	print("[bộ chỉnh F4]")
	var tuner = load("res://scripts/anim_tuner.gd").new()
	root.add_child(tuner)
	await _frames(2)
	_check(tuner._rows.has("p.grapple_range") and tuner._rows.has("b.accel") and tuner._rows.has("t.nape_mult"), "có hàng chỉnh cho grapple, bot, Titan")
	_check(tuner.set_value("p.grapple_pull_max", 77.0) and is_equal_approx(float(G.PLAYER["grapple_pull_max"]), 77.0), "kéo thanh trượt đổi giá trị thật")
	_check(tuner.export_text().contains("p.grapple_pull_max = 77.0"), "Xuất liệt kê giá trị đã đổi")
	tuner.apply_titan_preset("easy")
	_check(is_equal_approx(float(G.TITAN["health_mult"]), 0.7) and is_equal_approx(float(G.TITAN["windup_mult"]), 1.3), "preset Titan dễ")
	tuner.apply_titan_preset("hard")
	_check(is_equal_approx(float(G.TITAN["health_mult"]), 1.4) and is_equal_approx(float(G.TITAN["windup_mult"]), 0.8), "preset Titan khó")
	_check(is_equal_approx((tuner._rows["t.health_mult"]["slider"] as HSlider).value, 1.4), "preset đồng bộ thanh trượt")

	print("[lưu và nạp]")
	var saved: int = G.save_live()
	_check(saved == G.live_changed().size() and saved >= 4, "Lưu ghi %d giá trị" % saved)
	var before: Dictionary = G.live_changed()
	G.reset_live()
	_check(G.live_changed().is_empty(), "đặt lại về mặc định")
	var n: int = G.load_live()
	_check(n == before.size() and is_equal_approx(float(G.PLAYER["grapple_pull_max"]), 77.0), "nạp lại đúng %d giá trị" % n)
	var cf := ConfigFile.new()
	cf.set_value("p", "grapple_range", "xấu")
	cf.set_value("p", "gravity", 5.0)
	cf.set_value("zz", "a", 1.0)
	cf.save(G.LIVE_PATH)
	G.reset_live()
	_check(G.load_live() == 0 and G.live_changed().is_empty(), "file hỏng / khoá lạ bị bỏ qua")
	tuner.reset_all()
	_check(G.live_changed().is_empty(), "Đặt lại trong bộ chỉnh đưa mọi giá trị về mặc định")
	_check(is_equal_approx(float(G.PLAYER["grapple_range"]), d0), "tầm móc về mặc định (%.0f)" % d0)
	G.save_live()   # không còn gì đổi -> xoá file
	_check(not FileAccess.file_exists(G.LIVE_PATH), "không còn thay đổi: file tuning bị xoá")

	print("[F3]")
	var po = load("res://scripts/perf_overlay.gd").new()
	root.add_child(po)
	var txt: String = po._game_stats()
	_check(txt.begins_with("bot "), "dòng F3 có số bot (%s)" % txt)
	G.set_live("b", "accel", 40.0)
	_check(po._game_stats().contains("tuning 1"), "dòng F3 báo có giá trị đang chỉnh")
	G.reset_live()
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
