extends SceneTree
## M32: clip hoạt ảnh CC0 (Quaternius Universal Animation Library) cho người que glTF.
##   timeout 250 godot --headless --path . -s tools/tests/test_m32.gd

const DT: float = 1.0 / 60.0
const NEEDED: Array = ["Idle", "Sword_Idle", "Pistol_Idle", "Jog_Fwd", "Walk", "Sprint", "Crouch_Idle"]
var failures: int = 0
var L


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _mq(kind: String, clips: bool) -> Node3D:
	var m = load("res://scripts/mannequin_gltf.gd").new()
	m.kind = kind
	root.add_child(m)
	await process_frame
	m.animator.clips_enabled = clips
	return m


func _deg(m: Node3D, j: String) -> Vector3:
	return (m.get_joint(j) as Node3D).rotation_degrees


func _run() -> void:
	await process_frame
	var G: Node = root.get_node("Global")
	G.reduced_fx = false
	L = load("res://scripts/clip_lib.gd")

	print("[asset và giấy phép]")
	_check(FileAccess.file_exists("res://assets/animations/ual/UAL1_Standard.glb"), "có UAL1_Standard.glb")
	var lic: String = FileAccess.get_file_as_string("res://assets/animations/ual/LICENSE.txt")
	_check(lic.contains("CC0"), "LICENSE.txt ghi CC0")
	var docs: String = FileAccess.get_file_as_string("res://docs/ASSETS.md")
	_check(docs.contains("Universal Animation Library") and docs.contains("CC0"), "docs/ASSETS.md ghi nguồn + giấy phép")
	var t0: int = Time.get_ticks_usec()
	_check(L.available(), "thư viện clip nạp được")
	var load_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	_check(load_ms < 200.0, "nạp thư viện %.0f ms" % load_ms)
	var names: Array = L.clip_names()
	_check(names.size() >= 40, "%d clip trong thư viện" % names.size())
	for n in NEEDED:
		_check(names.has(n), "có clip %s" % n)

	print("[bake: quy ước khớp đúng, liên tục]")
	t0 = Time.get_ticks_usec()
	var jog: Dictionary = L.get_clip("Jog_Fwd")
	var bake_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	_check(not jog.is_empty() and bake_ms < 30.0, "bake Jog_Fwd %.1f ms, %d khung" % [bake_ms, int(jog.get("n", 0))])
	var hip_min: float = 999.0
	var hip_max: float = -999.0
	var knee_max: float = -999.0
	var knee_min: float = 999.0
	var maxstep: float = 0.0
	var prev: Dictionary = {}
	var finite: bool = true
	for i in int(jog["n"]) + 1:
		var s: Dictionary = L.sample(jog, float(i) / L.FPS)
		var hl: Vector3 = Basis(s["rot"]["hip_l"] as Quaternion).get_euler() * 57.29578
		var kl: Vector3 = Basis(s["rot"]["knee_l"] as Quaternion).get_euler() * 57.29578
		hip_min = minf(hip_min, hl.x)
		hip_max = maxf(hip_max, hl.x)
		knee_max = maxf(knee_max, kl.x)
		knee_min = minf(knee_min, kl.x)
		finite = finite and is_finite(hl.x) and is_finite(s["hips_y"])
		for j in L.JOINTS:
			if prev.has(j):
				maxstep = maxf(maxstep, rad_to_deg((prev[j] as Quaternion).angle_to(s["rot"][j] as Quaternion)))
			prev[j] = s["rot"][j]
	_check(finite, "giá trị hữu hạn")
	_check(hip_max > 15.0 and hip_min < -15.0, "chạy: hông vung cả hai chiều (%.0f..%.0f độ)" % [hip_min, hip_max])
	_check(knee_max < 5.0 and knee_min < -40.0, "gối chỉ gập ra sau, theo quy ước rig (%.0f..%.0f độ)" % [knee_min, knee_max])
	_check(maxstep < 75.0, "bước lớn nhất (chân chạy nhanh, không lật dấu/đứt) giữa 2 khung bake %.1f độ (liên tục, kể cả chỗ lặp)" % maxstep)
	var crouch: Dictionary = L.sample(L.get_clip("Crouch_Idle"), 0.5)
	var stand: Dictionary = L.sample(L.get_clip("Pistol_Idle"), 0.5)
	_check(float(crouch["hips_y"]) < float(stand["hips_y"]) - 0.25, "núp hạ hông (%.2f so với đứng %.2f chiều cao)" % [crouch["hips_y"], stand["hips_y"]])

	print("[animator: lớp clip đổi chân/thân, tay do code]")
	var a = await _mq("swordsman", true)
	var b = await _mq("swordsman", false)
	var arm_diff: float = 0.0
	var leg_diff: float = 0.0
	for i in 90:
		a.animate(DT, 4.8, true, 0.0)
		b.animate(DT, 4.8, true, 0.0)
		if i > 40:
			arm_diff = maxf(arm_diff, _maxc(((_deg(a, "shoulder_l") - _deg(b, "shoulder_l"))).abs()))
			leg_diff = maxf(leg_diff, _maxc(((_deg(a, "hip_l") - _deg(b, "hip_l"))).abs()))
	_check(leg_diff > 8.0, "chân chạy khác bản toàn code (lệch lớn nhất %.1f độ)" % leg_diff)
	_check(arm_diff < 0.5, "tay giữ nguyên do code (lệch %.2f độ)" % arm_diff)
	_check(a.animator._clip_name == "Jog_Fwd", "tốc độ 4.8 m/s -> clip Jog_Fwd (%s)" % a.animator._clip_name)
	for i in 30:
		a.animate(DT, 1.5, true, 0.0)
	_check(a.animator._clip_name == "Walk", "1.5 m/s -> Walk (%s)" % a.animator._clip_name)
	for i in 30:
		a.animate(DT, 8.0, true, 0.0)
	_check(a.animator._clip_name == "Sprint", "8 m/s -> Sprint (%s)" % a.animator._clip_name)
	for i in 60:
		a.animate(DT, 0.0, true, 0.0)
	_check(a.animator._clip_name == "Sword_Idle", "kiếm đứng yên -> Sword_Idle")
	var g = await _mq("gunner", true)
	for i in 60:
		g.animate(DT, 0.0, true, 0.0)
	_check(g.animator._clip_name == "Pistol_Idle", "xạ thủ đứng yên -> Pistol_Idle")
	for i in 60:
		g.animate(DT, 0.0, true, 0.0, "cover")
	_check(g.animator._clip_name == "Crouch_Idle", "núp -> Crouch_Idle")

	print("[tắt được; tay theo clip khi tăng ac_arm]")
	G.tune["a.ac_enabled"] = 0.0
	var c1 = await _mq("swordsman", true)
	var c2 = await _mq("swordsman", false)
	var d_off: float = 0.0
	for i in 90:
		c1.animate(DT, 4.8, true, 0.0)
		c2.animate(DT, 4.8, true, 0.0)
		d_off = maxf(d_off, _maxc(((_deg(c1, "hip_l") - _deg(c2, "hip_l"))).abs()))
	_check(d_off < 0.01, "ac_enabled = 0: giống hệt toàn code (lệch %.4f độ)" % d_off)
	G.tune["a.ac_enabled"] = 1.0
	G.tune["a.ac_arm"] = 0.6
	var e1 = await _mq("swordsman", true)
	var e2 = await _mq("swordsman", false)
	var d_arm: float = 0.0
	for i in 90:
		e1.animate(DT, 4.8, true, 0.0)
		e2.animate(DT, 4.8, true, 0.0)
		if i > 40:
			d_arm = maxf(d_arm, _maxc(((_deg(e1, "shoulder_l") - _deg(e2, "shoulder_l"))).abs()))
	_check(d_arm > 5.0, "ac_arm = 0.6: tay đánh theo clip (lệch %.1f độ)" % d_arm)
	G.tune.clear()

	print("[lùi/đi ngang: clip giảm trọng số, dáng do code]")
	var f1 = await _mq("swordsman", true)
	var f2 = await _mq("swordsman", true)
	f1.set_motion(Vector2(0, 1), 0.0)
	f2.set_motion(Vector2(0, -1), 0.0)
	for i in 60:
		f1.animate(DT, 4.8, true, 0.0)
		f2.animate(DT, 4.8, true, 0.0)
	_check(f1.animator._clip_w > 0.7 and f2.animator._clip_w < 0.1, "trọng số clip: tiến %.2f, lùi %.2f" % [f1.animator._clip_w, f2.animator._clip_w])

	print("[đòn đánh/parry vẫn do code: thời gian overlay không đổi]")
	var h1 = await _mq("swordsman", true)
	var h2 = await _mq("swordsman", false)
	h1.play("swing", 0.9, {"windup": 0.5, "active": 0.12, "recovery": 0.28})
	h2.play("swing", 0.9, {"windup": 0.5, "active": 0.12, "recovery": 0.28})
	var arm_sw: float = 0.0
	for i in 54:
		h1.animate(DT, 0.0, true, 0.0)
		h2.animate(DT, 0.0, true, 0.0)
		arm_sw = maxf(arm_sw, _maxc(((_deg(h1, "shoulder_r") - _deg(h2, "shoulder_r"))).abs()))
	_check(arm_sw < 0.5, "tay vung kiếm giống hệt (lệch %.2f độ)" % arm_sw)
	_check(h1.animator.overlay.is_empty() == h2.animator.overlay.is_empty(), "overlay swing chạy cùng nhịp")

	print("[chuyển trạng thái ngẫu nhiên: mượt, hữu hạn, không rò node]")
	var r = await _mq("swordsman", true)
	await process_frame
	var nodes0: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var rng := RandomNumberGenerator.new()
	rng.seed = 32
	var states: Array = ["", "cover", "vault", "slide"]
	var cur: String = ""
	var worst: float = 0.0
	var prev_pose: Dictionary = {}
	var fin: bool = true
	for fr in 1800:
		if rng.randi() % 40 == 0:
			cur = states[rng.randi() % states.size()]
		if rng.randi() % 30 == 0:
			r.set_motion(Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)), rng.randf_range(-300, 300))
		if rng.randi() % 90 == 0:
			r.play(["swing", "shoot", "hurt"][rng.randi() % 3], 0.4, {"windup": 0.2, "active": 0.1, "recovery": 0.2})
		r.animate(DT, [0.0, 1.5, 4.8, 8.0][rng.randi() % 4] if rng.randi() % 20 == 0 else r.animator._prev_speed, rng.randf() > 0.1, 0.0, cur)
		for j in ["hips", "spine", "hip_l", "knee_l", "hip_r", "knee_r"]:
			var v: Vector3 = _deg(r, j)
			fin = fin and is_finite(v.x) and is_finite(v.y) and is_finite(v.z)
			if prev_pose.has(j):
				var dd: Vector3 = v - prev_pose[j]
				worst = maxf(worst, maxf(absf(wrapf(dd.x, -180, 180)), maxf(absf(wrapf(dd.y, -180, 180)), absf(wrapf(dd.z, -180, 180)))))
			prev_pose[j] = v
	_check(fin, "1800 khung ngẫu nhiên: hữu hạn")
	_check(worst < 40.0, "khớp nhảy tối đa %.1f độ mỗi khung (đổi clip trộn chéo, không giật)" % worst)
	_check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == nodes0, "không rò node")

	print("[thiếu asset: tự chạy toàn code; rig khối không dùng clip]")
	L._failed = true
	var z = await _mq("swordsman", L.available())
	_check(not z.animator.clips_enabled, "không có thư viện: clips_enabled = false")
	for i in 30:
		z.animate(DT, 4.8, true, 0.0)
	_check(z.animator._clip_name == "" and is_finite(_deg(z, "hip_l").x), "chạy bình thường bằng code")
	L._failed = false
	var blk = load("res://scripts/mannequin.gd").new()
	root.add_child(blk)
	await process_frame
	_check(not blk.animator.clips_enabled, "rig khối (người chơi/Titan/dummy) không bật clip")

	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)


func _maxc(v: Vector3) -> float:
	return maxf(v.x, maxf(v.y, v.z))
