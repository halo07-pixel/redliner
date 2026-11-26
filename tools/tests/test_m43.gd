extends SceneTree
## M43 "4 súng low poly": pistol/shotgun/launcher/sniper dựng trong Blender (.glb) nạp được, trong ngân sách tam giác, nòng về -Z,
## có Empty `muzzle` + phần cử động (Mag/Pump/Cap/Bolt) đúng trục xoay; viewmodel dùng chúng (chớp lửa theo `muzzle`, nạp đạn vẫn
## chạy bộ phận); bot xạ thủ/pháo thủ cầm súng low poly. Bộ test cũ giữ xanh.
##   timeout 120 godot --headless --path . -s tools/tests/test_m43.gd

const GUNS: Array = ["pistol", "shotgun", "launcher", "sniper"]
## Theo viewmodel cũ: z chớp lửa và trục xoay của phần cử động.
const MUZZLE_Z: Dictionary = {"pistol": -0.36, "shotgun": -0.6, "launcher": -0.58, "sniper": -0.82}
const ANIM: Dictionary = {"pistol": ["Mag", Vector3(0.0, 0.0, 0.0)], "shotgun": ["Pump", Vector3(0.0, 0.0, 0.0)],
	"launcher": ["Cap", Vector3(0.0, 0.07, -0.5)], "sniper": ["Bolt", Vector3(0.04, 0.035, 0.0)]}

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
	var budget: int = int(L["budget"]["weapon"])
	var tris: Dictionary = {}

	print("[dữ liệu]")
	_check(L["guns"].keys().size() == 4, "LOWPOLY.guns có 4 súng")
	for k in ["gun_metal", "gun_metal_light", "wood", "red", "scope_dark"]:
		_check(G.PALETTE.has(k) and G.MATERIAL_PARAMS.has(k), "PALETTE + MATERIAL_PARAMS có " + k)

	for id in GUNS:
		print("[%s.glb]" % id)
		var path: String = String(L["guns"][id])
		_check(ResourceLoader.exists(path), "có file " + path)
		var model: Node3D = (load(path) as PackedScene).instantiate()
		root.add_child(model)
		await process_frame
		tris[id] = _tris(model)
		_check(tris[id] >= 100 and tris[id] <= budget, "tam giác %d trong ngân sách %d" % [tris[id], budget])
		var mz: Node3D = model.get_node_or_null("muzzle")
		_check(mz != null and absf(mz.position.z - float(MUZZLE_Z[id])) < 0.005, "có Empty muzzle ở z=%.2f" % (mz.position.z if mz != null else 0.0))
		var box: AABB = _aabb(model)
		_check(mz != null and absf(box.position.z - mz.position.z) < 0.06, "nòng ở -Z: đầu nòng %.2f, muzzle %.2f" % [box.position.z, mz.position.z if mz != null else 0.0])
		_check(box.position.x < 0.0 and box.end.x > 0.0 and box.end.z > 0.0 and box.position.z < -0.3, "gốc (bàn tay cầm) nằm trong thân súng")
		var an: Node3D = model.get_node_or_null(String(ANIM[id][0]))
		_check(an != null and an.position.is_equal_approx(ANIM[id][1]) and an.find_children("*", "MeshInstance3D", true, false).size() + (1 if an is MeshInstance3D else 0) >= 1, "phần cử động %s có trục xoay đúng %s" % [ANIM[id][0], str(ANIM[id][1])])
		var names: Dictionary = {}
		var flat: bool = true
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var m := mesh.surface_get_material(s) as BaseMaterial3D
				if m != null:
					names[m.resource_name] = true
					flat = flat and m.albedo_texture == null
		var pal_ok: bool = true
		for nm in names:
			pal_ok = pal_ok and G.PALETTE.has(String(nm).trim_prefix("gn_"))
		_check(flat and pal_ok, "màu phẳng, đều có trong PALETTE (%s)" % str(names.keys()))
		model.queue_free()

	print("[viewmodel]")
	var v: Node3D = load("res://scripts/viewmodel.gd").new()
	root.add_child(v)
	await process_frame
	for id in GUNS:
		var gm: Node3D = v._gun_models[id]
		var lp: Node = gm.get_node_or_null("LowPoly")
		_check(lp != null and _tris(lp) == tris[id], "%s: viewmodel nạp glb" % id)
		var d: Dictionary = v._anim_parts[id]
		_check(lp != null and lp.is_ancestor_of(d["node"]) and String(d["node"].name) == String(ANIM[id][0]), "%s: bộ phận cử động = node %s trong glb" % [id, ANIM[id][0]])
		_check(absf(float(v._flash_z[id]) - float(MUZZLE_Z[id])) < 0.005, "%s: chớp lửa theo muzzle (z=%.2f)" % [id, v._flash_z[id]])
		v.set_weapon(id, false)
		_check(gm.visible and v.muzzle_flash.position.z == v._flash_z[id], "%s: chọn súng -> chớp lửa đúng chỗ" % id)
		var other_hidden: bool = true
		for k in GUNS:
			other_hidden = other_hidden and (v._gun_models[k] as Node3D).visible == (k == id)
		_check(other_hidden, "%s: chỉ hiện đúng một súng" % id)
	# nạp đạn: bộ phận trong glb thật sự chuyển động
	for id in GUNS:
		v.set_weapon(id, false)
		for i in 5:
			v.update(1.0 / 60.0, 0.0, true, "")
		var n: Node3D = v._anim_parts[id]["node"]
		var p0: Vector3 = n.position
		var r0: Vector3 = n.rotation_degrees
		v.set_reloading(true)
		var moved: bool = false
		for i in 120:
			v.update(1.0 / 60.0, 0.0, true, "")
			moved = moved or n.position.distance_to(p0) > 0.01 or n.rotation_degrees.distance_to(r0) > 5.0
		_check(moved, "%s: nạp đạn làm bộ phận %s chuyển động" % [id, n.name])
		v.set_reloading(false)
	v.queue_free()

	print("[bot xạ thủ / pháo thủ]")
	var MG = load("res://scripts/mannequin_gltf.gd")
	for pair in [["gunner", "sniper"], ["bomber", "launcher"]]:
		var cfg: Dictionary = MG.weapon_config(pair[0])
		_check(String(cfg["file"]) == String(L["guns"][pair[1]]) and bool(cfg["flip"]), "%s trỏ tới %s.glb (flip)" % [pair[0], pair[1]])
		var m: Node3D = MG.new()
		m.kind = pair[0]
		root.add_child(m)
		await process_frame
		var wb: AABB = _aabb(m.weapon)
		_check(m.weapon != null and absf(wb.size.z - float(cfg["length"])) < 0.05, "%s: súng dài %.2f m theo trục -Z của khung cầm" % [pair[0], wb.size.z])
		_check(wb.position.z < -0.4 * float(cfg["length"]) and wb.end.z > 0.0 and wb.end.z < 0.2, "%s: nòng về -Z, báng sau điểm cầm (%.2f .. %.2f)" % [pair[0], wb.position.z, wb.end.z])
		_check(_tris(m.weapon) == tris[pair[1]], "%s: bot dùng đúng mesh glb" % pair[0])
		m.queue_free()
	_check(String(MG.weapon_config("elite")["file"]).ends_with("Axe_Double.fbx") and String(MG.weapon_config("rusher")["file"]).ends_with("Dagger.fbx"), "tinh anh / kẻ lao tới giữ model cũ (làm ở M44)")

	print("")
	if failures == 0:
		print("TẤT CẢ ĐẠT")
	else:
		printerr("CÓ %d LỖI" % failures)
	quit(1 if failures > 0 else 0)
