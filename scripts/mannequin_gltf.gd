extends Node3D
## Người que dựng từ model glTF (GodoDude, MIT) + vũ khí thật (Quaternius CC0, HoneyBadger CC0).
## Cùng API với `mannequin.gd`, để `RigAnimator` điều khiển KHÔNG đổi: nhân vật có một cây khớp "proxy"
## (Node3D vô hình, cùng tên/cấu trúc với hình nhân khối); mỗi frame, góc xoay của proxy được chuyển sang
## xương của model bằng phép "delta toàn cục" (không phụ thuộc hướng trục xương của Blender/Rigify).
## `MannequinGltf.has_asset(kind)` cho biết có model không; thiếu asset thì chủ nhân dùng mannequin.gd.

const AnimatorScript = preload("res://scripts/rig_animator.gd")
const MODEL_PATH: String = "res://assets/characters/godo/GodoDude.gltf"
const HEIGHT: float = 1.8
const JOINT_NAMES: Array = [
	"hips", "spine", "head", "shoulder_l", "elbow_l", "shoulder_r", "elbow_r",
	"hip_l", "knee_l", "hip_r", "knee_r", "hand_r",
	"hand_l", "ankle_l", "ankle_r",
]
## Khớp proxy -> [khớp cha, xương của model]. Bên "l" của hình nhân khối nằm ở -X, tức xương ".L" khi model quay mặt về -Z.
const JOINT_TREE: Dictionary = {
	"hips": ["", "spine"], "spine": ["hips", "spine.002"], "head": ["spine", "spine.005"],
	"shoulder_l": ["spine", "upper_arm.L"], "elbow_l": ["shoulder_l", "forearm.L"], "hand_l": ["elbow_l", "hand.L"],
	"shoulder_r": ["spine", "upper_arm.R"], "elbow_r": ["shoulder_r", "forearm.R"], "hand_r": ["elbow_r", "hand.R"],
	"hip_l": ["hips", "thigh.L"], "knee_l": ["hip_l", "shin.L"], "ankle_l": ["knee_l", "foot.L"],
	"hip_r": ["hips", "thigh.R"], "knee_r": ["hip_r", "shin.R"], "ankle_r": ["knee_r", "foot.R"],
}
## Thứ tự cập nhật xương (cha trước con).
const BONE_ORDER: Array = [
	"hips", "spine", "head", "hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r",
	"shoulder_l", "elbow_l", "hand_l", "shoulder_r", "elbow_r", "hand_r",
]
## Xương cần "kéo thẳng xuống" ở tư thế gốc (model dạng chữ A): khớp -> xương con để lấy hướng.
const STRAIGHTEN: Dictionary = {
	"shoulder_l": "forearm.L", "elbow_l": "hand.L", "shoulder_r": "forearm.R", "elbow_r": "hand.R",
	"hip_l": "shin.L", "knee_l": "foot.L", "hip_r": "shin.R", "knee_r": "foot.R",
}
## kind -> vũ khí. dir: hướng trục dài của asset ở dạng gốc (mũi nhọn/nòng súng); length: m; grip: tỉ lệ từ đuôi tới chỗ cầm.
const WEAPONS: Dictionary = {
	"swordsman": {"file": "res://assets/weapons/quaternius/Sword.fbx", "length": 1.0, "grip": 0.15, "melee": true, "hold_deg": -56.0},
	"elite": {"file": "res://assets/weapons/quaternius/Axe_Double.fbx", "length": 0.85, "grip": 0.2, "melee": true, "hold_deg": -56.0},
	"gunner": {"file": "res://assets/weapons/honeybadger/HoneyBadger.fbx", "length": 0.85, "grip": 0.45, "melee": false, "hold_deg": -90.0},
	"rusher": {"file": "res://assets/weapons/quaternius/Dagger.fbx", "length": 0.6, "grip": 0.1, "melee": true, "hold_deg": -56.0},
	"bomber": {"file": "res://assets/weapons/honeybadger/HoneyBadger.fbx", "length": 0.95, "grip": 0.45, "melee": false, "hold_deg": -90.0},
}

@export var color: Color = Color(0.85, 0.85, 0.9)
var kind: String = "swordsman"
## Bám chân xuống mặt đất bằng IK (cùng API với mannequin.gd).
var ik_feet: bool = true
var joints: Dictionary = {}
var weapon: Node3D
var animator: RefCounted

var model: Node3D
var skeleton: Skeleton3D
var _flip: Basis = Basis(Vector3.UP, PI)   # model nhìn +Z, game nhìn -Z
var _scale: float = 1.0
var _bone_idx: Dictionary = {}
var _bone_rest_g: Dictionary = {}    # khớp -> basis toàn cục lúc gốc (trong hệ model)
var _bone_fix: Dictionary = {}       # khớp -> phép xoay kéo xương thẳng xuống
var _root_rest_pos: Vector3
var _hips_base_y: float = 0.92
var _mats: Array = []


static func has_asset(k: String) -> bool:
	return WEAPONS.has(k) and ResourceLoader.exists(MODEL_PATH)


func _ready() -> void:
	_build_proxy_joints()
	model = (load(MODEL_PATH) as PackedScene).instantiate()
	add_child(model)
	model.basis = _flip
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	_fit_height()
	_prepare_skeleton()
	_fit_proxy_lengths()
	_prepare_materials()
	_attach_weapon()
	animator = AnimatorScript.new()
	animator.setup(self)
	reset_pose()


func _build_proxy_joints() -> void:
	for jn in JOINT_NAMES:
		var n := Node3D.new()
		n.name = jn
		var parent_name: String = JOINT_TREE[jn][0]
		(self if parent_name == "" else joints[parent_name] as Node3D).add_child(n)
		joints[jn] = n
	(joints["hips"] as Node3D).position = Vector3(0.0, _hips_base_y, 0.0)


func _fit_height() -> void:
	var m: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var h: float = m.get_aabb().size.y * model.scale.y
	_scale = HEIGHT / maxf(h, 0.01)
	model.scale = Vector3.ONE * _scale
	model.basis = _flip.scaled(Vector3.ONE * _scale)


func _prepare_skeleton() -> void:
	for jn in JOINT_NAMES:
		var bn: String = JOINT_TREE[jn][1]
		var i: int = skeleton.find_bone(bn)
		assert(i >= 0, "thiếu xương " + bn)
		_bone_idx[jn] = i
		_bone_rest_g[jn] = skeleton.get_bone_global_rest(i).basis.orthonormalized()
	_root_rest_pos = skeleton.get_bone_rest(_bone_idx["hips"]).origin
	for jn in STRAIGHTEN:
		var i: int = _bone_idx[jn]
		var j: int = skeleton.find_bone(STRAIGHTEN[jn])
		var dir: Vector3 = (skeleton.get_bone_global_rest(j).origin - skeleton.get_bone_global_rest(i).origin).normalized()
		_bone_fix[jn] = Basis(Quaternion(dir, Vector3.DOWN))
	# bàn tay đi theo cẳng tay
	_bone_fix["hand_l"] = _bone_fix["elbow_l"]
	_bone_fix["hand_r"] = _bone_fix["elbow_r"]


## Đặt vị trí khớp proxy theo xương thật (M20) để IK (rig_ik.gd) giải đúng độ dài xương: cặp khớp trên/dưới của tay chân thẳng
## xuống ở tư thế gốc nên đoạn dưới = (0, -độ dài, 0); các khớp còn lại lấy hiệu vị trí xương. Góc xoay proxy vẫn là thứ duy nhất
## đi vào `_apply_pose`, nên FK không đổi.
func _fit_proxy_lengths() -> void:
	var wp: Dictionary = {}
	for jn in JOINT_NAMES:
		wp[jn] = to_local(skeleton.global_transform * skeleton.get_bone_global_rest(int(_bone_idx[jn])).origin)
	const LOWER: Array = ["elbow_l", "elbow_r", "hand_l", "hand_r", "knee_l", "knee_r", "ankle_l", "ankle_r"]
	for jn in JOINT_NAMES:
		var parent_name: String = JOINT_TREE[jn][0]
		if parent_name == "":
			continue
		var j: Node3D = joints[jn]
		if jn in LOWER:
			j.position = Vector3(0.0, -(wp[jn] as Vector3).distance_to(wp[parent_name]), 0.0)
		else:
			j.position = (wp[jn] as Vector3) - (wp[parent_name] as Vector3)
	_hips_base_y = (wp["hips"] as Vector3).y
	(joints["hips"] as Node3D).position = Vector3(0.0, _hips_base_y, 0.0)


## Mỗi nhân vật có bản sao vật liệu riêng (tô màu, nháy, mờ).
func _prepare_materials() -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var src: Material = m.get_active_material(s)
			var copy: StandardMaterial3D = (src as StandardMaterial3D).duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
			copy.albedo_color = color
			copy.emission_enabled = true
			copy.emission = Color.WHITE
			copy.emission_energy_multiplier = 0.0
			m.set_surface_override_material(s, copy)
			_mats.append(copy)


func _attach_weapon() -> void:
	var cfg: Dictionary = WEAPONS[kind]
	var att := BoneAttachment3D.new()
	att.bone_name = JOINT_TREE["hand_r"][1]
	skeleton.add_child(att)
	var asset: Node3D = (load(String(cfg["file"])) as PackedScene).instantiate()
	# Khung vũ khí trong hệ "hình nhân khối": kiếm dọc +Y, súng nòng về -Z; chuôi tại gốc.
	var pivot := Node3D.new()
	pivot.name = "weapon"
	pivot.add_child(asset)
	_orient_asset(asset, bool(cfg["melee"]), float(cfg["length"]), float(cfg["grip"]))
	# Đặt pivot sao cho ở tư thế gốc nó trùng khung của khớp hand_r (+ lòng bàn tay cách cổ tay 0.08 m).
	var b0: Basis = (_bone_fix["hand_r"] as Basis) * (_bone_rest_g["hand_r"] as Basis)
	var to_bone: Basis = b0.inverse() * _flip.inverse()
	# Cách cầm: xoay quanh X của bàn tay. Cận chiến: lưỡi vuông góc cẳng tay, hơi chếch lên; súng: nòng dọc theo cẳng tay.
	var hold: Basis = Basis(Vector3.RIGHT, deg_to_rad(float(cfg["hold_deg"])))
	pivot.transform = Transform3D((to_bone * hold).scaled(Vector3.ONE / _scale), to_bone * Vector3(0.0, -0.08, 0.0) / _scale)
	att.add_child(pivot)
	weapon = pivot


## Xoay/co asset: trục dài -> +Y (cận chiến) hoặc -Z (súng), dài `length` m, điểm cầm ở gốc.
func _orient_asset(asset: Node3D, melee: bool, length: float, grip: float) -> void:
	var box: AABB = _mesh_aabb(asset)
	var axis: int = 0
	for a in 3:
		if box.size[a] > box.size[axis]:
			axis = a
	var long_axis: Vector3 = [Vector3.RIGHT, Vector3.UP, Vector3.BACK][axis]
	var target: Vector3 = Vector3.UP if melee else Vector3.FORWARD
	# Quaternius: mũi ở +Y; HoneyBadger: nòng ở +Z (xem ảnh xem thử) -> đưa nòng về -Z
	var from: Vector3 = long_axis
	var q := Quaternion(from, target) if absf(from.dot(target)) < 0.999 else (Quaternion.IDENTITY if from.dot(target) > 0.0 else Quaternion(Vector3.UP, PI))
	var s: float = length / box.size[axis]
	asset.basis = Basis(q).scaled(Vector3.ONE * s)
	var center: Vector3 = box.get_center()
	var tail: Vector3 = center - long_axis * (box.size[axis] * 0.5)   # đầu đuôi trong hệ asset
	var grip_pt: Vector3 = tail + long_axis * (box.size[axis] * grip)
	asset.position = -(asset.basis * grip_pt)


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


## Chuyển góc xoay của các khớp proxy sang xương model.
func _apply_pose() -> void:
	var hips: Node3D = joints["hips"]
	var off: Vector3 = _flip.inverse() * (hips.position - Vector3(0.0, _hips_base_y, 0.0)) / _scale
	skeleton.set_bone_pose_position(_bone_idx["hips"], _root_rest_pos + off)
	for jn in BONE_ORDER:
		var i: int = _bone_idx[jn]
		var d_adapter: Basis = global_transform.basis.inverse() * (joints[jn] as Node3D).global_transform.basis
		d_adapter = d_adapter.orthonormalized()
		var d_model: Basis = _flip.inverse() * d_adapter * _flip
		var desired: Basis = d_model * (_bone_fix.get(jn, Basis.IDENTITY) as Basis) * (_bone_rest_g[jn] as Basis)
		var parent_i: int = skeleton.get_bone_parent(i)
		var parent_g: Basis = skeleton.get_bone_global_pose(parent_i).basis.orthonormalized() if parent_i >= 0 else Basis.IDENTITY
		skeleton.set_bone_pose_rotation(i, (parent_g.inverse() * desired).get_rotation_quaternion())


## Hướng đi cục bộ + tốc độ quay người (M30), chỉ hình ảnh; cùng animator với rig khối.
func set_motion(dir_local: Vector2, turn_deg_per_s: float) -> void:
	animator.set_motion(dir_local, turn_deg_per_s)


func animate(delta: float, speed: float, grounded: bool, vel_y: float, state_name: String = "", side: float = 1.0) -> void:
	animator.update(delta, speed, grounded, vel_y, state_name, side)
	_apply_pose()


func play(overlay_name: String, duration: float, data: Dictionary = {}) -> void:
	animator.play(overlay_name, duration, data)


## Mục tiêu nhìn (vị trí thế giới) hoặc null. Chỉ hiển thị (IK đầu/thân).
func set_look_target(p: Variant) -> void:
	animator.set_look_target(p)


## Điểm tay trái cần chạm để đỡ báng súng (thế giới): phía trước bàn tay phải theo hướng ngắm.
func support_grip() -> Vector3:
	var hr: Node3D = joints["hand_r"]
	return hr.global_position + global_transform.basis * Vector3(0.0, 0.03, -0.42)


func clear_overlay() -> void:
	animator.clear_overlay()
	reset_pose()


func set_render_layers(mask: int) -> void:
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).layers = mask


func get_joint(joint_name: String) -> Node3D:
	return joints.get(joint_name)


func reset_pose() -> void:
	for n in joints.values():
		(n as Node3D).rotation = Vector3.ZERO
	if weapon != null:
		joints["elbow_r"].rotation_degrees = Vector3(-20.0, 0.0, 0.0)
		if kind == "gunner" or kind == "bomber":
			joints["shoulder_r"].rotation_degrees = Vector3(70.0, 0.0, 0.0)
	_apply_pose()


func flash() -> void:
	for m in _mats:
		var mat: StandardMaterial3D = m
		mat.emission_energy_multiplier = 1.5
		create_tween().tween_property(mat, "emission_energy_multiplier", 0.0, 0.12)


func fade_out(duration: float) -> void:
	for m in _mats:
		var mat: StandardMaterial3D = m
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c: Color = mat.albedo_color
		create_tween().tween_property(mat, "albedo_color", Color(c.r, c.g, c.b, 0.0), duration)
