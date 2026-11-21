extends RefCounted
## IK cho hình nhân (M20): giải hai khớp (vai-khuỷu-cổ tay, hông-gối-cổ chân) bằng định lý cos, bám chân xuống mặt đất,
## quay đầu/thân nhìn mục tiêu, tay phụ đỡ báng súng. Chỉ hiển thị, không ảnh hưởng vật lý.
## Chạy SAU khi hoạt ảnh FK đặt xong góc khớp (xem rig_animator.gd). Độ dài xương lấy từ vị trí khớp con, nên hình nhân
## mà khớp không có độ dài tự bỏ qua IK và vẫn chạy FK như cũ (proxy glTF được gán độ dài từ xương thật, xem mannequin_gltf.gd).

const MIN_BONE: float = 0.05

# Trạng thái bám chân (làm mượt theo thời gian).
var foot_off: Array = [0.0, 0.0]   # độ nâng/hạ bàn chân (m) so với sàn phẳng: trái, phải
var hip_off: float = 0.0           # độ hạ hông (m)
var look_target: Variant = null    # Vector3 thế giới hoặc null
var look_w: float = 0.0
var look_yaw: float = 0.0
var look_pitch: float = 0.0
var support_w: float = 0.0
var enabled_feet: bool = true


## Giải một chi: trả về {"basis": xoay cục bộ của khớp trên (so với cha), "flex": góc gập khớp giữa (rad, có dấu theo loại chi),
## "unreached": phần còn thiếu nếu đích ngoài tầm (m)}. `is_leg`: gối gập ra sau (khớp x âm); tay: khuỷu gập ra trước (x dương).
## Hàm thuần: nhận basis của cha, vị trí khớp trên, độ dài hai đoạn và đích (đều theo toạ độ thế giới).
static func solve(parent_basis: Basis, origin: Vector3, l1: float, l2: float, target: Vector3, is_leg: bool) -> Dictionary:
	var d: Vector3 = parent_basis.orthonormalized().inverse() * (target - origin)
	var dist: float = maxf(d.length(), 0.0001)
	var dhat: Vector3 = d / dist
	var r: float = clampf(dist, absf(l1 - l2) + 0.002, l1 + l2 - 0.002)
	var cos_flex_in: float = clampf((l1 * l1 + l2 * l2 - r * r) / (2.0 * l1 * l2), -1.0, 1.0)
	var flex: float = PI - acos(cos_flex_in)
	var alpha: float = acos(clampf((l1 * l1 + r * r - l2 * l2) / (2.0 * l1 * r), -1.0, 1.0))
	# Trục bản lề = trục X chiếu vuông góc với d (mặt phẳng chi giữ gần mặt phẳng dọc thân); khuỷu/gối nằm lệch về phía p.
	var xh: Vector3 = Vector3.RIGHT - dhat * dhat.x
	if xh.length() < 0.001:
		xh = Vector3.UP - dhat * dhat.y
	xh = xh.normalized()
	var p: Vector3 = xh.cross(dhat)
	if not is_leg:
		p = -p
	var t: Vector3 = dhat * cos(alpha) + p * sin(alpha)
	var y: Vector3 = -t
	var z: Vector3 = xh.cross(y)
	return {"basis": Basis(xh, y, z), "flex": -flex if is_leg else flex, "unreached": maxf(dist - (l1 + l2 - 0.002), 0.0)}


## Áp kết quả giải lên khớp thật, pha trộn với tư thế FK hiện tại theo `weight` (0 = giữ FK, 1 = IK hoàn toàn).
## Trả về false nếu chi không có độ dài (proxy glTF) hoặc thiếu khớp.
static func apply_limb(upper: Node3D, lower: Node3D, end: Node3D, target_world: Vector3, is_leg: bool, weight: float = 1.0) -> bool:
	if upper == null or lower == null or end == null or weight <= 0.0:
		return false
	var l1: float = lower.position.length()
	var l2: float = end.position.length()
	if l1 < MIN_BONE or l2 < MIN_BONE:
		return false
	var parent: Node3D = upper.get_parent() as Node3D
	var res: Dictionary = solve(parent.global_transform.basis, upper.global_position, l1, l2, target_world, is_leg)
	var q_fk: Quaternion = upper.basis.orthonormalized().get_rotation_quaternion()
	var q_ik: Quaternion = (res["basis"] as Basis).get_rotation_quaternion()
	upper.basis = Basis(q_fk.slerp(q_ik, clampf(weight, 0.0, 1.0)))
	lower.rotation = lower.rotation.lerp(Vector3(float(res["flex"]), 0.0, 0.0), clampf(weight, 0.0, 1.0))
	return true


## Bám chân: hạ/nâng bàn chân theo độ cao mặt đất dưới nó (chỉ khi chân đang ở pha chạm đất), hạ hông theo chân thấp nhất.
## `owner_y`: độ cao sàn phẳng của chủ nhân (gốc hình nhân ở chân). Trên sàn phẳng gần như không làm gì (không đổi hoạt ảnh chạy).
func plant_feet(m: Node3D, delta: float, owner_y: float) -> void:
	if not enabled_feet or not m.is_inside_tree():
		return
	var hips: Node3D = m.get_joint("hips")
	if (m.get_joint("knee_l") as Node3D).position.length() < MIN_BONE:
		return # khớp không có độ dài xương: giữ FK
	var space: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var targets: Array = []
	var want: Array = [0.0, 0.0]
	var sides: Array = ["l", "r"]
	for i in 2:
		var ankle: Node3D = m.get_joint("ankle_" + sides[i])
		var a: Vector3 = ankle.global_position
		var q := PhysicsRayQueryParameters3D.create(Vector3(a.x, owner_y + 0.7, a.z), Vector3(a.x, owner_y - 0.7, a.z), Global.L_WORLD)
		var hit: Dictionary = space.intersect_ray(q)
		var ground: float = (hit["position"] as Vector3).y if not hit.is_empty() else owner_y
		var stance: float = 1.0 - clampf((a.y - owner_y - 0.1) / 0.15, 0.0, 1.0)   # chân gần sàn phẳng = pha chạm đất
		want[i] = clampf(ground - owner_y, -0.4, 0.45) * stance
		targets.append(a)
	var k: float = 1.0 - exp(-delta * 20.0)
	for i in 2:
		foot_off[i] = lerpf(float(foot_off[i]), float(want[i]), k)
	var hip_want: float = minf(minf(float(foot_off[0]), float(foot_off[1])), 0.0)
	hip_off = lerpf(hip_off, hip_want, 1.0 - exp(-delta * 12.0))
	var active: float = clampf(maxf(absf(float(foot_off[0])), maxf(absf(float(foot_off[1])), absf(hip_off))) / 0.02, 0.0, 1.0)
	if active <= 0.0:
		return
	hips.position.y += hip_off
	for i in 2:
		var t: Vector3 = (targets[i] as Vector3) + Vector3(0.0, float(foot_off[i]), 0.0)
		apply_limb(m.get_joint("hip_" + sides[i]), m.get_joint("knee_" + sides[i]), m.get_joint("ankle_" + sides[i]), t, true, active)


## Quay đầu (và một phần thân) nhìn mục tiêu, có giới hạn góc, mượt theo thời gian. `weight` 0..1 (0 khi chết/choáng).
func apply_look(m: Node3D, delta: float, weight: float) -> void:
	var head: Node3D = m.get_joint("head")
	var spine: Node3D = m.get_joint("spine")
	var want_yaw: float = 0.0
	var want_pitch: float = 0.0
	var w: float = weight if look_target != null else 0.0
	if look_target != null:
		var local: Vector3 = head.get_parent().global_transform.basis.orthonormalized().inverse() * ((look_target as Vector3) - head.global_position)
		var flat: float = Vector2(local.x, local.z).length()
		want_yaw = clampf(atan2(-local.x, -local.z), -deg_to_rad(Global.ta("look_max_yaw")), deg_to_rad(Global.ta("look_max_yaw")))
		want_pitch = clampf(atan2(local.y, flat), -deg_to_rad(Global.ta("look_max_pitch")), deg_to_rad(Global.ta("look_max_pitch")))
	var k: float = 1.0 - exp(-delta * float(Global.ta("look_rate")))
	look_w = lerpf(look_w, w, k)
	look_yaw = lerpf(look_yaw, want_yaw, k)
	look_pitch = lerpf(look_pitch, want_pitch, k)
	if look_w < 0.001:
		return
	spine.rotation.y += look_yaw * 0.3 * look_w
	head.rotation.y += look_yaw * 0.7 * look_w
	head.rotation.x += look_pitch * look_w   # +x của đầu = cúi? Xem test: ngẩng khi mục tiêu cao hơn


## Tay trái đỡ phần trước của súng (hai tay cầm). `grip_world`: điểm cần chạm (tâm lòng bàn tay), weight 0..1.
func apply_support_hand(m: Node3D, grip_world: Vector3, weight: float) -> bool:
	var hand: Node3D = m.get_joint("hand_l")
	var elbow: Node3D = m.get_joint("elbow_l")
	var shoulder: Node3D = m.get_joint("shoulder_l")
	if hand == null:
		return false
	# Tâm lòng bàn tay nằm dưới khớp cổ tay một đoạn: trừ ra để cổ tay (đầu cẳng tay) tới đúng chỗ.
	var palm: Vector3 = elbow.global_transform.basis.orthonormalized() * Vector3(0.0, -0.06, 0.0)
	return apply_limb(shoulder, elbow, hand, grip_world - palm, false, weight)
