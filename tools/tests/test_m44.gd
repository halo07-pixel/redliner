extends SceneTree
## M44 "Bot + Titan low poly": thân 5 loại bot + Titan dựng trong Blender (khối rời gắn vào 15 khớp proxy, tools/blender/make_bots.py)
## nạp được, trong ngân sách tam giác, vị trí khớp khớp hình nhân khối (nên RigAnimator/IK/hitbox không đổi), tô màu theo loại bot;
## rìu + dao low poly; bot/Titan thật trong trận dùng chúng. Bộ test cũ giữ xanh.
##   timeout 150 godot --headless --path . -s tools/tests/test_m44.gd

const KINDS: Array = ["swordsman", "gunner", "elite", "rusher", "bomber", "titan"]
const WEAPON_KIND: Dictionary = {"swordsman": "sword", "gunner": "gun", "elite": "sword", "rusher": "sword", "bomber": "gun"}

var failures: int = 0
var G
var arena: Node


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


func _tris(n: Node) -> int:
	var t: int = 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx != null and idx.size() > 0 else arr[Mesh.ARRAY_VERTEX].size()) / 3
	return t


## AABB của các mesh; `frame` (nếu có) = nút làm hệ quy chiếu (đo trong khung vũ khí, không phụ thuộc tư thế tay).
func _aabb_of(meshes: Array, frame: Node3D = null) -> AABB:
	var r := AABB()
	var first := true
	for mi in meshes:
		var xf: Transform3D = (mi as MeshInstance3D).global_transform
		if frame != null:
			xf = frame.global_transform.affine_inverse() * xf
		var a: AABB = xf * (mi as MeshInstance3D).get_aabb()
		r = a if first else r.merge(a)
		first = false
	return r


## Vị trí cục bộ mong đợi của từng khớp theo `mannequin.gd` + Global.RIG.
func _expected(kind: String) -> Dictionary:
	var sw: float = float(G.RIG[kind]["shoulder"])
	var e: Dictionary = {"hips": Vector3(0.0, 0.92, 0.0), "spine": Vector3.ZERO, "head": Vector3(0.0, 0.62, 0.0)}
	for tag in ["l", "r"]:
		var side: float = -1.0 if tag == "l" else 1.0
		e["shoulder_" + tag] = Vector3(0.3 * sw * side, 0.52, 0.0)
		e["elbow_" + tag] = Vector3(0.0, -0.45, 0.0)
		e["hand_" + tag] = Vector3(0.0, -0.42, 0.0)
		e["hip_" + tag] = Vector3(0.13 * side, -0.05, 0.0)
		e["knee_" + tag] = Vector3(0.0, -0.45, 0.0)
		e["ankle_" + tag] = Vector3(0.0, -0.38, 0.0)
	return e


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	var L: Dictionary = G.LOWPOLY
	var LP = load("res://scripts/mannequin_lowpoly.gd")
	var MG = load("res://scripts/mannequin_gltf.gd")
	var bot_budget: int = int(L["budget"]["bot"])

	print("[dữ liệu]")
	_check(L["bots"].keys().size() == 6 and L.has("axe") and L.has("dagger"), "LOWPOLY: 6 thân + rìu + dao")
	for k in ["bd_cloth", "bd_pants"]:
		pass
	var weapon_tris: Dictionary = {}
	for w in ["axe", "dagger"]:
		var wm: Node3D = (load(String(L[w])) as PackedScene).instantiate()
		root.add_child(wm)
		weapon_tris[w] = _tris(wm)
		_check(weapon_tris[w] >= 40 and weapon_tris[w] <= int(L["budget"]["weapon"]), "%s: %d tam giác trong ngân sách %d" % [w, weapon_tris[w], L["budget"]["weapon"]])
		var box: AABB = _aabb_of(wm.find_children("*", "MeshInstance3D", true, false))
		_check(box.position.z < -0.3 and box.end.z > 0.0 and box.position.x < 0.0 and box.end.x > 0.0, "%s: đầu về -Z, gốc nằm trong thân" % w)
		wm.queue_free()

	var tris: Dictionary = {}
	for kind in KINDS:
		print("[%s]" % kind)
		_check(LP.has_asset(kind), "có asset thân")
		var path: String = String(L["bots"][kind])
		var raw: Node3D = (load(path) as PackedScene).instantiate()
		root.add_child(raw)
		tris[kind] = _tris(raw)
		_check(tris[kind] >= 400 and tris[kind] <= bot_budget, "%d tam giác trong ngân sách %d" % [tris[kind], bot_budget])
		raw.queue_free()

		var m: Node3D = LP.new()
		m.kind = kind
		m.color = Color(0.8, 0.3, 0.2)
		root.add_child(m)
		await process_frame
		var exp: Dictionary = _expected(kind)
		var joints_ok: bool = true
		var pos_ok: bool = true
		for jn in m.JOINT_NAMES:
			var j: Node3D = m.get_joint(jn)
			joints_ok = joints_ok and j != null
			if j != null:
				pos_ok = pos_ok and j.position.distance_to(exp[jn]) < 0.003
		_check(joints_ok, "đủ 15 khớp proxy")
		_check(pos_ok, "vị trí khớp khớp mannequin.gd (RIG vai %.2f)" % float(G.RIG[kind]["shoulder"]))
		var body: Array = m.find_children("*", "MeshInstance3D", true, false).filter(func(mi): return m.weapon == null or not m.weapon.is_ancestor_of(mi))
		var bb: AABB = _aabb_of(body)
		_check(bb.size.y > 1.7 and bb.size.y < 2.15 and absf(bb.position.y) < 0.03, "cao %.2f m, chân chạm đất (%.2f)" % [bb.size.y, bb.position.y])
		var tinted: bool = false
		var all_set: bool = true
		for mi in body:
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				var ov: Material = (mi as MeshInstance3D).get_surface_override_material(s)
				all_set = all_set and ov != null
				tinted = tinted or (ov is StandardMaterial3D and (ov as StandardMaterial3D).albedo_color.is_equal_approx(m.color))
		_check(all_set and tinted, "mọi bề mặt có vật liệu tô theo màu loại bot")
		if kind == "titan":
			_check(m.weapon == null, "Titan không cầm vũ khí")
		else:
			var wb: AABB = _aabb_of(m.weapon.find_children("*", "MeshInstance3D", true, false), m.weapon)
			var cfg: Dictionary = MG.weapon_config(kind)
			var along: float = wb.size.y if WEAPON_KIND[kind] == "sword" else wb.size.z
			_check(String(cfg["file"]).ends_with(".glb") and absf(along - float(cfg["length"])) < 0.06, "vũ khí low poly dài %.2f m (cần %.2f) theo %s" % [along, float(cfg["length"]), "+Y" if WEAPON_KIND[kind] == "sword" else "-Z"])
			if WEAPON_KIND[kind] == "gun":
				_check(wb.position.z < -0.4 * float(cfg["length"]) and wb.end.z < 0.25, "nòng về -Z")
			else:
				_check(wb.end.y > 0.6 * float(cfg["length"]) and wb.position.y > -0.25, "mũi/đầu rìu hướng +Y")
		# hoạt ảnh + IK vẫn chạy
		var finite: bool = true
		for i in 40:
			m.animate(1.0 / 60.0, 4.0, true, 0.0)
		for jn in m.JOINT_NAMES:
			var p: Vector3 = (m.get_joint(jn) as Node3D).global_position
			finite = finite and is_finite(p.x) and is_finite(p.y) and is_finite(p.z)
		_check(finite, "chạy hoạt ảnh 40 khung, mọi khớp hữu hạn")
		m.play("swing", 0.5, {"windup": 0.2, "active": 0.1, "recovery": 0.2})
		m.flash()
		m.flash_weapon(0.2)
		m.animate(1.0 / 60.0, 0.0, true, 0.0)
		_check(true, "swing/flash/flash_weapon không lỗi")
		m.queue_free()

	print("[bot + Titan trong trận]")
	arena = load("res://tools/tests/fixtures/flat_arena.gd").new()
	arena.bake_nav = false
	root.add_child(arena)
	await _frames(3)
	for t in ["swordsman", "gunner", "elite", "rusher", "bomber"]:
		var b = load("res://scripts/bot.gd").new()
		b.setup(t, 1)
		b.position = Vector3(0.0, 0.2, 0.0)
		arena.add_child(b)
		await _frames(3)
		_check(b.mannequin.get_script().resource_path.ends_with("mannequin_lowpoly.gd") and String(b.mannequin.kind) == t, "bot %s dùng thân low poly" % t)
		b.queue_free()
	var ti = load("res://scripts/titan.gd").new()
	ti.setup("titan", 1)
	ti.position = Vector3(0.0, 0.2, 0.0)
	arena.add_child(ti)
	await _frames(3)
	_check(ti.mannequin.get_script().resource_path.ends_with("mannequin_lowpoly.gd") and absf(ti.mannequin.scale.y - float(G.TITAN["scale"])) < 0.5, "Titan dùng thân low poly (scale %.2f)" % ti.mannequin.scale.y)
	ti.queue_free()
	arena.queue_free()

	print("")
	if failures == 0:
		print("TẤT CẢ ĐẠT")
	else:
		printerr("CÓ %d LỖI" % failures)
	quit(1 if failures > 0 else 0)
