extends Node3D
## Hình nhân người 3D dựng bằng khối cơ bản, có KHUNG XƯƠNG (cây Node3D, pivot đặt ở khớp) để mốc
## sau làm hoạt ảnh. Cao ~1.8m, gốc ở chân. Hình dáng theo `kind` (xem Global.RIG).
## API giữ nguyên: `color`, `flash()`, `fade_out()`; thêm `kind`, `get_joint()`, `reset_pose()`.
##
## Cây khớp: hips > spine > head | shoulder_l > elbow_l | shoulder_r > elbow_r ; hips > hip_l > knee_l | hip_r > knee_r.
## Cầm vũ khí: node "hand_r" (con của elbow_r), vũ khí là node "weapon".

const JOINT_NAMES: Array = [
	"hips", "spine", "head", "shoulder_l", "elbow_l", "shoulder_r", "elbow_r",
	"hip_l", "knee_l", "hip_r", "knee_r", "hand_r",
]

@export var color: Color = Color(0.85, 0.85, 0.9)
## Loại hình dáng: "dummy", "swordsman", "gunner", "elite". Đặt trước add_child.
var kind: String = "dummy"

var joints: Dictionary = {}
var weapon: Node3D
var _body_mats: Array = []   # vật liệu thân/giáp: nháy trắng và mờ dần
var _base_colors: Array = []


func _ready() -> void:
	var rig: Dictionary = Global.RIG.get(kind, Global.RIG["dummy"])
	var sw: float = rig["shoulder"]
	var bulk: float = rig["bulk"]

	var body := _mat(color, 0.3, 0.6)
	var dark := _mat(color.darkened(0.45), 0.7, 0.4)

	var hips := _joint("hips", self, Vector3(0.0, 0.92, 0.0))
	var spine := _joint("spine", hips, Vector3.ZERO)
	_mesh(spine, _box(Vector3(0.5 * sw, 0.62, 0.28 * bulk)), Vector3(0.0, 0.3, 0.0), body)
	_mesh(hips, _box(Vector3(0.36 * sw, 0.2, 0.24 * bulk)), Vector3(0.0, 0.0, 0.0), dark)
	var head := _joint("head", spine, Vector3(0.0, 0.62, 0.0))
	var hm := SphereMesh.new()
	hm.radius = 0.14
	hm.height = 0.28
	_mesh(head, hm, Vector3(0.0, 0.14, 0.0), body)

	for side in [-1, 1]:
		var tag: String = "l" if side < 0 else "r"
		var sh := _joint("shoulder_" + tag, spine, Vector3(0.3 * sw * side, 0.52, 0.0))
		_mesh(sh, _capsule(0.08 * bulk, 0.5), Vector3(0.0, -0.22, 0.0), body)
		var el := _joint("elbow_" + tag, sh, Vector3(0.0, -0.45, 0.0))
		_mesh(el, _capsule(0.07 * bulk, 0.44), Vector3(0.0, -0.2, 0.0), body)
		var hp := _joint("hip_" + tag, hips, Vector3(0.13 * side, -0.05, 0.0))
		_mesh(hp, _capsule(0.12 * bulk, 0.5), Vector3(0.0, -0.22, 0.0), body)
		var kn := _joint("knee_" + tag, hp, Vector3(0.0, -0.45, 0.0))
		_mesh(kn, _capsule(0.1 * bulk, 0.48), Vector3(0.0, -0.22, 0.0), body)
		_mesh(kn, _box(Vector3(0.16, 0.08, 0.26)), Vector3(0.0, -0.43, -0.04), dark)
		if int(rig["armor"]) >= 1:
			var pad: float = 0.2 if int(rig["armor"]) == 1 else 0.3
			_mesh(sh, _box(Vector3(pad, 0.08, pad)), Vector3(0.02 * side, 0.06, 0.0), dark)

	if int(rig["armor"]) >= 2:
		_mesh(spine, _box(Vector3(0.56 * sw, 0.34, 0.36 * bulk)), Vector3(0.0, 0.38, 0.0), dark)
	if rig["glow"]:
		var glow := StandardMaterial3D.new()
		glow.albedo_color = color
		glow.emission_enabled = true
		glow.emission = color.lightened(0.3)
		glow.emission_energy_multiplier = 2.5
		_mesh(spine, _box(Vector3(0.1, 0.5, 0.02)), Vector3(0.0, 0.3, -0.16 * bulk), glow)
		_mesh(head, _box(Vector3(0.2, 0.04, 0.02)), Vector3(0.0, 0.16, -0.13), glow)

	var hand := _joint("hand_r", joints["elbow_r"], Vector3(0.0, -0.42, 0.0))
	match String(rig["weapon"]):
		"sword":
			weapon = _node3d("weapon", hand)
			_mesh(weapon, _box(Vector3(0.05, 0.9, 0.1)), Vector3(0.0, 0.4, 0.0), _mat(Color(0.85, 0.88, 0.95), 0.9, 0.25, false))
			_mesh(weapon, _box(Vector3(0.22, 0.05, 0.08)), Vector3(0.0, 0.0, 0.0), dark)
		"gun":
			weapon = _node3d("weapon", hand)
			_mesh(weapon, _box(Vector3(0.08, 0.14, 0.75)), Vector3(0.0, 0.0, -0.3), dark)
			_mesh(weapon, _box(Vector3(0.06, 0.2, 0.08)), Vector3(0.0, -0.12, -0.05), dark)
	reset_pose()


func get_joint(joint_name: String) -> Node3D:
	return joints.get(joint_name)


## Về tư thế đứng mặc định: mọi khớp xoay 0, tay hơi buông.
func reset_pose() -> void:
	for n in joints.values():
		(n as Node3D).rotation = Vector3.ZERO
	if weapon != null and joints.has("elbow_r"):
		joints["elbow_r"].rotation_degrees = Vector3(-20.0, 0.0, 0.0)
	if weapon != null and weapon.name == "weapon" and kind == "gunner":
		joints["shoulder_r"].rotation_degrees = Vector3(-70.0, 0.0, 0.0)


func _joint(joint_name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var j := _node3d(joint_name, parent)
	j.position = pos
	joints[joint_name] = j
	return j


func _node3d(node_name: String, parent: Node3D) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	parent.add_child(n)
	return n


func _mat(c: Color, metallic: float, roughness: float, flashes: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = roughness
	if flashes: # lưỡi kiếm không nháy/mờ theo thân
		_body_mats.append(m)
		_base_colors.append(c)
	return m


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


## Nháy trắng khi trúng đòn.
func flash() -> void:
	for i in _body_mats.size():
		var m: StandardMaterial3D = _body_mats[i]
		m.albedo_color = Color.WHITE
		create_tween().tween_property(m, "albedo_color", _base_colors[i], 0.12)


## Mờ dần (khi chết).
func fade_out(duration: float) -> void:
	for i in _body_mats.size():
		var m: StandardMaterial3D = _body_mats[i]
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c: Color = m.albedo_color
		create_tween().tween_property(m, "albedo_color", Color(c.r, c.g, c.b, 0.0), duration)
