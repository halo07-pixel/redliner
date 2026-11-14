extends SceneTree
## Test headless M7.1: khung xương hình nhân, 3 loại bot có hình dáng riêng, API cũ còn chạy.
##   timeout 120 godot --headless --path . -s tools/tests/test_mannequin.gd

var failures: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _make(kind: String, color: Color = Color(0.8, 0.2, 0.2)) -> Node3D:
	var m: Node3D = load("res://scripts/mannequin.gd").new()
	m.color = color
	m.kind = kind
	root.add_child(m)
	return m


func _bounds(m: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var a: AABB = mi.global_transform * mi.mesh.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box


## AABB trong hệ tọa độ của chính node (không bị ảnh hưởng bởi tư thế/xoay của cha).
func _local_bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var a: AABB = mi.transform * mi.mesh.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box


func _torso_size(m: Node3D) -> Vector3:
	var mi := m.get_joint("spine").get_child(0) as MeshInstance3D
	return (mi.mesh as BoxMesh).size


func _run() -> void:
	await process_frame
	var M = load("res://scripts/mannequin.gd")
	var made: Dictionary = {}
	for kind in ["dummy", "swordsman", "gunner", "elite"]:
		made[kind] = _make(kind)
	await process_frame

	for kind in made.keys():
		var m: Node3D = made[kind]
		var all_joints: bool = true
		for j in M.JOINT_NAMES:
			if m.get_joint(j) == null:
				all_joints = false
		_check(all_joints, "%s: đủ %d khớp" % [kind, M.JOINT_NAMES.size()])
		var b := _bounds(m)
		_check(b.position.y > -0.1 and b.end.y > 1.65 and b.end.y < 1.95, "%s: cao ~1.8m, chân chạm đất (đỉnh %.2f)" % [kind, b.end.y])
	_check(made["swordsman"].get_joint("head").get_parent().name == "spine", "đầu gắn vào spine (cây phân cấp)")
	_check(made["swordsman"].get_joint("knee_l").get_parent() == made["swordsman"].get_joint("hip_l"), "gối gắn vào hông")

	var sw := {}
	for kind in made.keys():
		var m: Node3D = made[kind]
		sw[kind] = m.get_joint("shoulder_l").global_position.distance_to(m.get_joint("shoulder_r").global_position)
	_check(sw["swordsman"] > sw["gunner"] and sw["elite"] > sw["swordsman"], "độ rộng vai: gunner < swordsman < elite")
	_check(made["swordsman"].weapon != null and made["gunner"].weapon != null and made["dummy"].weapon == null, "kiếm/súng có vũ khí, bia không")
	var gb := _local_bounds(made["gunner"].weapon)
	_check(gb.size.z > gb.size.x * 4.0, "súng của gunner dài (nòng dọc theo Z)")
	var sb := _local_bounds(made["swordsman"].weapon)
	_check(sb.size.y > sb.size.x * 4.0, "kiếm dài theo Y")
	var et: Vector3 = _torso_size(made["elite"])
	var gt: Vector3 = _torso_size(made["gunner"])
	_check(et.x > gt.x and et.z > gt.z, "thân elite rộng và dày hơn gunner")
	_check(made["elite"].find_children("*", "MeshInstance3D", true, false).size() > made["swordsman"].find_children("*", "MeshInstance3D", true, false).size(), "elite có thêm giáp/vạch sáng")

	# Pose
	made["swordsman"].get_joint("knee_l").rotation_degrees = Vector3(40.0, 0.0, 0.0)
	made["swordsman"].reset_pose()
	_check(made["swordsman"].get_joint("knee_l").rotation == Vector3.ZERO, "reset_pose đưa khớp về 0")

	# API cũ
	var d: Node3D = made["dummy"]
	var mat0: StandardMaterial3D = (d.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).material_override
	d.flash()
	_check(mat0.albedo_color == Color.WHITE, "flash() nháy trắng")
	await create_timer(0.3).timeout
	_check(mat0.albedo_color.is_equal_approx(Color(0.8, 0.2, 0.2)) or mat0.albedo_color.r > 0.1, "flash() trả về màu gốc")
	d.fade_out(0.1)
	_check(mat0.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "fade_out() bật trong suốt")

	# Bot dùng đúng kind
	for t in ["swordsman", "gunner", "elite"]:
		var b = load("res://scripts/bot.gd").new()
		b.setup(t, 1)
		root.add_child(b)
		await process_frame
		_check(b.mannequin.kind == t and b.mannequin.get_joint("hand_r") != null, "bot %s dùng khung xương kind=%s" % [t, t])
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
