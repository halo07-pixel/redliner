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
# Overlay chiến đấu: {name, t, dur, data, prio, hold}. Chỉ điều khiển một số khớp, còn lại giữ hoạt ảnh nền.
var overlay: Dictionary = {}

const OVERLAY_PRIO: Dictionary = {"swing": 1, "shoot": 1, "parry": 1, "parry_miss": 1, "hurt": 1, "stagger": 2, "die": 3}


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


## Bắt đầu overlay chiến đấu. Overlay ưu tiên thấp không ngắt overlay ưu tiên cao đang chạy
## (die > stagger > còn lại). "die" giữ tư thế cuối (nằm). data: {windup, active, recovery} cho "swing";
## {direction: Vector3 hướng đòn theo hệ tọa độ cục bộ của hình nhân} cho "hurt".
func play(name: String, dur: float, data: Dictionary = {}) -> void:
	if not OVERLAY_PRIO.has(name):
		push_error("Overlay không tồn tại: " + name)
		return
	if not overlay.is_empty() and int(OVERLAY_PRIO[overlay["name"]]) > int(OVERLAY_PRIO[name]) and _overlay_live():
		return
	overlay = {"name": name, "t": 0.0, "dur": maxf(dur, 0.01), "data": data, "hold": name == "die"}


func clear_overlay() -> void:
	overlay = {}


func _overlay_live() -> bool:
	return not overlay.is_empty() and (overlay["hold"] or float(overlay["t"]) < float(overlay["dur"]))


## Trọng số 0..1 của overlay: vào nhanh, ra mượt (trừ overlay giữ tư thế cuối).
func overlay_weight() -> float:
	if overlay.is_empty():
		return 0.0
	var t: float = overlay["t"]
	var dur: float = overlay["dur"]
	var w: float = clampf(t / float(Global.ANIM["overlay_in"]), 0.0, 1.0)
	if not overlay["hold"]:
		w *= clampf((dur - t) / float(Global.ANIM["overlay_out"]), 0.0, 1.0)
	return w


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Tư thế của overlay tại thời điểm t (hàm thuần, dễ test): {khớp: Vector3 độ, "hips_y": Vector3(x=offset m)}.
func overlay_pose(name: String, t: float, dur: float, data: Dictionary) -> Dictionary:
	var o: Dictionary = {}
	var p: float = clampf(t / dur, 0.0, 1.0)
	match name:
		"swing":
			var wu: float = float(data.get("windup", 0.3))
			var ac: float = float(data.get("active", 0.12))
			var rc: float = float(data.get("recovery", 0.3))
			if t < wu:      # giơ kiếm lên, xoay thân về sau
				var k: float = _ease(t / maxf(wu, 0.001))
				o["shoulder_r"] = Vector3(lerpf(-15.0, 150.0, k), 0.0, 0.0)
				o["elbow_r"] = Vector3(lerpf(60.0, 80.0, k), 0.0, 0.0)
				o["spine"] = Vector3(lerpf(0.0, 8.0, k), lerpf(0.0, 28.0, k), 0.0)
			elif t < wu + ac: # chém xuống/ngang qua người
				var k2: float = _ease((t - wu) / maxf(ac, 0.001))
				o["shoulder_r"] = Vector3(lerpf(150.0, -20.0, k2), 0.0, 0.0)
				o["elbow_r"] = Vector3(lerpf(80.0, 20.0, k2), 0.0, 0.0)
				o["spine"] = Vector3(lerpf(8.0, -20.0, k2), lerpf(28.0, -38.0, k2), 0.0)
			else:           # thu về
				var k3: float = _ease((t - wu - ac) / maxf(rc, 0.001))
				o["shoulder_r"] = Vector3(lerpf(-20.0, -15.0, k3), 0.0, 0.0)
				o["elbow_r"] = Vector3(lerpf(20.0, 60.0, k3), 0.0, 0.0)
				o["spine"] = Vector3(lerpf(-20.0, 0.0, k3), lerpf(-38.0, 0.0, k3), 0.0)
		"shoot":
			var kick: float = (1.0 - p) * (1.0 - p)
			o["shoulder_r"] = Vector3(-70.0 + 16.0 * kick, 0.0, 0.0)
			o["elbow_r"] = Vector3(10.0 + 20.0 * kick, 0.0, 0.0)
			o["spine"] = Vector3(7.0 * kick, 0.0, 0.0)
		"parry":    # kiếm chắn ngang trước ngực
			o["shoulder_r"] = Vector3(-60.0, 0.0, -25.0)
			o["elbow_r"] = Vector3(110.0, 0.0, 0.0)
			o["spine"] = Vector3(-4.0, 22.0, 0.0)
		"parry_miss": # loạng choạng ngắn
			var e: float = sin(PI * p)
			o["spine"] = Vector3(16.0 * e, 0.0, sin(t * 14.0) * 4.0 * (1.0 - p))
			o["head"] = Vector3(12.0 * e, 0.0, 0.0)
			o["shoulder_r"] = Vector3(10.0, 0.0, 15.0 * e)
		"hurt":     # giật người theo hướng đòn tới
			var env: float = sin(PI * clampf(p, 0.0, 1.0))
			var d: Vector3 = data.get("direction", Vector3(0.0, 0.0, 1.0))
			o["spine"] = Vector3(22.0 * env * signf(d.z if absf(d.z) > 0.01 else 1.0), 0.0, -14.0 * env * clampf(d.x, -1.0, 1.0))
			o["head"] = Vector3(14.0 * env, 0.0, 0.0)
			o["shoulder_l"] = Vector3(-25.0 * env, 0.0, -20.0 * env)
		"stagger":  # choáng: cúi đầu, tay buông, lắc nhẹ
			o["spine"] = Vector3(-24.0, 0.0, sin(t * 9.0) * 5.0)
			o["head"] = Vector3(-28.0, 0.0, sin(t * 7.0) * 6.0)
			o["shoulder_l"] = Vector3(8.0, 0.0, -6.0)
			o["shoulder_r"] = Vector3(8.0, 0.0, 6.0)
			o["elbow_r"] = Vector3(10.0, 0.0, 0.0)
		"die":      # ngã ngửa ra sau, hông hạ xuống đất
			var k4: float = _ease(p)
			o["hips"] = Vector3(88.0 * k4, 0.0, 0.0)
			o["hips_y"] = Vector3(-0.72 * k4, 0.0, 0.0)
			o["spine"] = Vector3(-8.0 * k4, 0.0, 0.0)
			o["head"] = Vector3(-10.0 * k4, 0.0, 0.0)
			o["shoulder_l"] = Vector3(20.0 * k4, 0.0, -50.0 * k4)
			o["shoulder_r"] = Vector3(20.0 * k4, 0.0, 50.0 * k4)
			o["hip_l"] = Vector3(10.0 * k4, 0.0, -8.0 * k4)
			o["hip_r"] = Vector3(-5.0 * k4, 0.0, 8.0 * k4)
			o["knee_l"] = Vector3(-20.0 * k4, 0.0, 0.0)
			o["knee_r"] = Vector3(-35.0 * k4, 0.0, 0.0)
	return o


## Gọi mỗi frame vật lý. side: +1 tường bên phải (cùng quy ước player._wall_side), -1 bên trái (chỉ dùng khi wallrun).
func update(delta: float, speed: float, grounded: bool, vel_y: float, state_name: String = "", side: float = 1.0) -> void:
	_t += delta
	anim_state = pick_state(speed, grounded, state_name)
	if anim_state == "run" or anim_state == "wallrun":
		phase = fmod(phase + speed * delta * float(Global.ANIM["stride_rate"]), TAU)
	var pose: Dictionary = target_pose(anim_state, phase, speed, vel_y, side, _t)
	if not overlay.is_empty():
		overlay["t"] = float(overlay["t"]) + delta
		if not overlay["hold"] and float(overlay["t"]) >= float(overlay["dur"]):
			overlay = {}
		else:
			var w: float = overlay_weight()
			var op: Dictionary = overlay_pose(overlay["name"], overlay["t"], overlay["dur"], overlay["data"])
			for key in op:
				var base: Vector3 = pose.get(key, Vector3.ZERO)
				pose[key] = base.lerp(op[key], w)
	var f: float = 1.0 - exp(-float(Global.ANIM["blend"]) * delta)
	for jn in mannequin.JOINT_NAMES:
		var j: Node3D = mannequin.get_joint(jn)
		var tgt: Vector3 = pose.get(jn, Vector3.ZERO)
		j.rotation_degrees = j.rotation_degrees.lerp(tgt, f)
	var hips: Node3D = mannequin.get_joint("hips")
	var dy: float = (pose["hips_y"] as Vector3).x if pose.has("hips_y") else 0.0
	hips.position.y = lerpf(hips.position.y, _hips_base_y + dy, f)
