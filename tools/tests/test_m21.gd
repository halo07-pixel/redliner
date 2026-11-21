extends SceneTree
## M21: map lớn "Khu phố" - bố cục hợp lệ, navmesh nối tới mọi điểm sinh, bake nhanh, điểm sinh theo vòng, la bàn.

var _fails: int = 0

func _check(ok: bool, msg: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + msg)
	if not ok:
		_fails += 1

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var Maps: GDScript = load("res://scripts/maps.gd")
	var d: Dictionary = Maps.get_map("district")
	var h: Vector2 = d["half"]
	print("[bố cục]")
	_check(h.x * h.y * 4.0 >= 5.0 * 3600.0 * 0.95, "diện tích >= ~5x Sân tập (%d m2)" % int(h.x * h.y * 4.0))
	var bad: int = 0
	for b in d["boxes"]:
		var sz: Vector3 = b["size"]
		var p: Vector3 = b["pos"]
		if absf(p.x) + sz.x * 0.5 > h.x + 0.01 or absf(p.z) + sz.z * 0.5 > h.y + 0.01:
			bad += 1
	_check(bad == 0, "mọi khối nằm trong biên (%d lỗi)" % bad)
	_check(d["bot_spawns"].size() >= 12, "đủ điểm sinh bot (%d)" % d["bot_spawns"].size())
	_check(str(Maps.get_map("district")) == str(d), "bố cục xác định (cùng kết quả)")
	var sp: Vector3 = d["spawn"]
	var inside: int = 0
	for p in d["bot_spawns"]:
		for b in d["boxes"]:
			var sz: Vector3 = b["size"]
			var bp: Vector3 = b["pos"]
			if absf(p.x - bp.x) < sz.x * 0.5 and absf(p.z - bp.z) < sz.z * 0.5:
				inside += 1
	_check(inside == 0, "không điểm sinh nào nằm trong khối (%d)" % inside)

	print("[navmesh]")
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.map_id = "district"
	root.add_child(arena)
	await _frames(15)
	print("  bake ", arena.nav_bake_ms, " ms")
	_check(arena.nav_bake_ms < 8000, "bake < 8 s (%d ms)" % arena.nav_bake_ms)
	var np: PackedVector3Array = arena.nav_path(sp, d["bot_spawns"][0])
	for w in 200:   # navmesh đồng bộ vào map nav chậm hơn khi máy bận: đợi tới khi có đường
		if np.size() > 0:
			break
		await _frames(1)
		np = arena.nav_path(sp, d["bot_spawns"][0])
	print("  path0 size ", np.size(), " last ", np[np.size() - 1] if np.size() > 0 else "-", " target ", d["bot_spawns"][0], " polys ", (arena.nav_region.navigation_mesh.get_polygon_count()))
	var unreachable: int = 0
	for p in arena.bot_spawns:
		var path: PackedVector3Array = arena.nav_path(sp, p)
		if path.size() < 2 or path[path.size() - 1].distance_to(p) > 2.5:
			unreachable += 1
	_check(unreachable == 0, "người chơi tới được mọi điểm sinh bằng navmesh (%d không tới được)" % unreachable)
	_check(arena.spawn_band == Vector2(35.0, 60.0) and arena.compass, "map đọc spawn_band + compass")
	arena.queue_free()

	print("[điểm sinh theo vòng]")
	var W: GDScript = load("res://scripts/wave_manager.gd")
	var w: Node = W.new()
	root.add_child(w)
	w.setup(Node3D.new(), d["bot_spawns"], Vector2(35.0, 60.0))
	var player := Node3D.new()
	player.add_to_group("player")
	root.add_child(player)
	player.global_position = sp
	var in_band: int = 0
	for i in 40:
		var p: Vector3 = w._pick_spawn()
		var dist: float = p.distance_to(sp)
		if dist >= 35.0 and dist <= 60.0:
			in_band += 1
	_check(in_band == 40, "40/40 lần chọn nằm trong 35..60 m (%d)" % in_band)
	var w2: Node = W.new()
	root.add_child(w2)
	w2.setup(Node3D.new(), d["bot_spawns"])
	_check(w2._pick_spawn() != Vector3.INF, "không có band: cách cũ vẫn chạy")

	print("[la bàn HUD]")
	var hud = load("res://scripts/hud.gd").new()
	root.add_child(hud)
	await _frames(1)
	hud.set_compass(true, 0.0, 42.0)
	_check(hud._compass_label.visible and hud._compass_label.text.contains("42"), "la bàn hiện khoảng cách")
	hud.set_compass(false, 0.0, 0.0)
	_check(not hud._compass_label.visible, "la bàn tắt khi không có kẻ địch")
	print("FAIL: ", _fails)
	quit(1 if _fails > 0 else 0)
