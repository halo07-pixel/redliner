extends RefCounted
## Hoạt ảnh thân cho Mannequin: chỉ nhận đầu vào (tốc độ, đứng đất, vận tốc đứng, tên trạng thái)
## và xoay các khớp. Không chứa logic game. Chủ nhân (bot/player) gọi `update()` mỗi frame vật lý.
## Tư thế là hàm thuần `target_pose()` (dễ test); `update()` chỉ pha trộn mượt về tư thế đó.

const STATES: Array = ["idle", "run", "air", "slide", "dash", "wallrun", "grapple"]

var mannequin: Node3D
var anim_state: String = "idle"
var phase: float = 0.0
var _t: float = 0.0
var _hips_base_y: float = 0.0


func setup(p_mannequin: Node3D) -> void:
	mannequin = p_mannequin
	_hips_base_y = mannequin.get_joint("hips").position.y


## Chọn trạng thái hoạt ảnh. state_name: "" (bình thường) | "slide" | "dash" | "wallrun" | "grapple".
static func pick_state(speed: float, grounded: bool, state_name: String) -> String:
	if state_name in ["slide", "dash", "wallrun", "grapple"]:
		return state_name
	if not grounded:
		return "air"
	if speed > float(Global.ANIM["run_min_speed"]):
		return "run"
	return "idle"


## Tư thế đích: {tên khớp: Vector3 độ, "hips_y": offset}. Khớp không có trong dict = 0.
func target_pose(st: String, p_phase: float, speed: float, vel_y: float, side: float, t: float) -> Dictionary:
	var A: Dictionary = Global.ANIM
	var pose: Dictionary = {}
	var swing: float = sin(p_phase)
	var lean: float = -minf(speed * float(A["lean_per_speed"]), float(A["lean_max"]))
	match st:
		"idle":
			pose["spine"] = Vector3(sin(t * 1.6) * 1.2, 0.0, 0.0)
			pose["shoulder_l"] = Vector3(0.0, 0.0, -4.0)
			pose["shoulder_r"] = Vector3(0.0, 0.0, 4.0)
		"run", "wallrun":
			var k: float = 1.0 if st == "run" else 1.15
			var ls: float = float(A["leg_swing"]) * k
			pose["spine"] = Vector3(lean, 0.0, side * 14.0 if st == "wallrun" else 0.0)
			pose["hip_l"] = Vector3(ls * swing, 0.0, 0.0)
			pose["hip_r"] = Vector3(-ls * swing, 0.0, 0.0)
			pose["knee_l"] = Vector3(-float(A["knee_bend"]) * (0.5 - 0.5 * cos(p_phase + 1.0)) * k, 0.0, 0.0)
			pose["knee_r"] = Vector3(-float(A["knee_bend"]) * (0.5 - 0.5 * cos(p_phase + 1.0 + PI)) * k, 0.0, 0.0)
			pose["shoulder_l"] = Vector3(-float(A["arm_swing"]) * swing, 0.0, -5.0)
			pose["elbow_l"] = Vector3(40.0, 0.0, 0.0)
			pose["head"] = Vector3(-lean * 0.5, 0.0, 0.0)
			if st == "wallrun":
				pose["shoulder_" + ("r" if side > 0.0 else "l")] = Vector3(-30.0, 0.0, side * 70.0)
		"air":
			var falling: bool = vel_y < -1.0
			pose["spine"] = Vector3(-4.0, 0.0, 0.0)
			pose["hip_l"] = Vector3(35.0, 0.0, 0.0)
			pose["knee_l"] = Vector3(-55.0, 0.0, 0.0)
			pose["hip_r"] = Vector3(-12.0, 0.0, 0.0)
			pose["knee_r"] = Vector3(-25.0, 0.0, 0.0)
			pose["shoulder_l"] = Vector3(0.0, 0.0, -65.0 if falling else -35.0)
			pose["elbow_l"] = Vector3(25.0, 0.0, 0.0)
		"slide":
			pose["hips_y"] = Vector3(-float(A["slide_drop"]), 0.0, 0.0)
			pose["spine"] = Vector3(-25.0, 0.0, 0.0)
			pose["hip_l"] = Vector3(80.0, 0.0, 0.0)
			pose["knee_l"] = Vector3(-8.0, 0.0, 0.0)
			pose["hip_r"] = Vector3(25.0, 0.0, 0.0)
			pose["knee_r"] = Vector3(-95.0, 0.0, 0.0)
			pose["shoulder_l"] = Vector3(-35.0, 0.0, -15.0)
			pose["head"] = Vector3(15.0, 0.0, 0.0)
		"dash":
			pose["spine"] = Vector3(-38.0, 0.0, 0.0)
			pose["hip_l"] = Vector3(55.0, 0.0, 0.0)
			pose["knee_l"] = Vector3(-30.0, 0.0, 0.0)
			pose["hip_r"] = Vector3(-40.0, 0.0, 0.0)
			pose["knee_r"] = Vector3(-60.0, 0.0, 0.0)
			pose["shoulder_l"] = Vector3(-55.0, 0.0, -10.0)
			pose["head"] = Vector3(25.0, 0.0, 0.0)
		"grapple":
			pose["spine"] = Vector3(-8.0, 0.0, 0.0)
			pose["shoulder_r"] = Vector3(160.0, 0.0, 0.0)
			pose["elbow_r"] = Vector3(10.0, 0.0, 0.0)
			pose["shoulder_l"] = Vector3(10.0, 0.0, -25.0)
			pose["hip_l"] = Vector3(12.0, 0.0, 0.0)
			pose["knee_l"] = Vector3(-35.0, 0.0, 0.0)
			pose["hip_r"] = Vector3(-8.0, 0.0, 0.0)
			pose["knee_r"] = Vector3(-20.0, 0.0, 0.0)
	_hold_weapon_arm(pose, st)
	return pose


## Tay cầm vũ khí giữ tư thế cầm (không vung theo nhịp chạy), trừ khi đang đu móc.
func _hold_weapon_arm(pose: Dictionary, st: String) -> void:
	if mannequin.weapon == null or st == "grapple":
		return
	if mannequin.kind == "gunner":
		pose["shoulder_r"] = Vector3(-70.0, 0.0, 0.0)
		pose["elbow_r"] = Vector3(10.0, 0.0, 0.0)
	else:
		pose["shoulder_r"] = Vector3(-15.0, 0.0, 6.0)
		pose["elbow_r"] = Vector3(60.0, 0.0, 0.0)


## Gọi mỗi frame vật lý. side: +1 tường bên phải (cùng quy ước player._wall_side), -1 bên trái (chỉ dùng khi wallrun).
func update(delta: float, speed: float, grounded: bool, vel_y: float, state_name: String = "", side: float = 1.0) -> void:
	_t += delta
	anim_state = pick_state(speed, grounded, state_name)
	if anim_state == "run" or anim_state == "wallrun":
		phase = fmod(phase + speed * delta * float(Global.ANIM["stride_rate"]), TAU)
	var pose: Dictionary = target_pose(anim_state, phase, speed, vel_y, side, _t)
	var f: float = 1.0 - exp(-float(Global.ANIM["blend"]) * delta)
	for jn in mannequin.JOINT_NAMES:
		var j: Node3D = mannequin.get_joint(jn)
		var tgt: Vector3 = pose.get(jn, Vector3.ZERO)
		j.rotation_degrees = j.rotation_degrees.lerp(tgt, f)
	var hips: Node3D = mannequin.get_joint("hips")
	var dy: float = (pose["hips_y"] as Vector3).x if pose.has("hips_y") else 0.0
	hips.position.y = lerpf(hips.position.y, _hips_base_y + dy, f)
