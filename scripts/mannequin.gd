extends Node3D
## Hình nhân người 3D dựng bằng khối cơ bản, có KHUNG XƯƠNG (cây Node3D, pivot đặt ở khớp) để mốc
## sau làm hoạt ảnh. Cao ~1.8m, gốc ở chân. Hình dáng theo `kind` (xem Global.RIG).
## API giữ nguyên: `color`, `flash()`, `fade_out()`; thêm `kind`, `get_joint()`, `reset_pose()`.
##
## Cây khớp: hips > spine > head | shoulder_l > elbow_l | shoulder_r > elbow_r ; hips > hip_l > knee_l | hip_r > knee_r.
## Cầm vũ khí: node "hand_r" (con của elbow_r), vũ khí là node "weapon".

const AnimatorScript = preload("res://scripts/rig_animator.gd")
const JOINT_NAMES: Array = [
	"hips", "spine", "head", "shoulder_l", "elbow_l", "shoulder_r", "elbow_r",
	"hip_l", "knee_l", "hip_r", "knee_r", "hand_r",
	"hand_l", "ankle_l", "ankle_r",
]

@export var color: Color = Color(0.85, 0.85, 0.9)
## Loại hình dáng: "dummy", "swordsman", "gunner", "elite". Đặt trước add_child.
var kind: String = "dummy"
## Bám chân xuống mặt đất bằng IK (bật mặc định; thân người chơi chỉ để đổ bóng nên tắt).
var ik_feet: bool = true

var joints: Dictionary = {}
var weapon: Node3D
var animator: RefCounted
var _body_mats: Array = []   # vật liệu thân/giáp: nháy trắng và mờ dần
var _base_colors: Array = []


func _ready() -> void:
	var rig: Dictionary = Global.RIG.get(kind, Global.RIG["dummy"])
	var sw: float = rig["shoulder"]
	var bulk: float = rig["bulk"]
	var style: String = rig.get("style", "none")

	var cloth := _mat(color, 0.05, 0.85)                       # áo
	var pants := _mat(color.darkened(0.3), 0.05, 0.85)         # quần
	var dark := _mat(color.darkened(0.5), 0.7, 0.4)            # giáp, đai, bốt
	var skin := _mat(Global.SKIN_COLOR, 0.0, 0.8)              # da

	var hips := _joint("hips", self, Vector3(0.0, 0.92, 0.0))
	var spine := _joint("spine", hips, Vector3.ZERO)
	# Thân: ngực (child đầu tiên của spine), bụng, đai, cổ.
	_mesh(spine, _box(Vector3(0.5 * sw, 0.36, 0.28 * bulk)), Vector3(0.0, 0.44, 0.0), cloth)
	_mesh(spine, _box(Vector3(0.4 * sw, 0.28, 0.24 * bulk)), Vector3(0.0, 0.14, 0.0), cloth)
	_mesh(spine, _box(Vector3(0.43 * sw, 0.07, 0.27 * bulk)), Vector3(0.0, 0.0, 0.0), dark)
	_mesh(spine, _box(Vector3(0.1, 0.12, 0.1)), Vector3(0.0, 0.61, 0.0), skin)
	_mesh(hips, _box(Vector3(0.34 * sw, 0.18, 0.24 * bulk)), Vector3(0.0, -0.06, 0.0), pants)

	var head := _joint("head", spine, Vector3(0.0, 0.62, 0.0))
	var hm := SphereMesh.new()
	hm.radius = 0.13
	hm.height = 0.26
	_mesh(head, hm, Vector3(0.0, 0.13, 0.0), skin)
	for ex in [-1.0, 1.0]:
		_mesh(head, _box(Vector3(0.03, 0.02, 0.01)), Vector3(0.05 * ex, 0.15, -0.125), dark)   # mắt

	for side in [-1, 1]:
		var tag: String = "l" if side < 0 else "r"
		var sh := _joint("shoulder_" + tag, spine, Vector3(0.3 * sw * side, 0.52, 0.0))
		_mesh(sh, _sphere(0.085 * bulk), Vector3.ZERO, cloth)
		_mesh(sh, _capsule(0.075 * bulk, 0.5), Vector3(0.0, -0.22, 0.0), cloth)
		var el := _joint("elbow_" + tag, sh, Vector3(0.0, -0.45, 0.0))
		_mesh(el, _sphere(0.065 * bulk), Vector3.ZERO, cloth)
		_mesh(el, _capsule(0.062 * bulk, 0.44), Vector3(0.0, -0.2, 0.0), cloth)
		var hnd := _joint("hand_" + tag, el, Vector3(0.0, -0.42, 0.0))
		_mesh(hnd, _box(Vector3(0.08, 0.09, 0.045)), Vector3(0.0, -0.045, 0.0), skin)   # lòng bàn tay
		_mesh(hnd, _box(Vector3(0.075, 0.065, 0.04)), Vector3(0.0, -0.115, 0.0), skin)  # các ngón
		var hp := _joint("hip_" + tag, hips, Vector3(0.13 * side, -0.05, 0.0))
		_mesh(hp, _capsule(0.115 * bulk, 0.5), Vector3(0.0, -0.22, 0.0), pants)
		var kn := _joint("knee_" + tag, hp, Vector3(0.0, -0.45, 0.0))
		_mesh(kn, _sphere(0.095 * bulk), Vector3.ZERO, pants)
		_mesh(kn, _capsule(0.088 * bulk, 0.42), Vector3(0.0, -0.18, 0.0), pants)
		var ak := _joint("ankle_" + tag, kn, Vector3(0.0, -0.38, 0.0))
		_mesh(ak, _box(Vector3(0.13, 0.08, 0.27)), Vector3(0.0, 0.0, -0.05), dark)      # bốt
		_mesh(ak, _box(Vector3(0.12, 0.1, 0.12)), Vector3(0.0, 0.07, 0.02), dark)       # cổ bốt
		if int(rig["armor"]) >= 1:
			var pad: float = 0.2 if int(rig["armor"]) == 1 else 0.3
			_mesh(sh, _box(Vector3(pad, 0.08, pad)), Vector3(0.02 * side, 0.06, 0.0), dark)

	if int(rig["armor"]) >= 2:
		_mesh(spine, _box(Vector3(0.56 * sw, 0.34, 0.36 * bulk)), Vector3(0.0, 0.38, 0.0), dark)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color.lightened(0.3)
	glow.emission_energy_multiplier = 2.5
	_style_details(style, spine, head, hips, joints, sw, bulk, cloth, dark, glow)
	if rig["glow"]:
		_mesh(spine, _box(Vector3(0.1, 0.5, 0.02)), Vector3(0.0, 0.3, -0.19 * bulk), glow)

	var hand: Node3D = joints["hand_r"]
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
	animator = AnimatorScript.new()
	animator.setup(self)


## Chi tiết riêng theo loại (hình bóng nhận ra từ xa): ronin = kiếm sĩ, ranger = xạ thủ, guard = tinh nhuệ.
func _style_details(style: String, spine: Node3D, head: Node3D, hips: Node3D, js: Dictionary, sw: float, bulk: float, cloth: Material, dark: Material, glow: Material) -> void:
	match style:
		"ronin":
			_mesh(head, _box(Vector3(0.29, 0.035, 0.29)), Vector3(0.0, 0.19, 0.0), dark)                  # băng đầu
			_mesh(head, _box(Vector3(0.04, 0.16, 0.03)), Vector3(0.0, 0.1, 0.15), dark)                    # đuôi băng
			var sash := _box(Vector3(0.1, 0.55, 0.03))
			var sm := MeshInstance3D.new()
			sm.mesh = sash
			sm.material_override = dark
			sm.position = Vector3(0.0, 0.34, -0.15 * bulk)
			sm.rotation_degrees = Vector3(0.0, 0.0, 28.0)
			spine.add_child(sm)                                                                             # dây đeo chéo ngực
			_mesh(hips, _box(Vector3(0.1, 0.4, 0.04)), Vector3(0.0, -0.25, -0.13 * bulk), cloth)           # tà áo trước
		"ranger":
			var hood := SphereMesh.new()
			hood.radius = 0.15
			hood.height = 0.3
			_mesh(head, hood, Vector3(0.0, 0.15, 0.035), dark)                                              # mũ trùm
			_mesh(head, _box(Vector3(0.2, 0.05, 0.03)), Vector3(0.0, 0.15, -0.128), glow)                  # kính
			var band := MeshInstance3D.new()
			band.mesh = _box(Vector3(0.09, 0.52, 0.03))
			band.material_override = dark
			band.position = Vector3(0.0, 0.33, -0.15 * bulk)
			band.rotation_degrees = Vector3(0.0, 0.0, -30.0)
			spine.add_child(band)                                                                           # dây đạn chéo ngực
			for ox in [-1.0, 1.0]:
				_mesh(hips, _box(Vector3(0.1, 0.11, 0.08)), Vector3(0.22 * sw * ox, -0.07, -0.1 * bulk), dark)  # túi đạn
		"guard":
			var helm := SphereMesh.new()
			helm.radius = 0.155
			helm.height = 0.31
			_mesh(head, helm, Vector3(0.0, 0.15, 0.0), dark)                                                # mũ giáp
			_mesh(head, _box(Vector3(0.18, 0.03, 0.02)), Vector3(0.0, 0.15, -0.15), glow)                  # khe nhìn phát sáng
			_mesh(head, _box(Vector3(0.04, 0.1, 0.22)), Vector3(0.0, 0.3, 0.0), dark)                      # mào mũ
			for side in [-1, 1]:
				var tag: String = "l" if side < 0 else "r"
				_mesh(js["knee_" + tag], _box(Vector3(0.14, 0.2, 0.14)), Vector3(0.0, -0.2, -0.03), dark)  # giáp ống chân
				_mesh(js["elbow_" + tag], _box(Vector3(0.11, 0.2, 0.11)), Vector3(0.0, -0.2, 0.0), dark)   # giáp cẳng tay


## Chủ nhân gọi mỗi frame vật lý để chạy hoạt ảnh thân (xem rig_animator.gd).
func animate(delta: float, speed: float, grounded: bool, vel_y: float, state_name: String = "", side: float = 1.0) -> void:
	animator.update(delta, speed, grounded, vel_y, state_name, side)


## Hướng đi cục bộ (x phải, y tiến) và tốc độ quay người (độ/giây): dáng chạy theo hướng (M30). Chỉ hình ảnh.
func set_motion(dir_local: Vector2, turn_deg_per_s: float) -> void:
	animator.set_motion(dir_local, turn_deg_per_s)


## Chạy overlay chiến đấu ("swing", "shoot", "parry", "parry_miss", "hurt", "stagger", "die"); xem rig_animator.gd.
func play(overlay_name: String, duration: float, data: Dictionary = {}) -> void:
	animator.play(overlay_name, duration, data)


## Mục tiêu nhìn (vị trí thế giới) hoặc null. Chỉ hiển thị (IK đầu/thân).
func set_look_target(p: Variant) -> void:
	animator.set_look_target(p)


## Điểm tay trái cần chạm để đỡ báng súng (thế giới): phần trước thân súng.
func support_grip() -> Vector3:
	return weapon.to_global(Vector3(0.0, -0.02, -0.4)) if weapon != null else Vector3.ZERO


## Chớp sáng ngắn trên vũ khí (báo cửa sổ parry đang mở). Chỉ hình ảnh; không làm gì khi giảm hiệu ứng.
func flash_weapon(duration: float) -> void:
	if weapon == null or Global.reduced_fx:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.5, 0.9, 1.0, 0.85)
	var meshes: Array = []
	for c in weapon.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_overlay = mat
			meshes.append(c)
	var tw := weapon.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, maxf(duration, 0.05))
	tw.tween_callback(func():
		for m in meshes:
			if is_instance_valid(m):
				(m as MeshInstance3D).material_overlay = null)


func clear_overlay() -> void:
	animator.clear_overlay()
	reset_pose()


## Đặt render layer cho mọi mesh (vd. ẩn với camera của chính người chơi nhưng vẫn đổ bóng).
func set_render_layers(mask: int) -> void:
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).layers = mask


func get_joint(joint_name: String) -> Node3D:
	return joints.get(joint_name)


## Về tư thế đứng mặc định: mọi khớp xoay 0, tay hơi buông.
func reset_pose() -> void:
	for n in joints.values():
		(n as Node3D).rotation = Vector3.ZERO
	if weapon != null and joints.has("elbow_r"):
		joints["elbow_r"].rotation_degrees = Vector3(-20.0, 0.0, 0.0)
	if weapon != null and weapon.name == "weapon" and (kind == "gunner" or kind == "bomber"):
		joints["shoulder_r"].rotation_degrees = Vector3(70.0, 0.0, 0.0)


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


func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
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
