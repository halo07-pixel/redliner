extends SceneTree
## M45 "Module bản đồ Vô Tận low poly": 6 module dựng trong Blender (tools/blender/make_map.py) nạp được, mỗi module trong ngân sách
## tam giác (<= 3000), mesh nằm gọn trong khối đơn vị (co giãn khít hộp va chạm), Arena phủ module lên đúng hộp (hộp gốc ẩn, va chạm
## và bố cục Maps.endless KHÔNG đổi), mỗi ô 50 m không vượt trần tam giác. Bộ test cũ giữ xanh.
##   timeout 200 godot --headless --path . -s tools/tests/test_m45.gd

const Mods = preload("res://scripts/endless_modules.gd")
const Maps = preload("res://scripts/maps.gd")
const KINDS: Array = ["building_block", "building_fins", "building_slab", "pillar", "stage", "cover"]

var failures: int = 0


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


func _aabb(n: Node3D) -> AABB:
	var r := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (mi as MeshInstance3D).get_aabb()
		r = a if first else r.merge(a)
		first = false
	return r


func _run() -> void:
	print("[Dữ liệu / ngân sách]")
	var L: Dictionary = Global.LOWPOLY
	_check(int(L["budget"]["prop"]) == 3000, "ngân sách module = 3000 tam giác")
	_check(int(L["budget"]["cell"]) == 40000, "trần mỗi ô 50 m = 40000")
	for k in KINDS:
		_check(Mods.has_asset(k), "có file module %s" % k)
		var node: Node3D = load(Mods.path_of(k)).instantiate()
		var t: int = Mods.tri_count(node)
		_check(t > 0 and t <= int(L["budget"]["prop"]), "%s: %d tam giác <= 3000" % [k, t])
		var a: AABB = _aabb(node)
		_check(a.position.x >= -0.501 and a.end.x <= 0.501 and a.position.z >= -0.501 and a.end.z <= 0.501 and a.position.y >= -0.501, "%s: nằm trong khối đơn vị (không lấn ra ngoài hộp)" % k)
		_check(a.end.y <= 0.5 + 0.14, "%s: không vượt nóc hộp quá phụ kiện nhỏ" % k)
		var mats: Array = []
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				mats.append(String((mi as MeshInstance3D).mesh.surface_get_material(s).resource_name))
		_check(mats.all(func(n): return n in ["mod_wall", "mod_trim", "mod_glow"]), "%s: vật liệu đặt theo vai trò %s" % [k, str(mats)])
		node.free()

	print("[Chọn loại module]")
	_check(Mods.kind_for({"role": "pillar", "size": Vector3(2.5, 15, 2.5), "pos": Vector3.ZERO}) == "pillar", "cột -> pillar")
	_check(Mods.kind_for({"role": "platform", "size": Vector3(16, 2, 16), "pos": Vector3.ZERO}) == "stage", "bệ 16x2x16 -> stage")
	_check(Mods.kind_for({"role": "platform", "size": Vector3(8, 1.4, 0.8), "pos": Vector3.ZERO}) == "cover", "bức che -> cover")
	_check(Mods.kind_for({"role": "ramp", "size": Vector3(8, 0.4, 7), "pos": Vector3.ZERO}) == "", "dốc giữ hộp")
	_check(Mods.kind_for({"role": "grapple", "size": Vector3(4, 0.5, 4), "pos": Vector3.ZERO}) == "", "bệ móc giữ hộp")
	var seen: Dictionary = {}
	for b in Maps.endless(1)["boxes"] + Maps.endless(2)["boxes"] + Maps.endless(3)["boxes"]:
		if b["role"] == "wall":
			seen[Mods.kind_for(b)] = true
	_check(seen.size() >= 2, "toà nhà dùng nhiều kiểu (%d kiểu)" % seen.size())

	print("[Arena: module phủ đúng hộp, va chạm không đổi]")
	var before: Array = [Maps.endless(1)["boxes"].duplicate(true), Maps.endless(5)["boxes"].duplicate(true)]
	for fl in [1, 3]:
		var arena: Node3D = load("res://scripts/arena.gd").new()
		arena.map_id = "endless"
		arena.floor_n = fl
		arena.bake_nav = false
		root.add_child(arena)
		await _frames(2)
		var m: Dictionary = Maps.endless(fl)
		var bodies: Array = arena.find_children("*", "StaticBody3D", true, false)
		var mods: int = 0
		var bad: int = 0
		var cell_tris: Dictionary = {}
		var cell: float = float(Global.ENDLESS["cell"])
		var worst_prop: int = 0
		for b in bodies:
			var mod: Node = (b as Node).get_node_or_null("Module")
			if mod == null:
				continue
			mods += 1
			var t: int = Mods.tri_count(mod)
			worst_prop = maxi(worst_prop, t)
			var cs: CollisionShape3D = (b as Node).get_child(0)
			var sz: Vector3 = (cs.shape as BoxShape3D).size
			if not (mod as Node3D).scale.is_equal_approx(sz):
				bad += 1
			var key := Vector2i(floori(((b as Node3D).position.x + 150.0) / cell), floori(((b as Node3D).position.z + 150.0) / cell))
			cell_tris[key] = int(cell_tris.get(key, 0)) + t
		_check(mods > 0, "tầng %d: %d khối có module" % [fl, mods])
		_check(bad == 0, "tầng %d: scale module = kích thước hộp va chạm" % fl)
		_check(worst_prop <= 3000, "tầng %d: module nặng nhất %d <= 3000" % [fl, worst_prop])
		var worst_cell: int = 0
		for k in cell_tris:
			worst_cell = maxi(worst_cell, int(cell_tris[k]))
		_check(worst_cell <= int(L["budget"]["cell"]), "tầng %d: ô nặng nhất %d <= %d tam giác" % [fl, worst_cell, int(L["budget"]["cell"])])
		var hidden: int = 0
		for b in bodies:
			if (b as Node).get_node_or_null("Module") != null:
				for ch in (b as Node).get_children():
					if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is BoxMesh and not (ch as MeshInstance3D).visible:
						hidden += 1
		_check(hidden == mods, "tầng %d: hộp gốc bị ẩn ở mọi khối có module" % fl)
		_check(bodies.size() >= m["boxes"].size(), "tầng %d: số thân va chạm không giảm" % fl)
		arena.queue_free()
		await _frames(1)
	_check(Maps.endless(1)["boxes"] == before[0] and Maps.endless(5)["boxes"] == before[1], "bố cục Maps.endless không đổi")

	print("[Tắt LOWPOLY -> hộp cũ]")
	_check(Mods.has_asset("pillar") and not Mods.has_asset(""), "has_asset: rỗng -> false")

	print("")
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
