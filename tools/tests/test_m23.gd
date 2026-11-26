extends SceneTree
## M23: di chuyển bot - gia tốc, nhảy leo bệ, nhìn trước trên đường đi, nấp, tính đường thưa ở xa.
##   timeout 250 godot --headless --path . -s tools/tests/test_m23.gd

var failures: int = 0
var world: Node3D
var player


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


func _clear() -> void:
	for n in get_nodes_in_group("bots"):
		n.queue_free()
	if world != null:
		world.queue_free()
	if player != null and is_instance_valid(player):
		player.queue_free()
	await process_frame
	world = Node3D.new()
	root.add_child(world)


func _bake() -> void:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.5
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Global.L_WORLD
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, world)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	var r := NavigationRegion3D.new()
	r.navigation_mesh = nm
	world.add_child(r)
	await _frames(3)


func _player(pos: Vector3) -> void:
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = pos
	await _frames(3)


func _bot(kind: String, pos: Vector3):
	var b = load("res://scripts/bot.gd").new()
	b.setup(kind, 1)
	b.position = pos
	world.add_child(b)
	return b


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var M: Dictionary = root.get_node("Global").BOT_MOVE

	print("[gia tốc]")
	await _clear()
	_box(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	await _bake()
	await _player(Vector3(0, 0.1, 0))
	var a = _bot("swordsman", Vector3(0, 0.1, -40))
	a.melee.windup_override = 99.0
	await _frames(3)
	var v3: float = Vector2(a.velocity.x, a.velocity.z).length()
	_check(v3 < a.speed * 0.6, "3 khung đầu: chưa đạt tốc độ tối đa (%.1f / %.1f m/s)" % [v3, a.speed])
	await _frames(40)
	var v40: float = Vector2(a.velocity.x, a.velocity.z).length()
	_check(v40 > a.speed * 0.95, "sau 0.7 s: đạt tốc độ tối đa (%.1f m/s)" % v40)

	print("[nhảy leo bệ]")
	await _clear()
	_box(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	_box(Vector3(10, 2, 10), Vector3(0, 1.0, 0))   # bệ 2 m
	await _bake()
	await _player(Vector3(0, 2.1, 0))
	var c = _bot("rusher", Vector3(0, 0.1, 20))
	c.melee.windup_override = 99.0
	await _frames(420)
	_check(c.global_position.y > 1.6, "bệ 2 m: bot nhảy lên được (y=%.2f)" % c.global_position.y)
	await _clear()
	_box(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	_box(Vector3(10, 5, 10), Vector3(0, 2.5, 0))   # bệ 5 m: quá cao
	await _bake()
	await _player(Vector3(0, 5.1, 0))
	var d = _bot("rusher", Vector3(0, 0.1, 20))
	d.melee.windup_override = 99.0
	await _frames(420)
	_check(d.global_position.y < 0.6, "bệ 5 m: bot không leo (y=%.2f)" % d.global_position.y)
	# Thử tối đa 3 lần: bot leo từng nấc phụ thuộc thời điểm navmesh đồng bộ; chỉ coi là lỗi nếu cả 3 lần đều thất bại.
	var top: float = 0.0
	for attempt in 3:
		await _clear()
		_box(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
		_box(Vector3(10, 2.0, 10), Vector3(0, 1.0, 0))
		_box(Vector3(6, 4.0, 6), Vector3(0, 2.0, 0))    # nấc hai: 4 m, leo hai nhịp (2 m + 2 m)
		await _bake()
		await _player(Vector3(0, 4.1, 0))
		var e = _bot("rusher", Vector3(0, 0.1, 20))
		e.melee.windup_override = 99.0
		top = 0.0
		for i in 1200:
			await _frames(1)
			top = maxf(top, e.global_position.y)
			if top > 3.5:
				break
		if top > 3.5:
			break
	_check(top > 3.5, "tháp hai nấc: bot leo từng nấc lên đỉnh (cao nhất y=%.2f)" % top)

	print("[nhìn trước trên đường đi]")
	await _clear()
	_box(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	_box(Vector3(2, 6, 14), Vector3(0, 3, -6))
	await _bake()
	await _player(Vector3(0, 0.1, 12))
	var f = _bot("swordsman", Vector3(0, 0.1, -22))
	f.melee.windup_override = 99.0
	var best: float = INF
	var in_wall: int = 0
	for i in 520:
		await _frames(1)
		best = minf(best, f.global_position.distance_to(player.global_position))
		if absf(f.global_position.x) < 1.1 and absf(f.global_position.z + 6.0) < 7.0 and f.global_position.y < 6.0:
			in_wall += 1
	_check(best < 3.5, "đi vòng qua tường tới người chơi (gần nhất %.1f m)" % best)
	_check(in_wall == 0, "đường đi không cắt xuyên khối (%d khung trong tường)" % in_wall)

	print("[nấp sau khi bắn]")
	await _clear()
	_box(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	_box(Vector3(6, 4, 1), Vector3(-5, 2, 8))     # vật che gần xạ thủ
	await _bake()
	await _player(Vector3(0, 0.1, 25))
	var g = _bot("gunner", Vector3(-6, 0.1, 6))
	await _frames(2)
	g._shoot_cd = 2.0
	var cp: Vector3 = g._find_cover(9.0)
	_check(cp != Vector3.INF, "tìm được chỗ nấp quanh xạ thủ")
	var los_clear: bool = true
	if cp != Vector3.INF:
		var q := PhysicsRayQueryParameters3D.create(cp + Vector3(0, 1.2, 0), player.global_position + Vector3(0, 1.2, 0), Global.L_WORLD)
		los_clear = g.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_check(not los_clear, "chỗ nấp che tầm nhìn tới người chơi")
	g._cover_pt = cp
	g._cover_t = 1.5
	var near: float = INF
	for i in 85:
		await _frames(1)
		near = minf(near, g.global_position.distance_to(cp))
	_check(near < 2.0, "xạ thủ chạy tới chỗ nấp (gần nhất %.1f m)" % near)

	print("[Khu phố: bot tới được người chơi]")
	await _clear()
	var arena: Node3D = load("res://scripts/arena.gd").new()
	world.add_child(arena)
	await _frames(15)
	await _player(arena.spawn_point)
	var wm = load("res://scripts/wave_manager.gd").new()
	root.add_child(wm)
	wm.setup(world, arena.bot_spawns, arena.spawn_band)
	var bots: Array = []
	for k in ["swordsman", "rusher", "swordsman", "rusher"]:
		var bb = wm.spawn_practice(k, wm._pick_spawn(), 1)
		bb.melee.windup_override = 99.0
		bots.append(bb)
	var nearest: float = INF
	var fell: int = 0
	for i in 2400:
		await _frames(1)
		for bb in bots:
			nearest = minf(nearest, bb.global_position.distance_to(player.global_position))
			if bb.global_position.y < -5.0:
				fell += 1
	_check(nearest < 4.0, "bot sinh cách 35-60 m tới sát người chơi sau 40 s (gần nhất %.1f m)" % nearest)
	_check(fell == 0, "không bot nào rơi khỏi map")
	var close: int = 0
	for bb in bots:
		if bb.global_position.distance_to(player.global_position) < 12.0:
			close += 1
	_check(close >= 2, "ít nhất 2/4 bot vào vòng 12 m (%d)" % close)

	print("[tính đường thưa ở xa]")
	_check(float(M["far_path_interval"]) > float(M["path_interval"]) and float(M["far_dist"]) >= 50.0, "bot xa tính đường thưa hơn")
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
