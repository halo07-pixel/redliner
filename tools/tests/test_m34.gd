extends SceneTree
## M34: chế độ Vô Tận - bản đồ lưới, tầng/chỉ tiêu/cổng, sinh bot liên tục theo vòng, dựng lại bản đồ giữa các tầng.
##   timeout 280 godot --headless --path . -s tools/tests/test_m34.gd

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


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://test_m34.cfg"
	G.load_save()
	var E: Dictionary = G.ENDLESS
	var Maps = load("res://scripts/maps.gd")
	var GM = load("res://scripts/game_mode.gd")

	print("[bản đồ: hình học]")
	var m1: Dictionary = Maps.endless(1)
	var half: float = float(E["grid"]) * float(E["cell"]) * 0.5
	_check(m1["half"] == Vector2(half, half), "kích thước %dx%d m" % [half * 2.0, half * 2.0])
	_check(half * half * 4.0 >= 5.0 * 134.0 * 134.0 * 0.99, "diện tích %d m2 >= 5 lần Khu phố (17956 m2)" % (half * half * 4.0))
	_check(m1["boxes"] == Maps.endless(1)["boxes"], "cùng tầng cho cùng bản đồ (hạt giống theo tầng)")
	_check(m1["boxes"] != Maps.endless(2)["boxes"], "tầng khác cho bản đồ khác")
	var cell: float = float(E["cell"])
	var inset: float = float(E["inset"])
	var bad_inset: int = 0
	var roles: Dictionary = {}
	for fl in [1, 2, 3, 4, 5, 6, 7, 8]:
		var md: Dictionary = Maps.endless(fl)
		for b in md["boxes"]:
			roles[b["role"]] = true
			var pos: Vector3 = b["pos"]
			var sz: Vector3 = b["size"]
			var ci: int = int(floorf((pos.x + half) / cell))
			var cj: int = int(floorf((pos.z + half) / cell))
			var lo := Vector2(-half + cell * ci + inset, -half + cell * cj + inset)
			var hi := Vector2(-half + cell * (ci + 1) - inset, -half + cell * (cj + 1) - inset)
			if pos.x - sz.x * 0.5 < lo.x - 0.01 or pos.x + sz.x * 0.5 > hi.x + 0.01 or pos.z - sz.z * 0.5 < lo.y - 0.01 or pos.z + sz.z * 0.5 > hi.y + 0.01:
				bad_inset += 1
	_check(bad_inset == 0, "8 tầng: mọi khối lùi vào >= %d m trong ô (phố rộng >= %d m, mọi ô thông nhau)" % [inset, inset * 2.0])
	var role_keys: Array = roles.keys()
	role_keys.sort()
	_check(role_keys == ["grapple", "pillar", "wall"], "chỉ có toà nhà / cột / bệ móc (%s)" % [role_keys])
	for fl in [1, 2, 3, 4, 5]:
		var md: Dictionary = Maps.endless(fl)
		var sp: Vector3 = md["spawn"]
		var ex: Vector3 = md["exit"]
		_check(absf(sp.x) > half - cell and absf(sp.z) > half - cell and absf(ex.x) > half - cell and absf(ex.z) > half - cell, "tầng %d: xuất phát và cổng ở góc" % fl)
		_check(is_equal_approx(sp.x, -ex.x) and is_equal_approx(sp.z, -ex.z), "tầng %d: cổng ở góc đối diện (xa %d m)" % [fl, sp.distance_to(ex)])
		_check(md["bot_spawns"].size() >= 40, "tầng %d: %d điểm sinh bot dọc phố" % [fl, md["bot_spawns"].size()])
	_check(Maps.endless(1)["bot_spawns"].all(func(p): return (p as Vector3).distance_to(Maps.endless(1)["spawn"]) >= float(E["start_clear"]) - 0.01), "không điểm sinh nào sát chỗ xuất phát")

	print("[luật tầng]")
	_check(GM.quota_for(1) == 15 and GM.quota_for(2) == 20 and GM.quota_for(10) == 60, "chỉ tiêu 15 + 5/tầng")
	_check(not GM.has_boss(1) and not GM.has_boss(4) and GM.has_boss(5) and GM.has_boss(10) and not GM.has_boss(0), "Titan mỗi 5 tầng")
	var gm: Node = GM.new()
	root.add_child(gm)
	var opened: Array = []
	var floors: Array = []
	var objs: Array = []
	gm.portal_opened.connect(func(f): opened.append(f))
	gm.floor_changed.connect(func(f, q): floors.append([f, q]))
	gm.objective_changed.connect(func(t): objs.append(t))
	gm.setup("endless")
	gm.start()
	_check(gm.floor_n == 1 and gm.quota == 15 and not gm.portal_open and objs[0].contains("TẦNG 1") and objs[0].contains("0 / 15"), "tầng 1, chỉ tiêu 15, mục tiêu hiện tầng")
	gm.next_floor()
	_check(gm.floor_n == 1 and floors.is_empty(), "cổng đóng: không sang tầng được")
	for i in 14:
		gm.on_kill("swordsman")
	_check(opened.is_empty(), "14/15: cổng chưa mở")
	gm.on_kill("gunner")
	_check(opened == [1] and gm.portal_open and objs[objs.size() - 1].contains("CỔNG"), "15/15: cổng mở đúng 1 lần")
	gm.on_kill("rusher")
	_check(opened == [1], "hạ thêm không mở lại cổng")
	gm.next_floor()
	_check(gm.floor_n == 2 and floors == [[2, 20]] and gm.floor_kills == 0 and not gm.portal_open and gm.kills == 16, "sang tầng 2: chỉ tiêu 20, đếm lại, tổng hạ giữ nguyên")
	gm.floor_n = 4
	gm.portal_open = true
	gm.next_floor()
	_check(gm.floor_n == 5 and gm.boss_pending and gm.quota == 35, "tầng 5 có Titan, chỉ tiêu 35")
	for i in 35:
		gm.on_kill("swordsman")
	_check(not gm.portal_open and objs[objs.size() - 1].contains("Titan"), "đủ bot nhưng Titan còn sống: cổng chưa mở")
	gm.on_kill("titan")
	_check(gm.portal_open and gm.floor_kills == 35, "hạ Titan: cổng mở (Titan không tính vào chỉ tiêu)")
	_check(gm.result_score(777) == 777, "điểm chế độ Vô Tận = điểm hạ bot")
	gm.queue_free()

	print("[Arena: nav, dựng lại tầng]")
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.map_id = "endless"
	root.add_child(arena)
	await _frames(3)
	print("  nav bake tầng 1: %d ms" % arena.nav_bake_ms)
	await _frames(20)   # navmesh mới cần ~10 khung hình để máy chủ nav đồng bộ
	_check(arena.map_id == "endless" and arena.half == Vector2(half, half), "Arena dựng map Vô Tận")
	_check(arena.dummies.is_empty() and arena.props.is_empty(), "không bia / thùng (tối giản)")
	var path: PackedVector3Array = arena.nav_path(arena.spawn_point, arena.exit_point)
	_check(path.size() >= 2 and path[path.size() - 1].distance_to(arena.exit_point) < 3.0, "có đường navmesh từ xuất phát tới cổng (%d điểm ngoặt)" % path.size())
	var base_nodes: int = _nodes()
	var ex1: Vector3 = arena.exit_point
	for fl in [2, 3, 4]:
		arena.load_floor(fl)
		await _frames(20)
		var p2: PackedVector3Array = arena.nav_path(arena.spawn_point, arena.exit_point)
		_check(arena.floor_n == fl and p2.size() >= 2 and p2[p2.size() - 1].distance_to(arena.exit_point) < 3.0, "tầng %d: dựng lại, vẫn có đường tới cổng (bake %d ms)" % [fl, arena.nav_bake_ms])
	_check(arena.exit_point != ex1 or arena.floor_n == 4, "đã sang tầng 4")
	var drift: int = absi(_nodes() - base_nodes)
	_check(drift < 120, "dựng lại 3 tầng không dồn node cũ (lệch %d node)" % drift)
	arena.queue_free()
	await _frames(5)

	print("[Vòng sinh bot]")
	var arena2: Node3D = load("res://scripts/arena.gd").new()
	arena2.map_id = "endless"
	arena2.bake_nav = false
	root.add_child(arena2)
	var pl: Node3D = load("res://scenes/player.tscn").instantiate()
	root.add_child(pl)
	pl.global_position = arena2.spawn_point
	var wm: Node = load("res://scripts/wave_manager.gd").new()
	root.add_child(wm)
	wm.stream = true
	wm.titans_enabled = true
	wm.setup(arena2, arena2.bot_spawns, arena2.spawn_band)
	var spawn_d: Array = []
	wm.bot_spawned.connect(func(b): spawn_d.append((b as Node3D).global_position.distance_to(pl.global_position)))
	wm.start()
	await _frames(1)
	_check(wm.wave == 1 and wm.stream_cap == 6, "tầng 1: tối đa 6 bot cùng lúc")
	await create_timer(1.5 * float(E["spawn_interval"]) * 14.0).timeout
	var bots: Array = get_nodes_in_group("bots")
	_check(bots.size() == 6 and wm._alive == 6, "bot sinh dần và dừng ở mức tối đa (%d, _alive %d)" % [bots.size(), wm._alive])
	var band: Vector2 = E["band"]
	var in_band: int = 0
	for d in spawn_d:
		if d >= band.x - 6.0 and d <= band.y + 6.0:
			in_band += 1
	_check(spawn_d.size() == 6 and in_band >= 5, "lúc sinh, bot ở vòng ~%d-%d m quanh người chơi (%d/%d)" % [band.x, band.y, in_band, spawn_d.size()])
	var died: Array = []
	wm.bot_killed.connect(func(b, i): died.append(b))
	var victim: Node3D = bots[0]
	victim.died.emit(victim, {})
	victim.queue_free()
	_check(died.size() == 1 and wm._alive == 5 and wm.wave == 1, "bot chết: bot_killed phát, _alive 5, không mở wave mới")
	await create_timer(2.0 * float(E["spawn_interval"])).timeout
	_check(wm._alive == 6, "bot mới bù lại tới mức tối đa (_alive %d)" % wm._alive)
	pl.global_position = Vector3(-half + 3.0, 0.0, half - 3.0) if arena2.spawn_point.x > 0.0 else Vector3(half - 3.0, 0.0, -half + 3.0)
	var alive_before: int = wm._alive
	var removed: int = wm._prune_far(float(E["despawn_dist"]))
	_check(removed >= 1 and wm._alive == alive_before - removed and wm._alive >= 0, "bot ở xa > %d m bị gỡ (%d), số đếm khớp (_alive %d)" % [E["despawn_dist"], removed, wm._alive])
	wm.begin_floor(5, true)
	await _frames(2)
	var titans: int = 0
	for b in get_nodes_in_group("bots"):
		if "is_titan" in b and not b.is_queued_for_deletion():
			titans += 1
	_check(wm.wave == 5 and wm.stream_cap == 10 and titans == 1, "tầng 5: cap 10, đúng 1 Titan (%d)" % titans)
	wm.stop()
	wm.queue_free()
	pl.queue_free()
	arena2.queue_free()
	await _frames(3)

	print("[Tích hợp main: vào cổng -> tầng 2]")
	G.set_mode("endless")
	G.start_wave = 1
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(15)
	_check(main.arena.map_id == "endless" and main.portal != null and not main.portal.is_open, "main: map Vô Tận, cổng đóng")
	_check(main.player.global_position.distance_to(main.arena.spawn_point) < 2.0, "người chơi đứng ở chỗ xuất phát")
	main._start_mode()
	await _frames(5)
	_check(main.mode.floor_n == 1 and main.waves.wave == 1, "chế độ + bot bắt đầu ở tầng 1")
	main.mode.quota = 2
	main.mode.on_kill("swordsman")
	main.mode.on_kill("swordsman")
	_check(main.portal.is_open, "đủ chỉ tiêu: main mở cổng")
	var old_exit: Vector3 = main.arena.exit_point
	var hp0: float = main.player.hurtbox.health
	main.player.hurtbox.health = hp0 * 0.5
	main.player.global_position = old_exit + Vector3(0.0, 0.5, 0.0)
	await _frames(10)
	_check(main.mode.floor_n == 2 and main.arena.floor_n == 2, "bước vào cổng: sang tầng 2")
	_check(main.player.global_position.distance_to(main.arena.spawn_point) < 2.0, "người chơi về chỗ xuất phát tầng 2")
	_check(not main.portal.is_open and main.portal.global_position.distance_to(main.arena.exit_point) < 0.1, "cổng mới đóng, đặt ở góc đối diện")
	_check(main.waves.wave == 2 and main.waves.stream_cap == 7, "bot tầng 2: tối đa 7")
	_check(main.player.hurtbox.health > hp0 * 0.5, "hồi một phần máu khi sang tầng")
	var res: Dictionary = main.build_result("TEST", false, 100, 0, false)
	_check(String(res["lines"][1]).contains("Tầng"), "màn tổng kết có dòng tầng đạt được")
	main.queue_free()
	await _frames(10)

	print("---")
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
