extends SceneTree
## M33: spam grapple không tăng tốc vô hạn.
##   timeout 200 godot --headless --path . -s tools/tests/test_m33.gd

var failures: int = 0
var player
var world: Node3D


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _box(size: Vector3, pos: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = Global.L_WORLD
	b.position = pos
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	world.add_child(b)


func _reset(pos: Vector3) -> void:
	if player != null:
		player.queue_free()
		await process_frame
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = pos
	await _frames(3)
	player.velocity = Vector3.ZERO


func _initialize() -> void:
	_run()


func _spam(seconds: float) -> float:
	var peak: float = 0.0
	var frames: int = int(seconds * 60.0)
	for i in frames:
		# bấm 6 khung, nhả 6 khung (spam ~5 lần/giây); luôn nhìn về phía tường -Z
		player.want_grapple = (i % 12) < 6
		await physics_frame
		peak = maxf(peak, player.horizontal_speed())
		if player.global_position.z < -75.0: # tới tường: quay đầu bay ngược lại bằng cách dịch lại
			player.global_position = Vector3(player.global_position.x, 12.0, -20.0)
	return peak


func _release_chain(G, cap: float) -> float:
	G.PLAYER["grapple_soft_cap"] = cap
	await _reset(Vector3(0, 400.0, 0))
	player.velocity = Vector3(0, 0, -25.0)
	var peak: float = 0.0
	for k in 12:
		player._grapple_taut = true
		player._release_redirect()
		for i in 12:
			player.velocity.y = 0.0
			await physics_frame
			peak = maxf(peak, player.horizontal_speed())
	return peak


func _run() -> void:
	await process_frame
	var G = root.get_node("Global")
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(400, 1, 400), Vector3(0, -0.5, 0))
	_box(Vector3(60, 40, 1), Vector3(0, 20, -80))

	print("[cấu hình]")
	var cap: float = float(G.PLAYER["grapple_soft_cap"])
	_check(cap > 20.0 and cap < 45.0, "trần mềm %.0f m/s hợp lý" % cap)
	_check(float(G.PLAYER["fov_speed_max"]) < 18.0, "FOV nở tối đa nhỏ hơn bản cũ (18)")

	print("[móc đơn vẫn mạnh]")
	await _reset(Vector3(0, 12.0, -20))
	player.want_grapple = true
	var single_peak: float = 0.0
	for i in 70:
		await physics_frame
		single_peak = maxf(single_peak, player.velocity.length())
	player.want_grapple = false
	_check(single_peak > 22.0, "một lần móc đạt %.1f m/s" % single_peak)

	print("[spam 10 giây]")
	await _reset(Vector3(0, 12.0, -20))
	var peak: float = await _spam(10.0)
	_check(peak < cap * 1.12, "tốc độ ngang đỉnh %.1f <= trần %.0f (+12%% dung sai)" % [peak, cap])

	print("[chuỗi nhả móc khi dây căng: boost không cộng dồn]")
	var peak_chain: float = await _release_chain(G, cap)
	G.PLAYER["grapple_soft_cap"] = 9999.0   # đối chứng: không trần = hành vi cũ
	var peak_old: float = await _release_chain(G, 9999.0)
	G.PLAYER["grapple_soft_cap"] = cap
	_check(peak_old > cap * 1.5, "đối chứng: bản cũ cộng dồn tới %.1f m/s" % peak_old)
	_check(peak_chain < cap * 1.1, "bản mới đỉnh %.1f <= trần %.0f (+10%%)" % [peak_chain, cap])

	print("[hãm mềm, không chặn cứng]")
	await _reset(Vector3(0, 30.0, 0))
	player.velocity = Vector3(0, 0, -(cap + 20.0))
	var v0: float = player.horizontal_speed()
	await _frames(1)
	var v1: float = player.horizontal_speed()
	await _frames(30)
	var v2: float = player.horizontal_speed()
	_check(v1 < v0 and v1 > v0 - 3.0, "một khung chỉ giảm nhẹ (%.1f -> %.1f)" % [v0, v1])
	_check(v2 < cap + 10.0 and v2 >= cap - 0.5, "sau 0.5 giây gần trần (%.1f)" % v2)

	print("[dưới trần không bị ảnh hưởng]")
	await _reset(Vector3(0, 30.0, 0))
	player.velocity = Vector3(0, 0, -20.0)
	await _frames(1)
	_check(absf(player.horizontal_speed() - 20.0) < 0.5, "20 m/s giữ nguyên (%.2f)" % player.horizontal_speed())

	print("[cooldown chuỗi]")
	await _reset(Vector3(0, 12.0, -20))
	var cd0: float = 0.0
	for k in 5:
		player.global_position = Vector3(0, 12.0, -20)
		player.velocity = Vector3.ZERO
		player.want_grapple = true
		await _frames(10)
		player.want_grapple = false
		await _frames(2)
		if k == 0:
			cd0 = player._grapple_cd
		await _frames(int(player._grapple_cd * 60.0) + 2)
	player.want_grapple = true
	await _frames(10)
	player.want_grapple = false
	await _frames(2)
	_check(player._grapple_chain >= 4.0, "đếm chuỗi (%.1f)" % player._grapple_chain)
	_check(player._grapple_cd > cd0 + 0.1, "cooldown tăng khi móc liên tục (%.2f > %.2f)" % [player._grapple_cd, cd0])
	await _frames(720)
	_check(player._grapple_chain < 1.0, "chuỗi hồi lại khi nghỉ (%.2f)" % player._grapple_chain)

	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
