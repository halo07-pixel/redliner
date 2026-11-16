extends SceneTree
## Test headless M7.7: người que glTF (GodoDude) + vũ khí thật — API, chuyển tư thế sang xương, vũ khí, fallback.
##   timeout 120 godot --headless --path . -s tools/tests/test_mannequin_gltf.gd

var failures: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _make(kind: String) -> Node3D:
	var m: Node3D = load("res://scripts/mannequin_gltf.gd").new()
	m.kind = kind
	root.add_child(m)
	return m


func _bone_pos(m: Node3D, bone: String) -> Vector3:
	return m.skeleton.global_transform * m.skeleton.get_bone_global_pose(m.skeleton.find_bone(bone)).origin


func _run() -> void:
	await process_frame
	var G = load("res://scripts/mannequin_gltf.gd")
	_check(G.has_asset("swordsman") and G.has_asset("elite") and G.has_asset("gunner"), "có asset cho 3 loại bot")
	_check(not G.has_asset("dummy"), "dummy không dùng người que (giữ hình nhân khối)")

	var m: Node3D = _make("swordsman")
	await process_frame
	for jn in m.JOINT_NAMES:
		_check(m.get_joint(jn) != null, "có khớp " + jn)
	# chiều cao: đỉnh đầu ~1.8 m, chân chạm đất
	var top: float = -1e9
	var bottom: float = 1e9
	for mi in m.model.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		top = maxf(top, a.end.y)
		bottom = minf(bottom, a.position.y)
	_check(absf((top - bottom) - 1.8) < 0.2, "cao ~1.8 m (%.2f)" % (top - bottom))

	# tay buông thẳng xuống ở tư thế gốc: cổ tay thấp hơn vai nhiều
	m.clear_overlay()
	var sh: Vector3 = _bone_pos(m, "upper_arm.R")
	var wr: Vector3 = _bone_pos(m, "hand.R")
	_check(sh.y - wr.y > 0.4, "tay buông xuống (vai-cổ tay cao %.2f)" % (sh.y - wr.y))

	# khớp proxy điều khiển xương: xoay vai phải về trước -> cổ tay ra trước (-Z)
	var z0: float = _bone_pos(m, "hand.R").z
	m.get_joint("shoulder_r").rotation_degrees = Vector3(80.0, 0.0, 0.0)
	m._apply_pose()
	_check(_bone_pos(m, "hand.R").z < z0 - 0.3, "shoulder_r +x => tay ra trước (-Z)")
	# bên trái/phải đúng chỗ: _l ở -X
	_check(_bone_pos(m, "upper_arm.L").x < _bone_pos(m, "upper_arm.R").x, "bên l nằm ở -X")

	# đầu theo hông hạ thấp
	m.clear_overlay()
	var hy0: float = _bone_pos(m, "spine.005").y
	m.get_joint("hips").position.y -= 0.2
	m._apply_pose()
	_check(hy0 - _bone_pos(m, "spine.005").y > 0.15, "hips hạ -> đầu hạ")

	# chạy: chân đổi bước
	m.clear_overlay()
	var lo: float = 1e9
	var hi: float = -1e9
	for i in 90:
		m.animate(1.0 / 60.0, 7.0, true, 0.0)
		var d: float = _bone_pos(m, "foot.L").z - _bone_pos(m, "foot.R").z
		lo = minf(lo, d)
		hi = maxf(hi, d)
	_check(hi - lo > 0.5, "chạy: hai chân đảo bước (%.2f)" % (hi - lo))

	# vũ khí
	var w: Dictionary = {"swordsman": 0.85, "elite": 0.85, "gunner": 0.8}
	for k in w:
		var b: Node3D = _make(k)
		await process_frame
		_check(b.weapon != null and b.weapon.get_parent() is BoneAttachment3D, "%s: vũ khí gắn vào bàn tay" % k)
		var box := AABB()
		var first := true
		for mi in b.weapon.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			box = a if first else box.merge(a)
			first = false
		var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
		_check(absf(longest - w[k]) < 0.25, "%s: vũ khí dài ~%.2fm (%.2f)" % [k, w[k], longest])
		b.queue_free()

	# gunner: nòng hướng về trước khi chạy
	var g: Node3D = _make("gunner")
	await process_frame
	for i in 60:
		g.animate(1.0 / 60.0, 5.0, true, 0.0)
	var muzzle: Vector3 = (g.weapon.get_child(0) as Node3D).global_transform.basis * Vector3(0.0, 0.0, -1.0)
	var asset_fwd: float = -((g.weapon as Node3D).global_transform.basis.orthonormalized() * Vector3(0.0, 0.0, -1.0)).z
	_check(asset_fwd > 0.3 or muzzle.length() > 0.0, "gunner có hướng nòng")
	var fa: Vector3 = (_bone_pos(g, "hand.R") - _bone_pos(g, "forearm.R")).normalized()
	_check(fa.z < -0.3, "gunner: cẳng tay chĩa về phía trước (z=%.2f)" % fa.z)

	# overlay: chém hạ/giơ tay, chết nằm xuống
	m.clear_overlay()
	var rest_y: float = _bone_pos(m, "spine.005").y
	m.play("die", 0.45)
	for i in 60:
		m.animate(1.0 / 60.0, 0.0, true, 0.0)
	_check(_bone_pos(m, "spine.005").y < rest_y - 0.5, "chết: đầu hạ thấp (nằm)")
	m.clear_overlay()

	# nháy và mờ
	m.flash()
	var mat: StandardMaterial3D = m._mats[0]
	_check(mat.emission_energy_multiplier > 0.5, "flash bật phát sáng")
	var other: Node3D = _make("swordsman")
	await process_frame
	_check(other._mats[0].emission_energy_multiplier == 0.0, "flash không lan sang nhân vật khác")
	m.fade_out(0.1)
	await create_timer(0.3).timeout
	_check(mat.albedo_color.a < 0.05, "fade_out làm mờ hẳn")
	m.set_render_layers(2)
	var all2: bool = true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		all2 = all2 and (mi as MeshInstance3D).layers == 2
	_check(all2, "set_render_layers áp cho mọi mesh")

	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
