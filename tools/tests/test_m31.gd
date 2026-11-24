extends SceneTree
## M31: kiểm tra tổng thể (smoke) - mọi chế độ x mọi bản đồ vào/ra, vào lại không rò, nhiều wave có Titan, chồng tính năng.
## Lỗi script hiện qua "SCRIPT ERROR"/"ERROR:" trên stderr (bộ chạy dùng grep để bắt).
##   timeout 280 godot --headless --path . -s tools/tests/test_m31.gd

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


func _nodes() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func _maps() -> int:
	return NavigationServer3D.get_maps().size()


func _enter(map_id: String, mode_id: String, start_wave: int = 1) -> Node:
	G.selected_map = map_id
	G.set_mode(mode_id)
	G.start_wave = start_wave
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(15)
	return main


func _leave(main: Node) -> void:
	main.queue_free()
	await _frames(10)


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://m31.cfg"
	G.reduced_fx = false

	print("[mọi chế độ x mọi bản đồ: vào, chạy, ra]")
	var base_nodes: int = _nodes()
	var base_maps: int = -1   # ghi sau lần vào đầu tiên (bản đồ nav mặc định của World3D tạo lười)
	var base_orph: int = _orphans()
	var combos: int = 0
	for mode_id in G.MODES:
		for map_id in G.MAP_IDS:
			var main = await _enter(map_id, mode_id)
			var ok: bool = is_instance_valid(main.player) and main.arena.map_id == ("endless" if mode_id == "endless" else map_id) and main.mode != null
			main.waves.start()
			await _frames(60)
			ok = ok and main.waves.wave >= 1
			_check(ok, "%s / %s: vào trận, wave bắt đầu (wave %d, %d bot)" % [mode_id, map_id, main.waves.wave, get_nodes_in_group("bots").size()])
			await _leave(main)
			if base_maps < 0:
				base_maps = _maps()
			combos += 1
	_check(combos == G.MODES.size() * G.MAP_IDS.size(), "đã chạy %d tổ hợp" % combos)
	_check(_nodes() == base_nodes, "sau khi thoát hết: không còn node thừa (%d so với %d)" % [_nodes(), base_nodes])
	_check(_maps() == base_maps, "không rò bản đồ nav (%d so với %d)" % [_maps(), base_maps])
	_check(_orphans() <= base_orph, "không có node mồ côi mới (%d so với %d)" % [_orphans(), base_orph])

	print("[vào lại cùng bản đồ nhiều lần: không tích tụ]")
	var after_first: int = -1
	for i in 4:
		var main2 = await _enter("district", "survival", 5)
		main2.waves.start()
		await _frames(90)
		await _leave(main2)
		if after_first < 0:
			after_first = _nodes()
	_check(_nodes() == after_first and _nodes() == base_nodes, "4 lần vào/ra Khu phố: node ổn định (%d)" % _nodes())
	_check(_maps() == base_maps, "nav map ổn định sau 4 lần (%d)" % _maps())

	print("[bot đầu tiên không làm giật khung (nạp nền model)]")
	var mw = await _enter("yard", "survival")
	await _frames(30)   # chờ luồng nền nạp xong
	var t0: int = Time.get_ticks_usec()
	mw.waves._spawn("swordsman")
	var spawn_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	_check(spawn_ms < 40.0, "sinh bot gltf đầu tiên %.1f ms (< 40 ms; không nạp nền thì ~100 ms)" % spawn_ms)
	await _leave(mw)

	print("[nhiều wave trên Khu phố, qua wave 5 có Titan]")
	var main3 = await _enter("district", "survival", 4)
	var pl = main3.player
	pl.use_input = false
	pl.hurtbox.max_health = 1e9
	pl.hurtbox.health = 1e9
	main3.waves.break_time = 0.5
	main3.waves.start()
	var saw_titan: bool = false
	var frames: int = 0
	var phys_sum: float = 0.0
	var phys_n: int = 0
	var phys_max: float = 0.0
	var bots_max: int = 0
	var stuck_frames: int = 0
	var phys_max_late: float = 0.0
	var last_progress: int = 0
	var last_wave: int = 0
	var last_left: int = -1
	while main3.waves.wave <= 6 and frames < 60 * 420:
		await physics_frame
		frames += 1
		var fm: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		if frames > 40:
			if frames > 300:
				phys_max_late = maxf(phys_max_late, fm)
			phys_sum += fm
			phys_n += 1
			phys_max = maxf(phys_max, fm)
		var bots: Array = get_nodes_in_group("bots")
		bots_max = maxi(bots_max, bots.size())
		for b in bots:
			if b.get("type_name") == "titan":
				saw_titan = true
		if pl.global_position.y < main3.arena.void_y + 2.0:
			pl.global_position = main3.arena.spawn_point
		if frames % 120 == 0:
			for b in bots:
				if not b.dead:
					# Titan: sát thương lớn vào hộp trúng gáy (vùng chí mạng) để hạ được trong mô phỏng
					b.hurtbox.take_hit({"damage": 99999.0, "kind": "x", "source": null, "direction": Vector3.ZERO})
					break
		# wave không tiến triển quá lâu = kẹt
		var left: int = bots.size()
		if main3.waves.wave != last_wave or left != last_left:
			last_progress = frames
			last_wave = main3.waves.wave
			last_left = left
		stuck_frames = maxi(stuck_frames, frames - last_progress)
	_check(main3.waves.wave >= 6, "đạt wave %d trong %d khung (%.0f s mô phỏng)" % [main3.waves.wave, frames, frames / 60.0])
	_check(saw_titan, "Titan xuất hiện ở wave 5")
	_check(stuck_frames < 60 * 120, "không kẹt: khoảng im lặng dài nhất %.0f s" % (stuck_frames / 60.0))
	print("   SỐ ĐO (headless, chỉ logic, không GPU): physics TB %.2f ms, tệ nhất %.1f ms, bot tối đa %d, bake nav %d ms, tệ nhất sau 5 s: %.1f ms (khung đầu của vòng lặp có thể đọc lẫn số liệu lúc nạp màn)" % [phys_sum / maxf(phys_n, 1.0), phys_max, bots_max, int(main3.arena.nav_bake_ms), phys_max_late])
	_check(phys_sum / maxf(phys_n, 1.0) < 25.0, "physics trung bình < 25 ms")
	_check(int(main3.arena.nav_bake_ms) < 1500, "bake navmesh Khu phố < 1.5 s (%d ms)" % int(main3.arena.nav_bake_ms))

	print("[chồng tính năng ngẫu nhiên: không lỗi, không kẹt]")
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var vm = pl.viewmodel
	var fin: bool = true
	for f in 900:
		match rng.randi() % 60:
			0: G.reduced_fx = not G.reduced_fx
			1: G.settings["cam_fx"] = [0.0, 1.0, 2.0][rng.randi() % 3]
			2: vm.set_weapon(["pistol", "shotgun", "launcher", "sniper"][rng.randi() % 4], true)
			3: vm.set_reloading(rng.randf() > 0.5)
			4: vm.kick()
			5: vm.play_swing(0.18, 0.1, 0.25)
			6: pl.parry_react(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized())
			7: vm.parry_hit()
			8: vm.parry_fail()
			9: vm.ledge()
			10: pl.global_position = main3.arena.spawn_point + Vector3(rng.randf_range(-20, 20), 0.5, rng.randf_range(-20, 20))
		await physics_frame
		fin = fin and is_finite(pl.global_position.x) and is_finite(pl.camera.fov) and is_finite(pl.camera.rotation.x)
	G.reduced_fx = false
	G.settings["cam_fx"] = 1.0
	_check(fin, "900 khung chồng tính năng: vị trí/camera luôn hữu hạn")
	await _leave(main3)
	_check(_nodes() == base_nodes, "thoát sạch sau cùng (%d so với %d)" % [_nodes(), base_nodes])
	_check(_maps() == base_maps, "nav map về như đầu (%d so với %d)" % [_maps(), base_maps])

	G.start_wave = 1
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://m31.cfg"))
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
