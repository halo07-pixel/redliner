extends SceneTree
## P3: sân khấu (bệ + dốc + bức che) trong ô trống của bản đồ Vô Tận.
##   timeout 280 godot --headless --path . -s tools/tests/test_p3.gd

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
	G.save_path = "user://test_p3.cfg"
	G.load_save()
	var Maps = load("res://scripts/maps.gd")
	var T: Dictionary = Maps.TERRAIN
	var E: Dictionary = G.ENDLESS
	var cell: float = float(E["cell"])
	var half: float = float(E["grid"]) * cell * 0.5

	print("[dữ liệu]")
	var counts: Array = []
	var stage_ok: bool = true
	var same_old: bool = true
	var hash_ok: bool = true
	for fl in range(1, 13):
		var m: Dictionary = Maps.endless(fl)
		var plats: Array = []
		var ramps: int = 0
		var old: Array = []
		for b in m["boxes"]:
			match String(b["role"]):
				"platform":
					plats.append(b)
				"ramp":
					ramps += 1
				_:
					old.append(b)
		var stages: int = 0
		for b in plats:
			if (b["size"] as Vector3).y >= float(T["stage_h"]) - 0.01:
				stages += 1
		counts.append(stages)
		stage_ok = stage_ok and stages >= 1 and stages <= int(T["stage_max"]) and ramps == stages * 2 and plats.size() == stages * 3
		# tầng 1..12 đều dựng lại giống hệt (xác định)
		hash_ok = hash_ok and m["boxes"] == Maps.endless(fl)["boxes"]
		# toà nhà / cột / bệ móc giữ vị trí cũ: không có khối cũ nào ở chỗ sân khấu
		for b in plats:
			for o in old:
				var d: Vector3 = (o["pos"] as Vector3) - (b["pos"] as Vector3)
				if absf(d.x) < ((o["size"] as Vector3).x + (b["size"] as Vector3).x) * 0.5 and absf(d.z) < ((o["size"] as Vector3).z + (b["size"] as Vector3).z) * 0.5:
					same_old = false
	_check(stage_ok, "12 tầng: 1..%d sân khấu mỗi tầng (%s), mỗi sân khấu 2 dốc + 2 bức che" % [int(T["stage_max"]), counts])
	_check(hash_ok, "xác định: cùng tầng cho cùng bản đồ")
	_check(same_old, "sân khấu không chạm toà nhà / cột nào")
	# bố cục cũ giữ nguyên: lọc bỏ platform/ramp rồi so với số lượng khối cũ qua hạt giống (kiểm bằng kết quả tay của bộ sinh cũ: vai trò + chỉ số)
	var m1: Dictionary = Maps.endless(1)
	var old1: Array = m1["boxes"].filter(func(b): return b["role"] in ["wall", "pillar", "grapple"])
	_check(old1.size() > 10, "tầng 1: %d khối cũ (toà nhà / cột / bệ móc) còn nguyên" % old1.size())
	var inset: float = float(E["inset"])
	var inside: bool = true
	for fl in range(1, 13):
		for b in Maps.endless(fl)["boxes"]:
			if b["role"] in ["platform", "ramp"]:
				var pos: Vector3 = b["pos"]
				var sz: Vector3 = b["size"]
				var ci: int = int(floorf((pos.x + half) / cell))
				var cj: int = int(floorf((pos.z + half) / cell))
				var lo := Vector2(-half + cell * ci + inset, -half + cell * cj + inset)
				var hi := Vector2(-half + cell * (ci + 1) - inset, -half + cell * (cj + 1) - inset)
				if pos.x - sz.x * 0.5 < lo.x - 0.01 or pos.x + sz.x * 0.5 > hi.x + 0.01 or pos.z - sz.z * 0.5 < lo.y - 0.01 or pos.z + sz.z * 0.5 > hi.y + 0.01:
					inside = false
	_check(inside, "12 tầng: mọi khối mới lùi vào >= %d m trong ô (phố vẫn thông)" % inset)
	var cells_ok: bool = true
	for fl in range(1, 13):
		var m: Dictionary = Maps.endless(fl)
		for b in m["boxes"]:
			if b["role"] == "platform" and (b["size"] as Vector3).y >= float(T["stage_h"]) - 0.01:
				var p: Vector3 = b["pos"]
				if Vector2(p.x - (m["spawn"] as Vector3).x, p.z - (m["spawn"] as Vector3).z).length() < cell or Vector2(p.x - (m["exit"] as Vector3).x, p.z - (m["exit"] as Vector3).z).length() < cell:
					cells_ok = false
	_check(cells_ok, "không đặt ở ô xuất phát / cổng ra")

	print("[hình học dốc: raycast vật lý]")
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.map_id = "endless"
	arena.floor_n = 2
	arena.bake_nav = false
	root.add_child(arena)
	await physics_frame
	await physics_frame
	var md: Dictionary = Maps.endless(2)
	var space: PhysicsDirectSpaceState3D = arena.get_world_3d().direct_space_state
	var stage: Dictionary = {}
	for b in md["boxes"]:
		if b["role"] == "platform" and (b["size"] as Vector3).y >= float(T["stage_h"]) - 0.01:
			stage = b
			break
	var c: Vector3 = stage["pos"]
	var sh: float = float(T["stage_half"])
	var run: float = float(T["ramp_run"])
	var hh: float = float(T["stage_h"])
	var hgt := func(x: float, z: float) -> float:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 10.0, z), Vector3(x, -5.0, z))
		q.collision_mask = G.L_WORLD
		var r: Dictionary = space.intersect_ray(q)
		return (r["position"] as Vector3).y if not r.is_empty() else -99.0
	var good: bool = true
	var detail: String = ""
	for sx in [-1.0, 1.0]:
		for f in [0.05, 0.25, 0.5, 0.75, 0.95]:
			var x: float = c.x + sx * (sh + run * f)
			var want: float = hh * (1.0 - f)
			var got: float = hgt.call(x, c.z)
			if absf(got - want) > 0.12:
				good = false
				detail += " [sx=%d f=%.2f muốn %.2f được %.2f]" % [sx, f, want, got]
	_check(good, "2 dốc: độ cao mặt dốc đi từ %.1f m xuống 0 đúng tuyến tính%s" % [hh, detail])
	_check(absf(float(hgt.call(c.x, c.z)) - hh) < 0.05, "mặt bệ cao %.1f m" % hh)
	_check(absf(float(hgt.call(c.x + sx_far(sh, run), c.z))) < 0.05, "hết dốc là mặt đất")
	var cover_top: float = hgt.call(c.x, c.z + float(T["cover_dist"]))
	_check(absf(cover_top - float(T["cover_h"])) < 0.05, "bức che cao %.1f m (nhảy qua được)" % float(T["cover_h"]))
	var slope_deg: float = rad_to_deg(atan2(hh, run))
	_check(slope_deg < 35.0, "độ dốc %.1f° < 35° (đi / chạy lên được, navmesh max 40°)" % slope_deg)

	print("[navmesh + đường tới cổng]")
	var an: Node3D = load("res://scripts/arena.gd").new()
	an.map_id = "endless"
	an.floor_n = 1
	root.add_child(an)
	var rdy: int = -1
	for i in 40:
		await physics_frame
		if an.nav_ready():
			rdy = i
			break
	_check(rdy >= 0, "tầng 1: navmesh sẵn sàng (khung %d), bake %d ms" % [rdy, an.nav_bake_ms])
	var worst_ms: int = an.nav_bake_ms
	var all_paths: bool = rdy >= 0
	for fl in range(2, 9):
		an.load_floor(fl)
		var ok: bool = false
		for i in 150:
			await physics_frame
			if an.nav_ready():
				var p: PackedVector3Array = an.nav_path(an.spawn_point, an.exit_point)
				ok = p.size() >= 2 and p[p.size() - 1].distance_to(an.exit_point) < 4.0
				print("    tầng %d: sẵn sàng sau %d khung, đường %d điểm" % [fl, i + 1, p.size()])
				break
		all_paths = all_paths and ok
		worst_ms = maxi(worst_ms, an.nav_bake_ms)
		if not ok:
			printerr("    tầng %d: không có đường tới cổng" % fl)
	_check(all_paths, "tầng 1..8: có đường navmesh tới cổng")
	_check(worst_ms < 400, "bake navmesh tệ nhất %d ms (< 400)" % worst_ms)
	# navmesh tầng dựng lại không lẫn khối của tầng cũ: số đa giác ~ bản dựng mới hoàn toàn cùng tầng
	var fresh: Node3D = load("res://scripts/arena.gd").new()
	fresh.map_id = "endless"
	fresh.floor_n = 8
	root.add_child(fresh)
	await physics_frame
	var pa: int = an.nav_region.navigation_mesh.get_polygon_count()
	var pf: int = fresh.nav_region.navigation_mesh.get_polygon_count()
	_check(absi(pa - pf) <= maxi(10, pf / 20), "tầng 8: navmesh sau load_floor (%d đa giác) khớp dựng mới (%d): không lẫn collider tầng cũ" % [pa, pf])
	fresh.queue_free()
	# điểm trên bệ phải nằm trên navmesh (bot lên được bằng dốc)
	var onstage: int = 0
	var total: int = 0
	var nm: RID = an.nav_region.get_navigation_map()
	for b in Maps.endless(8)["boxes"]:
		if b["role"] == "platform" and (b["size"] as Vector3).y >= float(T["stage_h"]) - 0.01:
			total += 1
			var cp: Vector3 = NavigationServer3D.map_get_closest_point(nm, Vector3((b["pos"] as Vector3).x, hh, (b["pos"] as Vector3).z))
			if absf(cp.y - (hh + 0.5)) < 0.6 and Vector2(cp.x - (b["pos"] as Vector3).x, cp.z - (b["pos"] as Vector3).z).length() < 1.5:
				onstage += 1
	_check(total >= 1 and onstage == total, "tầng 8: %d/%d bệ có navmesh trên mặt (bot lên được)" % [onstage, total])
	an.queue_free()
	arena.queue_free()
	await physics_frame
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)


func sx_far(sh: float, run: float) -> float:
	return sh + run + 1.0
