extends "res://scripts/mannequin.gd"
## Thân low poly (M44): các KHỐI RỜI dựng trong Blender (tools/blender/make_bots.py), gắn vào 15 Empty trùng tên 15 khớp proxy.
## Là con của `mannequin.gd` nên dùng lại nguyên API/hoạt ảnh (RigAnimator, IK chân, flash, fade_out, render layers); chỉ khác ở chỗ
## dựng thân: lấy cây khớp từ .glb thay vì tạo khối bằng code. Vị trí khớp trong .glb khớp mannequin.gd (test_m44 kiểm tra), nên IK
## và hitbox không đổi. Màu: vật liệu trong .glb đặt tên theo VAI TRÒ, ở đây tô theo `color` của loại bot (như mannequin.gd).
## Vũ khí: glb low poly (kiếm/rìu/dao/súng) theo `MannequinGltf.weapon_config`, đặt trong khung "hình nhân khối" (kiếm dọc +Y, súng -Z).
## `has_asset(kind)` false (tắt LOWPOLY hoặc thiếu file) -> chủ nhân dùng lớp cũ.

const MannequinGltfScript = preload("res://scripts/mannequin_gltf.gd")
const VisualData = preload("res://scripts/data/visual_data.gd")


static func has_asset(k: String) -> bool:
	return bool(VisualData.LOWPOLY["enabled"]) and VisualData.LOWPOLY["bots"].has(k) and ResourceLoader.exists(String(VisualData.LOWPOLY["bots"][k]))


## Nạp nền model + vũ khí khi vào trận (như MannequinGltf.warm_up).
static func warm_up() -> void:
	for k in VisualData.LOWPOLY["bots"]:
		if has_asset(k):
			ResourceLoader.load_threaded_request(String(VisualData.LOWPOLY["bots"][k]))
	for k in MannequinGltfScript.WEAPONS:
		var f: String = String(MannequinGltfScript.weapon_config(k)["file"])
		if f.ends_with(".glb") and ResourceLoader.exists(f):
			ResourceLoader.load_threaded_request(f)


func _ready() -> void:
	var scene := load(String(VisualData.LOWPOLY["bots"][kind])) as PackedScene
	var holder: Node3D = scene.instantiate()
	var hips: Node3D = holder.find_child("hips", true, false)
	hips.get_parent().remove_child(hips)
	holder.free()
	add_child(hips)
	for jn in JOINT_NAMES:
		joints[jn] = hips if jn == "hips" else hips.find_child(jn, true, false)
	_tint(hips)
	var rig: Dictionary = Global.RIG.get(kind, Global.RIG["dummy"])
	if String(rig["weapon"]) != "none" and MannequinGltfScript.WEAPONS.has(kind):
		_attach_weapon()
	reset_pose()
	animator = AnimatorScript.new()
	animator.setup(self)


## Tô màu theo vai trò vật liệu (tên trong .glb): áo = color, quần = tối 30%, giáp/bốt = tối 50% kim loại, da, vạch phát sáng.
func _tint(root_node: Node) -> void:
	var cloth := _mat(color, 0.05, 0.85)
	var pants := _mat(color.darkened(0.3), 0.05, 0.85)
	var dark := _mat(color.darkened(0.5), 0.7, 0.4)
	var skin := _mat(Global.SKIN_COLOR, 0.0, 0.8)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color.lightened(0.3)
	glow.emission_energy_multiplier = 2.5
	var by_role: Dictionary = {"bd_cloth": cloth, "bd_pants": pants, "bd_dark": dark, "bd_skin": skin, "bd_glow": glow}
	for mi in root_node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(s)
			var role: String = String(src.resource_name) if src != null else "bd_cloth"
			m.set_surface_override_material(s, by_role.get(role, cloth))


func _attach_weapon() -> void:
	var cfg: Dictionary = MannequinGltfScript.weapon_config(kind)
	var asset: Node3D = (load(String(cfg["file"])) as PackedScene).instantiate()
	weapon = _node3d("weapon", joints["hand_r"])
	weapon.add_child(asset)
	_orient_asset(asset, bool(cfg["melee"]), float(cfg["length"]), float(cfg["grip"]), bool(cfg.get("flip", false)))


## Cùng phép với MannequinGltf._orient_asset: trục dài -> +Y (cận chiến) / -Z (súng), dài `length` m, điểm cầm ở gốc.
func _orient_asset(asset: Node3D, melee: bool, length: float, grip: float, flip: bool) -> void:
	var box: AABB = _mesh_aabb(asset)
	var axis: int = 0
	for a in 3:
		if box.size[a] > box.size[axis]:
			axis = a
	var long_axis: Vector3 = [Vector3.RIGHT, Vector3.UP, Vector3.BACK][axis]
	if flip:
		long_axis = -long_axis
	var target: Vector3 = Vector3.UP if melee else Vector3.FORWARD
	var q := Quaternion(long_axis, target) if absf(long_axis.dot(target)) < 0.999 else (Quaternion.IDENTITY if long_axis.dot(target) > 0.0 else Quaternion(Vector3.UP, PI))
	var s: float = length / box.size[axis]
	asset.basis = Basis(q).scaled(Vector3.ONE * s)
	var tail: Vector3 = box.get_center() - long_axis * (box.size[axis] * 0.5)
	asset.position = -(asset.basis * (tail + long_axis * (box.size[axis] * grip)))


func _mesh_aabb(root_node: Node3D) -> AABB:
	var r := AABB()
	var first := true
	for mi in root_node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var a: AABB = m.transform * m.get_aabb()
		var p: Node = m.get_parent()
		while p != root_node and p is Node3D:
			a = (p as Node3D).transform * a
			p = p.get_parent()
		r = a if first else r.merge(a)
		first = false
	return r


## Chớp sáng ngắn trên vũ khí (cửa sổ parry mở); vũ khí glb có mesh nằm sâu trong cây nên tìm đệ quy.
func flash_weapon(duration: float) -> void:
	if weapon == null or Global.reduced_fx:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.5, 0.9, 1.0, 0.85)
	var meshes: Array = weapon.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		(m as MeshInstance3D).material_overlay = mat
	var tw := weapon.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, maxf(duration, 0.05))
	tw.tween_callback(func():
		for m in meshes:
			if is_instance_valid(m):
				(m as MeshInstance3D).material_overlay = null)
