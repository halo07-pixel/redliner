extends SceneTree
## M42 "Chuẩn low poly": thanh kiếm dựng trong Blender (.glb) nạp được, trong ngân sách tam giác, đúng quy ước trục/điểm cầm,
## màu khớp PALETTE; viewmodel + bot kiếm sĩ dùng nó mà không đổi gì ở hitbox/chiến đấu (bộ test cũ giữ xanh).
##   timeout 120 godot --headless --path . -s tools/tests/test_m42.gd

var failures: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _tris(n: Node) -> int:
	var t: int = 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx != null and idx.size() > 0 else arr[Mesh.ARRAY_VERTEX].size()) / 3
	return t


func _aabb(n: Node3D) -> AABB:
	var r := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var a: AABB = m.transform * m.get_aabb()
		var p: Node = m.get_parent()
		while p != n and p is Node3D:
			a = (p as Node3D).transform * a
			p = p.get_parent()
		r = a if first else r.merge(a)
		first = false
	return r


func _run() -> void:
	await process_frame
	var G = root.get_node("Global")
	var L: Dictionary = G.LOWPOLY
	var path: String = String(L["sword"])

	print("[dữ liệu + chuẩn]")
	_check(bool(L["enabled"]) and ResourceLoader.exists(path), "bật low poly, có file " + path)
	var b: Dictionary = L["budget"]
	_check(int(b["bot"]) >= 800 and int(b["weapon"]) >= 200 and int(b["prop"]) >= 300, "ngân sách: bot %d / súng-kiếm %d / vật cảnh %d" % [b["bot"], b["weapon"], b["prop"]])
	for k in ["steel", "steel_dark", "gold", "leather"]:
		_check(G.PALETTE.has(k), "PALETTE có màu " + k)
	_check(FileAccess.file_exists("res://docs/ASSETS.md") and FileAccess.get_file_as_string("res://docs/ASSETS.md").contains("Chuẩn low poly"), "docs/ASSETS.md có mục Chuẩn low poly")

	print("[sword.glb]")
	var sword: Node3D = (load(path) as PackedScene).instantiate()
	root.add_child(sword)
	var tris: int = _tris(sword)
	_check(tris >= 20 and tris <= int(b["weapon"]), "tam giác %d trong ngân sách %d" % [tris, b["weapon"]])
	var box: AABB = _aabb(sword)
	_check(absf(box.size.z - 1.19) < 0.03 and box.size.x < 0.2 and box.size.y < 0.1, "kích thước mét: dài %.2f, rộng %.2f, dày %.2f" % [box.size.z, box.size.x, box.size.y])
	_check(absf(box.position.z + 1.06) < 0.02 and absf(box.end.z - 0.13) < 0.02, "mũi ở -Z (%.2f), đầu chuôi ở +Z (%.2f)" % [box.position.z, box.end.z])
	_check(box.has_point(Vector3.ZERO), "gốc (điểm cầm) nằm trong thân kiếm")
	var mats: Dictionary = {}
	for mi in sword.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s) as BaseMaterial3D
			if m != null:
				mats[m.resource_name] = m
	_check(mats.size() == 4, "4 vật liệu phẳng: %s" % str(mats.keys()))
	var colors_ok: bool = true
	for k in ["steel", "steel_dark", "gold", "leather"]:
		var m = mats.get("sw_" + k)
		colors_ok = colors_ok and m != null and (m.albedo_color.srgb_to_linear().is_equal_approx(Color(G.PALETTE[k]).srgb_to_linear()) or m.albedo_color.is_equal_approx(Color(G.PALETTE[k]))) and m.albedo_texture == null
	_check(colors_ok, "màu vật liệu khớp PALETTE, không texture")
	sword.queue_free()

	print("[viewmodel]")
	var v: Node3D = load("res://scripts/viewmodel.gd").new()
	root.add_child(v)
	await process_frame
	var ls: Node = v.sword_pivot.get_node_or_null("LowPolySword")
	_check(ls != null, "viewmodel nạp kiếm low poly")
	var old_blade: int = v.sword_pivot.get_children().filter(func(c): return c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh and ((c as MeshInstance3D).mesh as BoxMesh).size.z > 0.5).size()
	_check(old_blade == 0, "không còn khối lưỡi kiếm cũ")
	_check(_tris(v.sword_pivot.get_node("LowPolySword")) == tris, "viewmodel dùng đúng mesh glb")
	v.queue_free()

	print("[bot kiếm sĩ]")
	var MG = load("res://scripts/mannequin_gltf.gd")
	_check(String(MG.weapon_config("swordsman")["file"]) == path and bool(MG.weapon_config("swordsman")["flip"]), "kiếm sĩ trỏ tới glb (flip)")
	_check(String(MG.weapon_config("elite")["file"]).ends_with("Axe_Double.fbx") and String(MG.weapon_config("rusher")["file"]).ends_with("Dagger.fbx"), "tinh anh / kẻ lao tới giữ model cũ (xạ thủ, pháo thủ đã đổi ở M43)")
	var m: Node3D = MG.new()
	m.kind = "swordsman"
	root.add_child(m)
	await process_frame
	_check(m.weapon != null and m.weapon.find_children("*", "MeshInstance3D", true, false).size() >= 1, "bot cầm kiếm")
	var wb: AABB = _aabb(m.weapon)
	_check(absf(wb.size.y - 1.0) < 0.03, "kiếm bot dài %.2f m theo trục +Y của khung cầm" % wb.size.y)
	_check(wb.position.y < -0.08 and wb.position.y > -0.16 and wb.end.y > 0.8, "điểm cầm gần đầu chuôi, mũi hướng +Y (%.2f .. %.2f)" % [wb.position.y, wb.end.y])
	_check(_tris(m.weapon) == tris, "bot dùng đúng mesh glb")
	m.queue_free()

	print("")
	if failures == 0:
		print("TẤT CẢ ĐẠT")
	else:
		printerr("CÓ %d LỖI" % failures)
	quit(1 if failures > 0 else 0)
