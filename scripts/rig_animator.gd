extends RefCounted
## Hoạt ảnh thân cho Mannequin: chỉ nhận đầu vào (tốc độ, đứng đất, vận tốc đứng, tên trạng thái)
## và xoay các khớp. Không chứa logic game. Chủ nhân (bot/player) gọi `update()` mỗi frame vật lý.
## Tư thế là hàm thuần `target_pose()` (dễ test); `update()` chỉ pha trộn mượt về tư thế đó.

const RigIK = preload("res://scripts/rig_ik.gd")
const STATES: Array = ["idle", "run", "air", "slide", "dash", "wallrun", "grapple"]

var mannequin: Node3D
var anim_state: String = "idle"
var phase: float = 0.0
var _t: float = 0.0
var _hips_base_y: float = 0.0
var _rot: Dictionary = {}    # khớp -> góc hiện tại (độ), do lò xo điều khiển
var _vel: Dictionary = {}
var _hy: float = 0.0         # độ lệch hông theo Y, Z (m) và vận tốc lò xo
var _hyv: float = 0.0
var _hz: float = 0.0
var _hzv: float = 0.0
# Overlay chiến đấu: {name, t, dur, data, prio, hold}. Chỉ điều khiển một số khớp, còn lại giữ hoạt ảnh nền.
var overlay: Dictionary = {}
var ik := RigIK.new()   # bám chân, nhìn mục tiêu, tay phụ (M20)

const OVERLAY_PRIO: Dictionary = {"swing": 1, "shoot": 1, "parry": 1, "parry_miss": 1, "parry_hit": 1, "hurt": 1, "stagger": 2, "clash": 2, "die": 3}


func setup(p_mannequin: Node3D) -> void:
	mannequin = p_mannequin
	_hips_base_y = mannequin.get_joint("hips").position.y
	for jn in mannequin.JOINT_NAMES:
		_rot[jn] = mannequin.get_joint(jn).rotation_degrees
		_vel[jn] = Vector3.ZERO


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
			var look: float = float(A["idle_look"]) * sin(t * 0.37) * maxf(0.0, sin(t * 0.9)) # thỉnh thoảng quay đầu nhìn quanh
			pose["spine"] = Vector3(sin(t * 1.6) * 1.2, 0.0, 0.0)                         # thở
			pose["hips"] = Vector3(0.0, 0.0, sin(t * 0.6) * 2.2)                           # đổi trọng tâm
			pose["hip_l"] = Vector3(sin(t * 0.6) * 2.5, 0.0, 0.0)
			pose["hip_r"] = Vector3(-sin(t * 0.6) * 2.5, 0.0, 0.0)
			pose["head"] = Vector3(0.0, look, 0.0)
			pose["shoulder_l"] = Vector3(0.0, 0.0, -4.0 + sin(t * 1.6) * 0.8)
			pose["shoulder_r"] = Vector3(0.0, 0.0, 4.0 - sin(t * 1.6) * 0.8)
		"run", "wallrun":
			var k: float = 1.0 if st == "run" else 1.15
			var ls: float = float(A["leg_swing"]) * k
			var hip_y: float = -float(A["hip_twist"]) * swing                             # hông xoay: chân trái tiến -> hông trái tiến
			var sp_y: float = float(A["spine_twist"]) * swing                              # vai xoay ngược hông
			pose["hips"] = Vector3(0.0, hip_y, 0.0)
			pose["spine"] = Vector3(lean, sp_y, side * 14.0 if st == "wallrun" else 0.0)
			pose["hips_y"] = Vector3(-float(A["hip_bob"]) * (0.5 + 0.5 * cos(2.0 * p_phase)), 0.0, 0.0)  # nhún theo từng bước
			pose["hip_l"] = Vector3(ls * swing, 0.0, 0.0)
			pose["hip_r"] = Vector3(-ls * swing, 0.0, 0.0)
			pose["knee_l"] = Vector3(-float(A["knee_bend"]) * (0.5 - 0.5 * cos(p_phase + 1.0)) * k, 0.0, 0.0)
			pose["knee_r"] = Vector3(-float(A["knee_bend"]) * (0.5 - 0.5 * cos(p_phase + 1.0 + PI)) * k, 0.0, 0.0)
			pose["ankle_l"] = Vector3(15.0 * maxf(0.0, swing) - 20.0 * maxf(0.0, -swing), 0.0, 0.0)   # gót chạm rồi đẩy mũi chân
			pose["ankle_r"] = Vector3(15.0 * maxf(0.0, -swing) - 20.0 * maxf(0.0, swing), 0.0, 0.0)
			pose["shoulder_l"] = Vector3(-float(A["arm_swing"]) * swing, 0.0, -5.0)
			pose["elbow_l"] = Vector3(45.0 + 15.0 * sin(p_phase + 0.6), 0.0, 0.0)
			pose["head"] = Vector3(-lean * 0.5, -(sp_y + hip_y), 0.0)                       # đầu giữ hướng nhìn
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
	if mannequin.kind == "gunner" or mannequin.kind == "bomber":
		pose["shoulder_r"] = Vector3(70.0, 0.0, 0.0)
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
	var w: float = _ease(t / float(Global.ta("overlay_in")))
	if not overlay["hold"]:
		w *= _ease((dur - t) / float(Global.ta("overlay_out")))
	return w


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Vào chậm rồi tăng tốc mạnh (đòn chém: dồn lực rồi bật ra).
static func _ease_in(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x


## Bật nhanh rồi giảm tốc (windup, đỡ đòn).
static func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


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
				var k: float = _ease_out(t / maxf(wu, 0.001))
				o["shoulder_r"] = Vector3(lerpf(-15.0, 150.0, k), 0.0, 0.0)
				o["elbow_r"] = Vector3(lerpf(60.0, 80.0, k), 0.0, 0.0)
				o["spine"] = Vector3(lerpf(0.0, 8.0, k), lerpf(0.0, 28.0, k), 0.0)
				o["+hips_y"] = Vector3(-float(Global.ANIM["anticip_drop"]) * k, 0.0, 0.0)           # hạ người dồn lực
				o["+hip_l"] = Vector3(22.0 * k, 0.0, 0.0)
				o["+knee_l"] = Vector3(-30.0 * k, 0.0, 0.0)
				o["+knee_r"] = Vector3(-22.0 * k, 0.0, 0.0)
			elif t < wu + ac: # chém xuống/ngang qua người
				var k2: float = _ease_in((t - wu) / maxf(ac, 0.001))
				o["shoulder_r"] = Vector3(lerpf(150.0, -20.0, k2), 0.0, 0.0)
				o["elbow_r"] = Vector3(lerpf(80.0, 20.0, k2), 0.0, 0.0)
				o["spine"] = Vector3(lerpf(8.0, -20.0, k2), lerpf(28.0, -38.0, k2), 0.0)
				o["+hips_y"] = Vector3(lerpf(-float(Global.ANIM["anticip_drop"]), -0.05, k2), 0.0, 0.0)
				o["hips_z"] = Vector3(-float(Global.ANIM["lunge"]) * k2, 0.0, 0.0)                  # lao tới khi chém
				o["+hip_l"] = Vector3(lerpf(22.0, 45.0, k2), 0.0, 0.0)
				o["+knee_l"] = Vector3(lerpf(-30.0, -20.0, k2), 0.0, 0.0)
				o["+knee_r"] = Vector3(lerpf(-22.0, -10.0, k2), 0.0, 0.0)
			else:           # thu về
				var k3: float = _ease((t - wu - ac) / maxf(rc, 0.001))
				var over: float = sin(PI * clampf((t - wu - ac) / maxf(rc, 0.001) * 1.6, 0.0, 1.0)) * (1.0 - k3)   # follow-through: quất quá đích rồi mới về
				o["shoulder_r"] = Vector3(lerpf(-20.0, -15.0, k3) - 16.0 * over, 0.0, 0.0)
				o["elbow_r"] = Vector3(lerpf(20.0, 60.0, k3) - 10.0 * over, 0.0, 0.0)
				o["spine"] = Vector3(lerpf(-20.0, 0.0, k3), lerpf(-38.0, 0.0, k3), 0.0)
				o["+hips_y"] = Vector3(lerpf(-0.05, 0.0, k3), 0.0, 0.0)
				o["hips_z"] = Vector3(-float(Global.ANIM["lunge"]) * (1.0 - k3), 0.0, 0.0)
				o["+hip_l"] = Vector3(lerpf(45.0, 0.0, k3), 0.0, 0.0)
				o["+knee_l"] = Vector3(lerpf(-20.0, 0.0, k3), 0.0, 0.0)
				o["+knee_r"] = Vector3(lerpf(-10.0, 0.0, k3), 0.0, 0.0)
		"shoot":
			var kick: float = (1.0 - p) * (1.0 - p)
			o["shoulder_r"] = Vector3(70.0 + 12.0 * kick, 0.0, 0.0)
			o["elbow_r"] = Vector3(10.0 + 20.0 * kick, 0.0, 0.0)
			o["spine"] = Vector3(7.0 * kick, 0.0, 0.0)
		"parry":    # kiếm chắn ngang trước ngực: bật nhanh (ease-out) rồi giữ
			var pk: float = _ease_out(t / 0.08)
			o["shoulder_r"] = Vector3(-60.0, 0.0, -25.0) * pk
			o["elbow_r"] = Vector3(110.0, 0.0, 0.0) * pk
			o["spine"] = Vector3(-4.0, 22.0, 0.0) * pk
		"parry_miss": # loạng choạng ngắn
			var e: float = sin(PI * p)
			var bounce: float = exp(-3.5 * p) * sin(p * TAU * 1.5)    # nảy đàn hồi tắt dần
			o["spine"] = Vector3(16.0 * e + 10.0 * bounce, 0.0, sin(t * 14.0) * 4.0 * (1.0 - p))
			o["head"] = Vector3(12.0 * e + 8.0 * bounce, 0.0, 0.0)
			o["shoulder_r"] = Vector3(10.0 + 14.0 * bounce, 0.0, 15.0 * e)
		"hurt":     # giật người theo hướng đòn tới
			var env: float = sin(PI * clampf(p, 0.0, 1.0))
			var d: Vector3 = data.get("direction", Vector3(0.0, 0.0, 1.0))
			var side: float = clampf(d.x, -1.0, 1.0)
			var recoil: float = env * (1.0 + 0.35 * sin(p * TAU * 1.5) * (1.0 - p))       # giật rồi dội nhẹ
			o["spine"] = Vector3(22.0 * recoil * signf(d.z if absf(d.z) > 0.01 else 1.0), -10.0 * env * side, -14.0 * env * side)
			o["hips"] = Vector3(0.0, 12.0 * env * side, 0.0)                              # hông xoay lệch theo hướng đòn
			o["head"] = Vector3(14.0 * env, 16.0 * env * side, 8.0 * env * side)           # đầu bật theo hướng đòn tới
			o["shoulder_l"] = Vector3(-25.0 * env, 0.0, -20.0 * env)
			o["shoulder_r"] = Vector3(-14.0 * env, 0.0, 12.0 * env * (1.0 + side))
			o["+knee_l"] = Vector3(-18.0 * env, 0.0, 0.0)                                         # khuỵu gối
			o["+knee_r"] = Vector3(-12.0 * env, 0.0, 0.0)
			o["+hips_y"] = Vector3(-0.06 * env, 0.0, 0.0)
			match String(data.get("zone", "torso")):
				"head":   # trúng đầu: đầu hất ra sau mạnh, thân ngửa
					o["head"] = Vector3(-34.0 * recoil, 16.0 * env * side, 8.0 * env * side)
					o["spine"] = Vector3(-12.0 * recoil, -10.0 * env * side, -14.0 * env * side)
				"legs":   # trúng chân: khuỵu gối sâu, hông hạ, thân cúi
					o["+knee_l"] = Vector3(-40.0 * env, 0.0, 0.0)
					o["+knee_r"] = Vector3(-32.0 * env, 0.0, 0.0)
					o["+hips_y"] = Vector3(-0.14 * env, 0.0, 0.0)
					o["spine"] = Vector3(-18.0 * recoil, -10.0 * env * side, -14.0 * env * side)
		"stagger":  # choáng: cúi đầu, tay buông, lắc nhẹ
			o["spine"] = Vector3(-24.0, 0.0, sin(t * 9.0) * 5.0)
			o["head"] = Vector3(-28.0, 0.0, sin(t * 7.0) * 6.0)
			var kb: float = exp(-t * 9.0)   # cú hất ban đầu: tay cầm kiếm bị đánh bật lên rồi buông xuống
			o["shoulder_l"] = Vector3(8.0, 0.0, -6.0)
			o["shoulder_r"] = Vector3(8.0 + 100.0 * kb, 0.0, 6.0)
			o["elbow_r"] = Vector3(10.0 + 50.0 * kb, 0.0, 0.0)
			o["hips_z"] = Vector3(0.1 * kb, 0.0, 0.0)
			o["+hips_y"] = Vector3(-0.05, 0.0, 0.0)
			o["+knee_l"] = Vector3(-16.0 + sin(t * 8.0) * 5.0, 0.0, 0.0)
			o["+knee_r"] = Vector3(-16.0 - sin(t * 8.0) * 5.0, 0.0, 0.0)
		"clash":    # hai kiếm chạm nhau: bị đẩy lùi theo hướng đẩy, kiếm bật lên, thân ngửa rồi lấy lại thăng bằng
			var d2: Vector3 = data.get("direction", Vector3(0.0, 0.0, 1.0))
			var kb2: float = exp(-t * 7.0)
			var env2: float = sin(PI * clampf(p, 0.0, 1.0)) * (1.0 - p * 0.3)
			o["hips_z"] = Vector3(0.14 * kb2 * signf(d2.z if absf(d2.z) > 0.01 else 1.0), 0.0, 0.0)
			o["spine"] = Vector3(16.0 * env2, -10.0 * clampf(d2.x, -1.0, 1.0) * env2, 0.0)
			o["head"] = Vector3(10.0 * env2, 0.0, 0.0)
			o["shoulder_r"] = Vector3(-15.0 + 125.0 * kb2, 0.0, 10.0 * kb2)
			o["elbow_r"] = Vector3(60.0 + 40.0 * kb2, 0.0, 0.0)
			o["shoulder_l"] = Vector3(-20.0 * env2, 0.0, -18.0 * env2)
			o["+knee_l"] = Vector3(-18.0 * env2, 0.0, 0.0)
			o["+knee_r"] = Vector3(-24.0 * env2, 0.0, 0.0)
			o["+hips_y"] = Vector3(-0.05 * env2, 0.0, 0.0)
		"parry_hit": # parry thành công: đẩy kiếm bật ra rồi thu về, thân lao nhẹ theo cú đẩy
			var snap: float = _ease_out(t / 0.07)
			var back: float = _ease(clampf((p - 0.35) / 0.65, 0.0, 1.0))
			o["shoulder_r"] = Vector3(lerpf(-60.0, 15.0, snap) * (1.0 - back) + -15.0 * back, 0.0, -25.0 * (1.0 - snap))
			o["elbow_r"] = Vector3(lerpf(110.0, 25.0, snap) * (1.0 - back) + 60.0 * back, 0.0, 0.0)
			o["spine"] = Vector3(-10.0 * snap * (1.0 - back), 14.0 * (1.0 - back), 0.0)
			o["hips_z"] = Vector3(-0.08 * snap * (1.0 - back), 0.0, 0.0)
		"die":      # ngã ngửa ra sau, hông hạ xuống đất
			var k4: float = _ease(p)
			o["hips"] = Vector3(88.0 * k4, 0.0, 0.0)
			o["hips_y"] = Vector3(-0.72 * k4 + 0.035 * sin(PI * clampf((p - 0.8) / 0.2, 0.0, 1.0)), 0.0, 0.0) # nảy nhẹ khi chạm đất
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
				var kk: String = key
				if kk.begins_with("+"): # cộng thêm lên hoạt ảnh nền (vd. hạ người khi chém nhưng chân vẫn chạy)
					kk = kk.substr(1)
					pose[kk] = pose.get(kk, Vector3.ZERO) + (op[key] as Vector3) * w
				else:
					pose[kk] = (pose.get(kk, Vector3.ZERO) as Vector3).lerp(op[key], w)
	# Lò xo cho từng khớp: chuyển tư thế có quán tính, đuổi theo tư thế đích và nảy nhẹ khi dừng.
	var k: float = float(Global.ta("joint_k"))
	var c: float = float(Global.ta("joint_c"))
	var n: int = maxi(1, ceili(delta / (1.0 / 120.0)))
	var h: float = delta / float(n)
	for jn in mannequin.JOINT_NAMES:
		var tgt: Vector3 = pose.get(jn, Vector3.ZERO)
		var x: Vector3 = _rot[jn]
		var v: Vector3 = _vel[jn]
		for i in n:
			v += ((tgt - x) * k - v * c) * h
			x += v * h
		_rot[jn] = x
		_vel[jn] = v
		mannequin.get_joint(jn).rotation_degrees = x
	var ty: float = (pose["hips_y"] as Vector3).x if pose.has("hips_y") else 0.0
	var tz: float = (pose["hips_z"] as Vector3).x if pose.has("hips_z") else 0.0
	for i in n:
		_hyv += ((ty - _hy) * k - _hyv * c) * h
		_hy += _hyv * h
		_hzv += ((tz - _hz) * k - _hzv * c) * h
		_hz += _hzv * h
	var hips: Node3D = mannequin.get_joint("hips")
	hips.position.y = _hips_base_y + _hy
	hips.position.z = _hz
	_apply_ik(delta)


## Lớp IK chạy sau FK: bám chân xuống sàn, nhìn mục tiêu, tay trái đỡ báng. Bị tắt/giảm khi chết, choáng, clash.
func _apply_ik(delta: float) -> void:
	var ov: String = overlay["name"] if not overlay.is_empty() else ""
	var calm: float = 1.0
	match ov:
		"die", "stagger", "clash":
			calm = 0.0
		"hurt":
			calm = 0.4
	ik.apply_look(mannequin, delta, calm)
	if mannequin.get("ik_feet") != false:
		ik.enabled_feet = ov != "die"
		ik.plant_feet(mannequin, delta, mannequin.global_position.y)
	if mannequin.weapon != null and (mannequin.kind == "gunner" or mannequin.kind == "bomber") and anim_state != "grapple":
		var grip: Vector3 = mannequin.support_grip()
		ik.support_w = lerpf(ik.support_w, float(Global.ta("support_hand")) * calm, 1.0 - exp(-delta * 10.0))
		ik.apply_support_hand(mannequin, grip, ik.support_w)


## Mục tiêu để đầu/thân quay nhìn (vị trí thế giới) hoặc null để thôi nhìn.
func set_look_target(p: Variant) -> void:
	ik.look_target = p
