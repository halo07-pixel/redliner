extends SceneTree
## P1: diện mạo bản đồ Vô Tận (chỉ hình ảnh) + navmesh không trả đường cũ khi sang tầng.
##   timeout 280 godot --headless --path . -s tools/tests/test_p1.gd

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


func _count(node: Node, cls: String) -> int:
	var c: int = 0
	for ch in node.get_children():
		if ch.is_class(cls):
			c += 1
	return c


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://test_p1.cfg"
	G.load_save()
	var Maps = load("res://scripts/maps.gd")
	var Look = load("res://scripts/endless_look.gd")

	print("[dữ liệu bản đồ không đổi]")
	var before: Array = [Maps.endless(1)["boxes"], Maps.endless(4)["boxes"]]
	var decos: Array = Look.dress(Maps.endless(1))
	_check(Maps.endless(1)["boxes"] == before[0] and Maps.endless(4)["boxes"] == before[1], "dress() không đổi dữ liệu Maps.endless")
	for d in decos:
		d.free()

	print("[mặt tiền]")
	var variants: Dictionary = {}
	for fl in [1, 2, 3, 4, 5, 6]:
		for b in Maps.endless(fl)["boxes"]:
			if b["role"] == "wall":
				variants[Look.facade_variant(b["pos"])] = true
	_check(variants.size() >= 4, "6 tầng dùng >= 4 trong 5 tông mặt tiền (%d)" % variants.size())
	_check(Look.facade_variant(Vector3(12.0, 5.0, -30.0)) == Look.facade_variant(Vector3(12.0, 5.0, -30.0)), "tông theo vị trí, xác định")
	var wall_col: Color = G.PALETTE["wall"]
	var all_ok: bool = true
	for v in 5:
		var mt: StandardMaterial3D = Look.facade(v)
		all_ok = all_ok and mt != load("res://scripts/materials.gd").make("wall") and mt.albedo_texture != null and mt.uv1_triplanar
		all_ok = all_ok and mt.albedo_color.r <= 1.0 and mt.albedo_color.r > 0.15
	_check(all_ok, "5 tông: bản sao của 'wall' (triplanar, có họa tiết), không đổi vật liệu 'wall' dùng chung")
	_check(load("res://scripts/materials.gd").make("wall").albedo_color == wall_col, "vật liệu 'wall' gốc giữ nguyên màu (các map khác không bị ảnh hưởng)")

	print("[lớp trang trí]")
	var md: Dictionary = Maps.endless(2)
	var buildings: int = 0
	var pillars: int = 0
	var tall: float = 0.0
	for b in md["boxes"]:
		if b["role"] == "wall":
			buildings += 1
			tall = maxf(tall, (b["size"] as Vector3).y)
		elif b["role"] == "pillar":
			pillars += 1
	var deco: Array = Look.dress(md)
	var insts: int = 0
	var bad_node: int = 0
	for d in deco:
		if not (d is MultiMeshInstance3D) or d.get_child_count() > 0 or d.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			bad_node += 1
		insts += int(d.multimesh.instance_count)
	_check(deco.size() >= 5 and deco.size() <= 7, "%d lớp MultiMesh (<= 7 draw call cho toàn bộ trang trí)" % deco.size())
	_check(bad_node == 0, "mọi lớp: MultiMeshInstance3D, không va chạm (không node con), không đổ bóng")
	# mái 4 vạch/toà + vòng cột 4 vạch/cột + 3 ăng-ten + khung xuất phát/cổng 8 + vạch phố
	var min_expected: int = buildings * 4 + pillars * 4 + 3 + 8
	_check(insts >= min_expected and insts < 3000, "%d thể hiện (>= %d tối thiểu, < 3000): %d toà, %d cột" % [insts, min_expected, buildings, pillars])
	var masts: MultiMeshInstance3D
	for d in deco:
		if d.multimesh.instance_count == mini(3, buildings):
			masts = d
	_check(masts != null, "ăng-ten mốc: đúng %d cái (trên các toà cao nhất)" % mini(3, buildings))
	for d in deco:
		d.free()

	print("[Arena: chỉ Vô Tận được trang trí]")
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.map_id = "endless"
	arena.bake_nav = false
	root.add_child(arena)
	await _frames(2)
	var ends: int = _count(arena, "MultiMeshInstance3D")
	_check(ends >= 5, "Vô Tận: %d lớp MultiMesh được thêm" % ends)
	var tinted: int = 0
	var gridded: int = 0
	for ch in arena.get_children():
		if ch is StaticBody3D and ch.get_child_count() > 1:
			var mi: Node = ch.get_child(1)
			if mi is MeshInstance3D and (mi.mesh as BoxMesh).material != null:
				var mat: Material = (mi.mesh as BoxMesh).material
				for v in 5:
					if mat == Look.facade(v):
						tinted += 1
				gridded += 1
	_check(tinted >= 10, "%d toà nhà đã đổi tông mặt tiền" % tinted)
	arena.queue_free()
	await _frames(2)
	for id in ["yard"]:   # sân phẳng của test: không có lớp trang trí Vô Tận
		var a2: Node3D = load("res://tools/tests/fixtures/flat_arena.gd").new()
		a2.bake_nav = false
		root.add_child(a2)
		await _frames(1)
		_check(_count(a2, "MultiMeshInstance3D") == 0, "map %s: không có lớp trang trí Vô Tận (giữ nguyên)" % id)
		a2.queue_free()
		await _frames(1)

	print("[navmesh: không trả đường tầng cũ]")
	var an: Node3D = load("res://scripts/arena.gd").new()
	an.map_id = "endless"
	root.add_child(an)
	var first_ready: int = -1
	for i in 20:
		if an.nav_ready():
			first_ready = i
			break
		_check(an.nav_path(an.spawn_point, an.exit_point).is_empty(), "tầng 1, khung %d: chưa đồng bộ thì nav_path rỗng" % i) if i < 2 else null
		await physics_frame
	_check(first_ready >= 0 and first_ready <= 12, "tầng 1: navmesh sẵn sàng sau %d khung" % first_ready)
	var path1: PackedVector3Array = an.nav_path(an.spawn_point, an.exit_point)
	_check(path1.size() >= 2, "tầng 1: có đường tới cổng khi đã sẵn sàng")
	for fl in [2, 3]:
		var old_region: NavigationRegion3D = an.nav_region
		an.load_floor(fl)
		_check(not old_region.enabled, "tầng %d: vùng điều hướng cũ bị tắt ngay khi dựng lại" % fl)
		# Chưa sẵn sàng thì phải rỗng; nếu máy chủ đã gộp ngay thì đường phải đúng cổng mới (không bao giờ là đường cũ).
		var p0: PackedVector3Array = an.nav_path(an.spawn_point, an.exit_point)
		_check(p0.is_empty() or p0[p0.size() - 1].distance_to(an.exit_point) < 3.0, "tầng %d: khung đầu không trả đường cũ / sai" % fl)
		var rd: int = -1
		for i in 40:
			await physics_frame
			if an.nav_ready():
				rd = i + 1
				break
		_check(rd >= 1 and rd <= 30, "tầng %d: sẵn sàng sau %d khung" % [fl, rd])
		var p2: PackedVector3Array = an.nav_path(an.spawn_point, an.exit_point)
		_check(p2.size() >= 2 and p2[p2.size() - 1].distance_to(an.exit_point) < 3.0, "tầng %d: đường mới tới đúng cổng mới (rd=%d, %d điểm, cách %.1f m)" % [fl, rd, p2.size(), p2[p2.size() - 1].distance_to(an.exit_point) if p2.size() > 0 else -1.0])
	an.queue_free()
	await _frames(2)

	print("[cổng]")
	var portal: Area3D = load("res://scripts/portal.gd").new()
	root.add_child(portal)
	await _frames(2)
	_check(not portal.is_open and portal._beam.visible and not portal._light.visible, "khoá: cột đỏ mờ vẫn thấy, không đèn")
	var ph_locked: float = portal._beam_mesh.height
	portal.set_open(true)
	_check(portal.is_open and portal._beam.visible and portal._light.visible, "mở: cột sáng + đèn")
	_check(portal._beam_mesh.height > ph_locked and portal._beam_mesh.top_radius > 1.2, "mở: cột cao và rộng hơn lúc khoá")
	var got: Array = []
	portal.entered.connect(func(): got.append(1))
	var pl := CharacterBody3D.new()
	pl.add_to_group("player")
	portal._on_body_entered(pl)
	_check(got.size() == 1, "mở + người chơi vào: phát entered")
	portal.set_open(false)
	portal._on_body_entered(pl)
	_check(got.size() == 1 and not portal.is_open, "khoá: vào cổng không phát entered")
	pl.free()
	G.reduced_fx = true
	portal.set_open(true)
	portal._process(0.5)
	var a_lo: float = portal._beam_mat.albedo_color.a
	portal._process(0.5)
	_check(is_equal_approx(a_lo, portal._beam_mat.albedo_color.a), "giảm hiệu ứng: cột không nhấp nháy")
	G.reduced_fx = false
	portal.queue_free()
	await _frames(2)

	print("")
	if failures == 0:
		print("TẤT CẢ ĐẠT")
	else:
		printerr("CÓ %d LỖI" % failures)
	quit(1 if failures > 0 else 0)
