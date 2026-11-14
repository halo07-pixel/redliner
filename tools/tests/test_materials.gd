extends SceneTree
## Test headless M6.2: vật liệu theo vai trò khớp bảng màu, vật phát sáng/kim loại đúng, arena dựng được.
##   timeout 120 godot --headless --path . -s tools/tests/test_materials.gd

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
	var Mat = load("res://scripts/materials.gd")
	var pal: Dictionary = Global.PALETTE
	var params: Dictionary = Global.MATERIAL_PARAMS
	_check(pal.keys().size() == params.keys().size(), "PALETTE và MATERIAL_PARAMS cùng bộ vai trò")
	for role in pal.keys():
		var m: StandardMaterial3D = Mat.make(role)
		_check(m.albedo_color == pal[role], "màu '%s' khớp bảng màu" % role)
		_check(Mat.make(role) == m, "'%s' được cache" % role)
	_check(Mat.make("grapple").emission_enabled, "bệ đu móc phát sáng")
	_check(Mat.make("trim").emission_enabled, "vạch trim phát sáng")
	_check(not Mat.make("floor").emission_enabled, "sàn không phát sáng")
	_check(Mat.make("pillar").metallic > Mat.make("floor").metallic, "cột kim loại hơn sàn")
	_check(Mat.make("floor").uv1_triplanar, "sàn dùng triplanar")
	var colors: Array = []
	for role in ["floor", "wall", "pillar", "runwall", "grapple", "ramp"]:
		colors.append(pal[role])
	var uniq: bool = true
	for i in colors.size():
		for j in range(i + 1, colors.size()):
			if colors[i].is_equal_approx(colors[j]):
				uniq = false
	_check(uniq, "các vai trò chính có màu phân biệt")
	var arena: Node3D = load("res://scripts/arena.gd").new()
	root.add_child(arena)
	await process_frame
	var meshes: int = 0
	var bad: int = 0
	for n in arena.find_children("*", "MeshInstance3D", true, false):
		if n.get_parent() is StaticBody3D and n.get_parent().get_parent() == arena:
			meshes += 1
			if (n as MeshInstance3D).mesh.material == null:
				bad += 1
	_check(meshes >= 14 and bad == 0, "arena dựng %d khối, đều có vật liệu" % meshes)
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
