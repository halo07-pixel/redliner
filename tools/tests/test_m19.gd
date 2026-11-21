extends SceneTree
## Test headless M19: hệ hoạt ảnh mượt hơn (clip + lò xo + cửa sổ hủy + IK + camera).
##   timeout 200 godot --headless --path . -s tools/tests/test_m19.gd

var failures: int = 0
const DT: float = 1.0 / 60.0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _fresh() -> Node3D:
	var v: Node3D = load("res://scripts/viewmodel.gd").new()
	root.add_child(v)
	return v


## Đo bước nhảy lớn nhất giữa hai khung liên tiếp của kiếm (vị trí m, góc độ) và súng khi chạy `frames` khung.
## `script`: Callable(frame_index, vm) gọi trước mỗi update.
func _run_trace(v: Node3D, frames: int, script: Callable, speed: float = 0.0, st: String = "") -> Dictionary:
	var max_p: float = 0.0
	var max_r: float = 0.0
	var max_gp: float = 0.0
	var pp: Vector3 = v.sword_pivot.position
	var pr: Vector3 = v.sword_pivot.rotation_degrees
	var pg: Vector3 = v.gun_pivot.position
	for i in frames:
		script.call(i, v)
		v.update(DT, speed, true, st)
		max_p = maxf(max_p, v.sword_pivot.position.distance_to(pp))
		max_r = maxf(max_r, v.sword_pivot.rotation_degrees.distance_to(pr))
		max_gp = maxf(max_gp, v.gun_pivot.position.distance_to(pg))
		pp = v.sword_pivot.position
		pr = v.sword_pivot.rotation_degrees
		pg = v.gun_pivot.position
	return {"p": max_p, "r": max_r, "gp": max_gp}


var _rng := RandomNumberGenerator.new()


## Lệnh ngẫu nhiên cứ 4 khung một lần: chém / đỡ / parry hụt / bắn / nạp / parry thành công.
func _chaos(i: int, vm: Node3D) -> void:
	if i % 4 != 0:
		return
	match _rng.randi() % 6:
		0:
			vm.play_swing(0.12, 0.1, 0.28)
		1:
			vm.raise()
		2:
			vm.parry_fail()
		3:
			vm.kick()
		4:
			vm.set_reloading(_rng.randi() % 2 == 0)
		5:
			vm.parry_hit()


func _run() -> void:
	await process_frame
	var G: Node = root.get_node("Global")
	var V: Dictionary = G.VIEWMODEL

	print("[easing]")
	var VM: GDScript = load("res://scripts/viewmodel.gd")
	for kind in ["lin", "in", "out", "io", "elastic", "back"]:
		_check(absf(VM.ease_u(kind, 0.0)) < 0.001 and absf(VM.ease_u(kind, 1.0) - 1.0) < 0.001, "easing '%s': 0 -> 0, 1 -> 1" % kind)
	_check(VM.ease_u("in", 0.5) < 0.2 and VM.ease_u("out", 0.5) > 0.8, "in = vào chậm tăng tốc, out = bật nhanh rồi giảm tốc")
	var el_max: float = 0.0
	var bk_max: float = 0.0
	for i in 101:
		el_max = maxf(el_max, VM.ease_u("elastic", i / 100.0))
		bk_max = maxf(bk_max, VM.ease_u("back", i / 100.0))
	_check(el_max > 1.05 and bk_max > 1.05, "elastic/back vượt đích rồi về (%.2f / %.2f)" % [el_max, bk_max])

	print("[blending: đổi trạng thái không nhảy tư thế]")
	var v: Node3D = _fresh()
	await process_frame
	var seq: Array = ["", "slide", "dash", "grapple", "", "wallrun", "slide", ""]
	var st_ref: Array = [""]
	var maxp: float = 0.0
	var maxr: float = 0.0
	var maxg: float = 0.0
	var pp: Vector3 = v.sword_pivot.position
	var pr: Vector3 = v.sword_pivot.rotation_degrees
	var pg: Vector3 = v.gun_pivot.position
	for s in seq:
		for i in 40:
			v.update(DT, 8.0, true, s, 0.5)
			maxp = maxf(maxp, v.sword_pivot.position.distance_to(pp))
			maxr = maxf(maxr, v.sword_pivot.rotation_degrees.distance_to(pr))
			maxg = maxf(maxg, v.gun_pivot.position.distance_to(pg))
			pp = v.sword_pivot.position
			pr = v.sword_pivot.rotation_degrees
			pg = v.gun_pivot.position
	_check(maxp < 0.012 and maxg < 0.02, "đổi trạng thái liên tục: bước nhảy vị trí lớn nhất kiếm %.4f m, súng %.4f m / khung (súng giơ 0.22 m khi đu móc)" % [maxp, maxg])
	_check(maxr < 3.5, "đổi trạng thái liên tục: bước nhảy góc kiếm lớn nhất %.2f độ / khung" % maxr)
	var w_ok: bool = true
	var vw: Node3D = _fresh()
	var last_w: float = 0.0
	for i in 30:
		vw.update(DT, 5.0, true, "slide")
		var cw: float = float(vw._w["slide"])
		if absf(cw - last_w) > DT / float(V["state_fade"]) + 0.001:
			w_ok = false
		last_w = cw
	_check(w_ok and last_w >= 0.999, "trọng số trạng thái trượt dần 0 -> 1 trong state_fade, không nhảy")

	print("[chém: ngắt giữa chừng vẫn liền mạch]")
	var base_v: Node3D = _fresh()
	await process_frame
	var ref: Dictionary = _run_trace(base_v, 60, func(i: int, vm: Node3D): if i == 0: vm.play_swing(0.12, 0.1, 0.28))
	var cut_v: Node3D = _fresh()
	await process_frame
	var cut: Dictionary = _run_trace(cut_v, 60, func(i: int, vm: Node3D):
		if i == 0:
			vm.play_swing(0.12, 0.1, 0.28)
		if i == 10:
			vm.parry_fail())
	_check(float(cut["p"]) <= float(ref["p"]) * 1.25 and float(cut["r"]) <= float(ref["r"]) * 1.25, "ngắt bằng parry_fail giữa windup: bước nhảy không lớn hơn chính cú chém (%.4f vs %.4f m, %.1f vs %.1f độ)" % [cut["p"], ref["p"], cut["r"], ref["r"]])
	var rc: Node3D = _fresh()
	await process_frame
	var rcut: Dictionary = _run_trace(rc, 60, func(i: int, vm: Node3D):
		if i == 0:
			vm.play_swing(0.12, 0.1, 0.28)
		if i == 25:
			vm.raise())
	_check(float(rcut["p"]) < 0.2 and float(rcut["r"]) < 45.0, "chém rồi đỡ ngay khi hết cửa sổ hủy: không nhảy tư thế (%.4f m, %.1f độ / khung; đỡ bật nhanh có chủ đích, nhảy thẳng sẽ > 0.4 m)" % [rcut["p"], rcut["r"]])

	print("[cửa sổ hủy + hàng đợi]")
	var q: Node3D = _fresh()
	await process_frame
	q.play_swing(0.12, 0.1, 0.28)
	for i in 3:
		q.update(DT, 0.0, true)
	q.raise()
	_check(q.pending_command == "raise", "đỡ khi đang windup (chưa hủy được): xếp hàng, chưa chạy")
	_check(q._sw.clip_name == "swing", "clip chém vẫn đang chạy")
	for i in 30:
		q.update(DT, 0.0, true)
	_check(q.pending_command == "" and q._sw.clip_name == "parry", "tới cửa sổ hủy: lệnh đỡ chạy (clip = %s)" % q._sw.clip_name)
	q.play_swing(0.12, 0.1, 0.28)
	q.update(DT, 0.0, true)
	q.parry_fail()
	_check(q._sw.clip_name == "parry_fail" and q.pending_command == "", "parry_fail luôn ngắt ngay, xoá hàng đợi")
	_check(q.debug_info().begins_with("VM sword[parry_fail"), "debug_info báo clip/pha hiện tại: %s" % q.debug_info())

	print("[chen ngang ngẫu nhiên vẫn về nghỉ, không rò node]")
	var ch: Node3D = _fresh()
	await process_frame
	var nodes_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var kids_before: int = ch.get_child_count()
	_rng.seed = 19
	var chaos: Dictionary = _run_trace(ch, 600, _chaos, 6.0, "")
	_check(is_finite(ch.sword_pivot.position.x) and is_finite(ch.gun_pivot.position.x), "chen ngang 600 khung: giá trị hữu hạn")
	_check(float(chaos["p"]) < 0.2, "chen ngang liên tục: bước nhảy vị trí kiếm lớn nhất %.3f m / khung" % chaos["p"])
	ch.set_reloading(false)
	for i in 300:
		ch.update(DT, 0.0, true)
	_check(ch.sword_pivot.position.distance_to(ch._sword_rest_pos) < 0.02 and ch.sword_pivot.rotation_degrees.distance_to(ch._sword_rest) < 5.0, "sau đó về tư thế nghỉ")
	_check(ch.gun_pivot.position.distance_to(ch._gun_rest_pos) < 0.01 and not ch._sw.active() and not ch._gn.active() and ch.pending_command == "", "súng về chỗ, hết clip, hàng đợi trống")
	_check(ch.get_child_count() == kids_before and int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == nodes_before, "không rò node (con %d, tổng node %d)" % [ch.get_child_count(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])

	print("[tay IK: bàn tay dính chuôi/báng]")
	var ik: Node3D = _fresh()
	await process_frame
	var worst: float = 0.0
	var reach_ok: bool = true
	var checks: Array = []
	for scenario in ["rest", "swing", "guard", "slide", "grapple", "reload"]:
		match scenario:
			"swing":
				ik.play_swing(0.12, 0.1, 0.28)
			"guard":
				ik.parry_fail()
				for i in 60:
					ik.update(DT, 0.0, true)
				ik.raise()
			"reload":
				ik.set_reloading(true)
		for i in 60:
			var st: String = scenario if scenario in ["slide", "grapple"] else ""
			ik.update(DT, 6.0, true, st)
			worst = maxf(worst, maxf(ik.arm_error("sword"), ik.arm_error("gun")))
			for arm in [ik._sword_arm, ik._gun_arm]:
				var d: float = (Vector3(arm["wrist"]) - Vector3(arm["shoulder"])).length()
				if d > float(arm["l1"]) + float(arm["l2"]) - 0.002:
					reach_ok = false
	_check(worst < 0.002, "đầu cẳng tay trùng cổ tay mọi tư thế (sai số lớn nhất %.5f m)" % worst)
	_check(reach_ok, "cổ tay luôn trong tầm với của tay (không bị kéo giãn)")
	var elb: Vector3 = VM.solve_two_bone(Vector3.ZERO, Vector3(0.0, 0.0, -0.8), 0.6, 0.6, Vector3.DOWN)
	_check(absf(elb.distance_to(Vector3.ZERO) - 0.6) < 0.001 and absf(elb.distance_to(Vector3(0.0, 0.0, -0.8)) - 0.6) < 0.001 and elb.y < 0.0, "IK hai khớp: độ dài hai đoạn đúng, khuỷu hướng về pole")

	print("[nhịp bước chân]")
	var fs: Node3D = _fresh()
	fs.update(DT, 8.0, true)
	var vy0: float = fs._pos_spring.v.y
	fs.footstep(8.0)
	var rz1: float = fs._rot_spring.v.z
	fs.footstep(8.0)
	var rz2: float = fs._rot_spring.v.z
	_check(fs._pos_spring.v.y < vy0 - 0.2, "bước chân: tay nhún xuống một nhịp")
	_check((rz1 > 0.0) != (rz2 - rz1 > 0.0), "bước chân: nghiêng luân phiên trái/phải")

	print("[camera + người chơi thật]")
	var p: Node3D = load("res://scenes/player.tscn").instantiate()
	root.add_child(p)
	await process_frame
	var vv: Vector3 = p._cam_fx_v
	p.melee.swing_started.emit(0.12, 0.1, 0.28)
	_check(p._cam_fx_v.z < vv.z - 0.2, "chém: camera lao nhẹ tới trước (xung z %.2f)" % p._cam_fx_v.z)
	for i in 120:
		p._step_cam_fx(DT)
	_check(p._cam_fx.length() < 0.003, "lò xo camera hồi về 0")
	G.set_setting("cam_fx", 0.0)
	p._cam_fx_v = Vector3.ZERO
	p.melee.swing_started.emit(0.12, 0.1, 0.28)
	_check(p._cam_fx_v.length() < 0.0001, "hệ số cam_fx = 0: tắt lao camera")
	G.set_setting("cam_fx", 1.0)
	p._fall_vy = -16.0
	p._was_floor_vis = false
	p._cam_fx_v = Vector3.ZERO
	p.global_position = Vector3(0.0, 0.0, 0.0)
	p._step_cam_fx(DT) # không đứng trên sàn trong test: chỉ kiểm không nổ
	_check(is_finite(p._cam_fx.y), "tiếp đất/rơi: lò xo camera ổn định")
	var vy_before: float = p.viewmodel._pos_spring.v.y
	p.footstep.emit(8.0)
	_check(p.viewmodel._pos_spring.v.y < vy_before - 0.2, "Signal footstep của người chơi -> viewmodel nhún (signal up)")
	var stride: float = float(G.PLAYER["step_stride"])
	_check(absf(1.0 / stride - float(V["bob_freq"])) < 0.01, "nhịp nhún viewmodel = 1 / step_stride (%.4f vs %.4f)" % [1.0 / stride, float(V["bob_freq"])])
	p.respawn(Vector3.ZERO)
	_check(not p.viewmodel._sw.active() and not p.viewmodel._gn.active(), "hồi sinh: hết clip đang chạy")

	print("[bot: rig_animator]")
	var RigA: GDScript = load("res://scripts/rig_animator.gd")
	var mq: Node3D = load("res://scripts/mannequin.gd").new()
	root.add_child(mq)
	await process_frame
	var ra = RigA.new()
	ra.setup(mq)
	var hr: Dictionary = ra.overlay_pose("hurt", 0.1, 0.25, {"direction": Vector3(1.0, 0.0, 0.5)})
	var hl: Dictionary = ra.overlay_pose("hurt", 0.1, 0.25, {"direction": Vector3(-1.0, 0.0, 0.5)})
	_check(signf((hr["head"] as Vector3).y) == -signf((hl["head"] as Vector3).y) and absf((hr["head"] as Vector3).y) > 3.0, "bị đánh từ phải/trái: đầu bật hai hướng ngược nhau")
	_check(signf((hr["hips"] as Vector3).y) == -signf((hl["hips"] as Vector3).y), "bị đánh: hông xoay theo hướng đòn")
	var sw_end: Dictionary = ra.overlay_pose("swing", 0.12 + 0.1 + 0.05, 0.5, {"windup": 0.12, "active": 0.1, "recovery": 0.28})
	var sw_late: Dictionary = ra.overlay_pose("swing", 0.12 + 0.1 + 0.27, 0.5, {"windup": 0.12, "active": 0.1, "recovery": 0.28})
	_check((sw_end["shoulder_r"] as Vector3).x < -20.0 and (sw_late["shoulder_r"] as Vector3).x > (sw_end["shoulder_r"] as Vector3).x, "chém: tay quất quá đích (follow-through) rồi mới thu về")
	var pm0: Dictionary = ra.overlay_pose("parry", 0.0, 0.28, {})
	var pm1: Dictionary = ra.overlay_pose("parry", 0.1, 0.28, {})
	_check((pm0["shoulder_r"] as Vector3).length() < 1.0 and (pm1["shoulder_r"] as Vector3).x < -55.0, "đỡ: bật từ nghỉ lên tư thế chắn rất nhanh")
	# trọng số overlay trơn: không nhảy
	ra.play("swing", 0.5, {"windup": 0.12, "active": 0.1, "recovery": 0.28})
	var wprev: float = 0.0
	var wmax: float = 0.0
	for i in 40:
		ra.update(DT, 5.0, true, 0.0)
		var wc: float = ra.overlay_weight()
		wmax = maxf(wmax, absf(wc - wprev))
		wprev = wc
	_check(wmax < 0.5, "trọng số overlay đổi trơn giữa hai khung (lớn nhất %.2f)" % wmax)

	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
