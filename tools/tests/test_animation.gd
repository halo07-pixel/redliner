extends SceneTree
## Test headless M7.2: chọn trạng thái hoạt ảnh, tư thế từng trạng thái, nhịp chân theo tốc độ,
## pha trộn mượt, bot có animator, thân người chơi ẩn với camera của mình.
##   timeout 120 godot --headless --path . -s tools/tests/test_animation.gd

var failures: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _make(kind: String) -> Node3D:
	var m: Node3D = load("res://scripts/mannequin.gd").new()
	m.kind = kind
	root.add_child(m)
	return m


func _run() -> void:
	await process_frame
	var Anim = load("res://scripts/rig_animator.gd")
	var m: Node3D = _make("swordsman")
	await process_frame
	var an = m.animator

	# Chọn trạng thái
	_check(Anim.pick_state(0.0, true, "") == "idle", "đứng yên -> idle")
	_check(Anim.pick_state(6.0, true, "") == "run", "có tốc độ trên đất -> run")
	_check(Anim.pick_state(6.0, false, "") == "air", "trên không -> air")
	_check(Anim.pick_state(6.0, false, "slide") == "slide" and Anim.pick_state(6.0, true, "grapple") == "grapple", "trạng thái đặc biệt thắng air/run")
	for st in Anim.STATES:
		_check(an.target_pose(st, 0.5, 6.0, 0.0, 1.0, 0.0) is Dictionary, "tư thế '%s' tồn tại" % st)

	# Tư thế đặc trưng
	var run_a: Dictionary = an.target_pose("run", PI * 0.5, 7.0, 0.0, 1.0, 0.0)
	var run_b: Dictionary = an.target_pose("run", PI * 1.5, 7.0, 0.0, 1.0, 0.0)
	_check(run_a["hip_l"].x > 20.0 and run_a["hip_r"].x < -20.0, "chạy: hai chân đối nhau")
	_check(signf(run_a["hip_l"].x) != signf(run_b["hip_l"].x), "chạy: chân đổi bước theo pha")
	_check(run_a["shoulder_l"].x * run_a["hip_l"].x < 0.0, "chạy: tay trái ngược chân trái")
	_check(run_a["spine"].x < 0.0, "chạy: thân nghiêng về trước")
	var slide: Dictionary = an.target_pose("slide", 0.0, 8.0, 0.0, 1.0, 0.0)
	_check(slide["hips_y"].x < -0.2, "trượt: hạ hông")
	var grap: Dictionary = an.target_pose("grapple", 0.0, 8.0, 0.0, 1.0, 0.0)
	_check(grap["shoulder_r"].x > 120.0, "đu móc: tay phải giơ lên")
	var wall_r: Dictionary = an.target_pose("wallrun", 0.0, 8.0, 0.0, 1.0, 0.0)
	var wall_l: Dictionary = an.target_pose("wallrun", 0.0, 8.0, 0.0, -1.0, 0.0)
	_check(wall_r["spine"].z * wall_l["spine"].z < 0.0, "chạy tường: nghiêng ngược nhau theo bên tường")
	var air_up: Dictionary = an.target_pose("air", 0.0, 5.0, 4.0, 1.0, 0.0)
	var air_dn: Dictionary = an.target_pose("air", 0.0, 5.0, -6.0, 1.0, 0.0)
	_check(absf(air_dn["shoulder_l"].z) > absf(air_up["shoulder_l"].z), "rơi: dang tay rộng hơn lúc bay lên")
	var gun: Node3D = _make("gunner")
	await process_frame
	var gp: Dictionary = gun.animator.target_pose("run", 1.0, 5.0, 0.0, 1.0, 0.0)
	_check(gp["shoulder_r"].x < -60.0, "xạ thủ: giữ súng nhắm khi chạy")

	# Chu kỳ chạy khớp tốc độ: chạy nhanh -> pha tăng nhanh hơn
	var m2: Node3D = _make("swordsman")
	await process_frame
	m.animate(0.1, 3.0, true, 0.0)
	m2.animate(0.1, 9.0, true, 0.0)
	_check(m2.animator.phase > m.animator.phase * 2.5, "pha chạy tăng tỉ lệ với tốc độ")

	# Pha trộn mượt: đổi run -> slide, mỗi frame 1/60 góc khớp không nhảy quá 25 độ
	var m3: Node3D = _make("swordsman")
	await process_frame
	for i in 30:
		m3.animate(1.0 / 60.0, 8.0, true, 0.0)
	var maxstep: float = 0.0
	for i in 40:
		var before: Dictionary = {}
		for jn in m3.JOINT_NAMES:
			before[jn] = m3.get_joint(jn).rotation_degrees
		m3.animate(1.0 / 60.0, 8.0, true, 0.0, "slide")
		for jn in m3.JOINT_NAMES:
			var d: Vector3 = (m3.get_joint(jn).rotation_degrees - before[jn]).abs()
			maxstep = maxf(maxstep, maxf(d.x, maxf(d.y, d.z)))
	_check(maxstep < 25.0, "đổi trạng thái không giật (bước lớn nhất %.1f độ/frame)" % maxstep)
	_check(m3.get_joint("hips").position.y < 0.92 - 0.25, "trượt: hông hạ xuống thật")
	for i in 120:
		m3.animate(1.0 / 60.0, 0.0, true, 0.0)
	_check(m3.get_joint("hips").position.y > 0.9, "về idle: hông trở lại độ cao đứng")

	# --- M7.5: chu kỳ chạy chi tiết, đứng yên có sức sống, lò xo ổn định
	var run_p: Dictionary = an.target_pose("run", PI * 0.5, 7.0, 0.0, 1.0, 0.0)
	var run_q: Dictionary = an.target_pose("run", PI * 0.5 + PI * 0.5, 7.0, 0.0, 1.0, 0.0)
	_check(run_p["hips"].y * run_p["spine"].y < 0.0, "chạy: thân xoay ngược chiều hông")
	_check(absf(run_p["head"].y + run_p["spine"].y + run_p["hips"].y) < 0.01, "chạy: đầu giữ thẳng hướng nhìn (bù xoay thân)")
	var bob_lo: float = 0.0
	var bob_hi: float = -1.0
	for i in 64:
		var bp: Dictionary = an.target_pose("run", TAU * i / 64.0, 7.0, 0.0, 1.0, 0.0)
		bob_lo = minf(bob_lo, bp["hips_y"].x)
		bob_hi = maxf(bob_hi, bp["hips_y"].x)
	_check(bob_hi - bob_lo > 0.02 and bob_hi <= 0.0, "chạy: hông nhún %.3f m theo bước" % (bob_hi - bob_lo))
	_check(run_p["ankle_l"].x * run_p["ankle_r"].x <= 0.0, "chạy: hai bàn chân lật ngược pha")
	var sw_a: float = an.target_pose("run", 0.5 * PI, 7.0, 0.0, 1.0, 0.0)["hips_y"].x
	var sw_b: float = an.target_pose("run", 1.0 * PI, 7.0, 0.0, 1.0, 0.0)["hips_y"].x
	_check(absf(sw_a - sw_b) > 0.005, "chạy: hông nhún lên xuống giữa hai pha")
	var idle_a: Dictionary = an.target_pose("idle", 0.0, 0.0, 0.0, 1.0, 1.0)
	var idle_b: Dictionary = an.target_pose("idle", 0.0, 0.0, 0.0, 1.0, 5.0)
	_check(idle_a["spine"] != idle_b["spine"] and idle_a["hips"] != idle_b["hips"], "đứng yên: thở và đổi trọng tâm theo thời gian")
	var looked: bool = false
	for i in 200:
		var ip: Dictionary = an.target_pose("idle", 0.0, 0.0, 0.0, 1.0, i * 0.1)
		if absf(ip["head"].y) > 5.0:
			looked = true
	_check(looked, "đứng yên: thỉnh thoảng quay đầu nhìn quanh")
	var spr: Node3D = _make("swordsman")
	await process_frame
	spr.animate(0.5, 7.0, true, 0.0, "slide") # frame rất chậm: lò xo vẫn ổn định
	var finite: bool = true
	for jn in spr.JOINT_NAMES:
		var r: Vector3 = spr.get_joint(jn).rotation_degrees
		if not (is_finite(r.x) and is_finite(r.y) and is_finite(r.z)) or r.length() > 400.0:
			finite = false
	_check(finite, "frame chậm 0.5s: lò xo khớp không nổ")
	var overshoot: bool = false
	var sp2: Node3D = _make("swordsman")
	await process_frame
	var prev: float = 0.0
	for i in 90:
		sp2.animate(1.0 / 60.0, 8.0, true, 0.0, "slide")
		var v: float = sp2.get_joint("knee_r").rotation_degrees.x
		if v < -95.0 - 0.2:
			overshoot = true
		prev = v
	_check(absf(prev - (-95.0)) < 2.0, "tư thế trượt: khớp hội tụ về tư thế đích (%.1f)" % prev)

	# Bot
	var b = load("res://scripts/bot.gd").new()
	b.setup("swordsman", 1)
	root.add_child(b)
	await process_frame
	_check(b.mannequin.animator != null, "bot có animator")

	# Người chơi
	var p: Node3D = load("res://scenes/player.tscn").instantiate()
	root.add_child(p)
	await process_frame
	_check(p.body_view != null, "người chơi có thân hình nhân")
	_check((p.camera.cull_mask & p.BODY_LAYER) == 0, "camera người chơi không vẽ layer thân")
	var meshes: Array = p.body_view.find_children("*", "MeshInstance3D", true, false)
	var all_layer: bool = meshes.size() > 0
	for mi in meshes:
		if (mi as MeshInstance3D).layers != p.BODY_LAYER:
			all_layer = false
	_check(all_layer, "mọi mesh thân nằm ở layer riêng (còn đổ bóng)")
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
