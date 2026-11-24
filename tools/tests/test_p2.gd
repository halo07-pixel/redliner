extends SceneTree
## P2: chủ đề môi trường theo tầng (Vô Tận).
##   timeout 200 godot --headless --path . -s tools/tests/test_p2.gd

var failures: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var G = root.get_node("Global")
	G.save_path = "user://test_p2.cfg"
	G.load_save()
	var Look = load("res://scripts/endless_look.gd")
	var n: int = Look.THEMES.size()
	_check(n == 6, "6 chủ đề")
	_check(Look.theme_index(1) == 0 and Look.theme_index(6) == 5 and Look.theme_index(7) == 0 and Look.theme_index(13) == 0, "tầng -> chủ đề, lặp vòng")
	var skies: Dictionary = {}
	var ok_floor: bool = true
	for i in n:
		var e: Dictionary = Look.theme_env(i)
		skies[e["sky_horizon"]] = true
		if float(e["sun_energy"]) < Look.MIN_SUN - 0.0001 or float(e["ambient_energy"]) < Look.MIN_AMBIENT - 0.0001:
			ok_floor = false
	_check(skies.size() == n, "6 chủ đề có trời khác nhau")
	_check(ok_floor, "mọi chủ đề giữ sàn độ sáng (không tối quá)")
	var d0: Dictionary = Look.theme_env(0)
	_check(is_equal_approx(float(d0["sun_energy"]), float(G.ENV["sun_energy"])) and d0["sky_top"] == G.ENV["sky_top"], "tầng 1 = môi trường gốc")
	var accents: Dictionary = {}
	for i in n:
		accents[Look.theme_accent(i)] = true
	_check(accents.size() == n, "6 màu viền khác nhau")

	# Arena Vô Tận: tầng 1 áp ngay, đổi tầng + reduced_fx -> áp tức thì, không reduced_fx -> chuyển mượt
	var a: Node3D = load("res://scripts/arena.gd").new()
	a.map_id = "endless"
	a.floor_n = 1
	a.bake_nav = false
	root.add_child(a)
	await physics_frame
	var sm: ProceduralSkyMaterial = a.world_env.sky.sky_material
	_check(sm.sky_horizon_color.is_equal_approx(G.ENV["sky_horizon"]), "tầng 1: trời gốc")
	G.reduced_fx = true
	a.load_floor(4)
	var e4: Dictionary = Look.theme_env(3)
	_check(sm.sky_horizon_color.is_equal_approx(e4["sky_horizon"]) and is_equal_approx(a.sun.light_energy, float(e4["sun_energy"])), "giảm hiệu ứng: tầng 4 (đêm) áp tức thì")
	_check(is_equal_approx(a.world_env.fog_density, float(e4["fog_density"]) * 0.6), "sương giữ hệ số 0.6 của Vô Tận")
	_check(a.sun.light_energy >= Look.MIN_SUN - 0.0001 and a.world_env.ambient_light_energy >= Look.MIN_AMBIENT - 0.0001, "đêm vẫn đủ sáng")
	G.reduced_fx = false
	a.load_floor(5)
	var from_h: Color = sm.sky_horizon_color
	await physics_frame
	var mid_h: Color = sm.sky_horizon_color
	_check(mid_h.is_equal_approx(from_h) or not mid_h.is_equal_approx(Look.theme_env(4)["sky_horizon"]), "không giảm hiệu ứng: chưa nhảy thẳng tới đích")
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(Look.THEME_BLEND_SEC * 1000.0) + 600:
		await process_frame
	_check(sm.sky_horizon_color.is_equal_approx(Look.theme_env(4)["sky_horizon"]), "sau khi chuyển: tới đúng chủ đề tầng 5")
	# đổi tầng giữa chừng không để tween cũ ghi đè
	a.load_floor(6)
	a.load_floor(1)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(Look.THEME_BLEND_SEC * 1000.0) + 600:
		await process_frame
	_check(sm.sky_horizon_color.is_equal_approx(G.ENV["sky_horizon"]), "đổi tầng liên tiếp: kết thúc ở chủ đề tầng cuối")
	# viền nóc theo chủ đề: dress() nhận chủ đề
	var m: Dictionary = load("res://scripts/maps.gd").endless(2)
	var layers: Array = Look.dress(m, 2)
	var c: Color = ((layers[0].multimesh.mesh as BoxMesh).material as StandardMaterial3D).albedo_color
	var acc: Color = Look.theme_accent(2)
	_check(is_equal_approx(c.r / float(Look.LOOK["roof_energy"]), acc.r), "viền nóc dùng màu chủ đề")
	a.queue_free()
	# map khác không đổi môi trường
	var y: Node3D = load("res://scripts/arena.gd").new()
	y.map_id = "yard"
	y.bake_nav = false
	root.add_child(y)
	await physics_frame
	_check((y.world_env.sky.sky_material as ProceduralSkyMaterial).sky_horizon_color.is_equal_approx(G.ENV["sky_horizon"]), "map yard giữ môi trường gốc")
	y.queue_free()
	await physics_frame
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
