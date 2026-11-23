extends SceneTree
## M29: tay + vũ khí góc nhìn thứ nhất - nạp/rút/giật riêng từng súng, ngón tay, bộ phận chuyển động, tiếp đất/leo gờ, chuyển trạng thái mượt.
##   timeout 250 godot --headless --path . -s tools/tests/test_m29.gd

const DT: float = 1.0 / 60.0
const GUNS: Array = ["pistol", "shotgun", "launcher", "sniper"]
var failures: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _fresh(id: String = "pistol") -> Node3D:
	var v: Node3D = load("res://scripts/viewmodel.gd").new()
	root.add_child(v)
	v.set_weapon(id, false)
	return v


func _run() -> void:
	await process_frame
	var G: Node = root.get_node("Global")

	print("[nạp đạn riêng từng súng: tổng thời gian = WEAPONS.reload]")
	var VM = load("res://scripts/viewmodel.gd")
	var sigs: Dictionary = {}
	for id in GUNS:
		var v: Node3D = _fresh(id)
		v.set_reloading(true)
		var total: float = v._gn.total()
		var want: float = float(G.WEAPONS[id]["reload"])
		_check(absf(total - want) < 0.001, "%s: clip nạp %.3f s = %.3f s" % [id, total, want])
		sigs[id] = str(v._reload_keys(id, want).map(func(k): return k.get("rot", Vector3.ZERO)))
		v.queue_free()
	var distinct: Dictionary = {}
	for id in GUNS:
		distinct[sigs[id]] = true
	_check(distinct.size() == GUNS.size(), "mỗi súng một chuỗi nạp khác nhau (%d kiểu)" % distinct.size())
	_check(VM.reload_steps("shotgun").size() >= 5 and VM.reload_steps("pistol").size() == 3, "shotgun nhét từng viên + kéo ống trượt; súng lục 3 bước")

	print("[bộ phận chuyển động khi nạp rồi về chỗ cũ]")
	var expect: Dictionary = {"pistol": "y", "shotgun": "z", "launcher": "rx", "sniper": "z"}
	for id in GUNS:
		var v2: Node3D = _fresh(id)
		var part: Dictionary = v2._anim_parts[id]
		var n: Node3D = part["node"]
		var rest_pos: Vector3 = part["pos"]
		var rest_rot: Vector3 = part["rot"]
		v2.set_reloading(true)
		var moved: float = 0.0
		var total2: float = v2._gn.total()
		for i in int(total2 * 60.0) + 2:
			v2.update(DT, 0.0, true)
			moved = maxf(moved, n.position.distance_to(rest_pos) + n.rotation_degrees.distance_to(rest_rot) * 0.01)
		_check(moved > 0.02, "%s: bộ phận chuyển động khi nạp (độ lệch %.3f)" % [id, moved])
		for i in 60:
			v2.update(DT, 0.0, true)
		_check(n.position.distance_to(rest_pos) < 0.004 and n.rotation_degrees.distance_to(rest_rot) < 1.0, "%s: về đúng chỗ sau khi nạp" % id)
		v2.queue_free()

	print("[hủy nạp giữa chừng: bộ phận về chỗ, không kẹt]")
	var vc: Node3D = _fresh("shotgun")
	vc.set_reloading(true)
	for i in 100:
		vc.update(DT, 0.0, true)
	vc.set_reloading(false)
	for i in 90:
		vc.update(DT, 0.0, true)
	var pp: Dictionary = vc._anim_parts["shotgun"]
	_check((pp["node"] as Node3D).position.distance_to(pp["pos"]) < 0.004 and not vc._gn.active(), "hủy: ống trượt về chỗ, hết clip")

	print("[rút súng riêng từng súng, thời gian = draw]")
	var starts: Dictionary = {}
	for id in GUNS:
		var vd: Node3D = _fresh("pistol")
		vd.set_weapon(id, true)
		_check(vd._gn.clip_name == "draw" and absf(vd._gn.total() - float(G.WEAPONS[id]["draw"])) < 0.001, "%s: clip rút %.3f s = draw" % [id, vd._gn.total()])
		starts[id] = str(vd._gn.pos.x) + str(vd._gn.rot.x)
		for i in 120:
			vd.update(DT, 0.0, true)
		_check(not vd._gn.active() and vd.gun_pivot.position.distance_to(vd._gun_rest_pos) < 0.01, "%s: rút xong về tư thế nghỉ" % id)
		vd.queue_free()
	var ds: Dictionary = {}
	for id in GUNS:
		ds[starts[id]] = true
	_check(ds.size() == GUNS.size(), "tư thế bắt đầu rút khác nhau theo súng")

	print("[giật riêng từng súng]")
	var peaks: Dictionary = {}
	for id in GUNS:
		var vk: Node3D = _fresh(id)
		vk.kick()
		peaks[id] = vk._kick_spring.x
	_check(peaks["shotgun"].z > peaks["pistol"].z * 1.3 and peaks["launcher"].z > peaks["shotgun"].z, "giật lùi: pistol < shotgun < launcher (%.3f / %.3f / %.3f)" % [peaks["pistol"].z, peaks["shotgun"].z, peaks["launcher"].z])
	_check(peaks["sniper"].x > peaks["pistol"].x * 1.5, "sniper hất nòng mạnh hơn pistol (%.1f so với %.1f độ)" % [peaks["sniper"].x, peaks["pistol"].x])
	var vs: Node3D = _fresh("sniper")
	var vp: Node3D = _fresh("pistol")
	vs.kick()
	vp.kick()
	for i in 4:
		vs.update(DT, 0.0, true)
		vp.update(DT, 0.0, true)
	var rs: float = vs._kick_spring.x.z / peaks["sniper"].z
	var rp: float = vp._kick_spring.x.z / peaks["pistol"].z
	_check(rs > rp, "sniper hồi chậm hơn (còn %.2f so với %.2f của đỉnh)" % [rs, rp])

	print("[tay đổi dáng theo hành động]")
	var vf: Node3D = _fresh("pistol")
	for i in 30:
		vf.update(DT, 0.0, true)
	var idle_trigger: float = (vf._gun_fingers[0] as Node3D).rotation_degrees.x
	var idle_mid: float = (vf._gun_fingers[2] as Node3D).rotation_degrees.x
	vf.kick()
	for i in 3:
		vf.update(DT, 0.0, true)
	var fire_trigger: float = (vf._gun_fingers[0] as Node3D).rotation_degrees.x
	var fire_mid: float = (vf._gun_fingers[2] as Node3D).rotation_degrees.x
	_check(fire_trigger > idle_trigger + 3.0, "bắn: ngón trỏ bóp cò (%.1f -> %.1f độ)" % [idle_trigger, fire_trigger])
	_check(fire_mid > idle_mid + 2.0, "bắn: các ngón siết báng (%.1f -> %.1f độ)" % [idle_mid, fire_mid])
	var sw_idle: float = (vf._sword_fingers[1] as Node3D).rotation_degrees.x
	vf.play_swing(0.2, 0.1, 0.3)
	for i in 20:
		vf.update(DT, 0.0, true)
	_check((vf._sword_fingers[1] as Node3D).rotation_degrees.x > sw_idle + 2.0, "chém: tay kiếm siết chặt")
	for i in 120:
		vf.update(DT, 0.0, true)
	_check(absf((vf._gun_fingers[0] as Node3D).rotation_degrees.x - idle_trigger) < 1.5, "xong: tay trở lại nắm hờ")

	print("[tiếp đất mạnh theo vận tốc rơi, leo gờ]")
	var va: Node3D = _fresh("pistol")
	va.update(DT, 0.0, false)
	va.update(DT, 0.0, true, "", 0.0, 0.0)
	var soft: float = va._pos_spring.v.y
	var vb: Node3D = _fresh("pistol")
	vb.update(DT, 0.0, false)
	vb.update(DT, 0.0, true, "", 0.0, 20.0)
	_check(vb._pos_spring.v.y < soft - 0.3, "rơi nhanh nảy xuống mạnh hơn (%.2f so với %.2f m/s)" % [vb._pos_spring.v.y, soft])
	var vl: Node3D = _fresh("pistol")
	vl.ledge()
	_check(vl._pos_spring.v.y > 0.3 and vl._rot_spring.v.x < -10.0, "leo gờ: vũ khí nhấc lên, nòng hất")
	for i in 120:
		vl.update(DT, 0.0, true)
	_check(vl._pos_spring.x.length() < 0.02, "rồi về yên")

	print("[chuyển trạng thái ngẫu nhiên: không nhảy tư thế, hữu hạn, không rò node]")
	var vr: Node3D = _fresh("pistol")
	await process_frame
	var nodes0: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var prev_g: Vector3 = vr.gun_pivot.position
	var prev_s: Vector3 = vr.sword_pivot.position
	var jump_g: float = 0.0
	var jump_s: float = 0.0
	var finite: bool = true
	for f in 1500:
		match rng.randi() % 40:
			0:
				vr.set_weapon(GUNS[rng.randi() % 4], true)   # đổi súng: súng mới hiện từ thấp (chủ ý), không tính là bước nhảy
				prev_g = vr.gun_pivot.position
			1:
				vr.set_reloading(true)
			2:
				vr.set_reloading(false)
			3:
				vr.kick()
			4:
				vr.play_swing(0.18, 0.1, 0.25)
			5:
				vr.raise()
			6:
				vr.parry_hit()
			7:
				vr.parry_fail()
			8:
				vr.ledge()
		var was_draw: bool = vr._gn.clip_name == "draw"
		vr.update(DT, 6.0, rng.randf() > 0.2, "", 0.0, rng.randf() * 15.0)
		if was_draw and vr._gn.clip_name != "draw":
			prev_g = vr.gun_pivot.position
		jump_g = maxf(jump_g, vr.gun_pivot.position.distance_to(prev_g))
		jump_s = maxf(jump_s, vr.sword_pivot.position.distance_to(prev_s))
		prev_g = vr.gun_pivot.position
		prev_s = vr.sword_pivot.position
		finite = finite and is_finite(prev_g.x) and is_finite(prev_s.x)
	_check(finite, "1500 khung chen ngang: giá trị hữu hạn")
	_check(jump_g < 0.22 and jump_s < 0.2, "bước nhảy lớn nhất mỗi khung: súng %.3f, kiếm %.3f m" % [jump_g, jump_s])
	vr.set_reloading(false)
	for i in 400:
		vr.update(DT, 0.0, true)
	_check(vr.gun_pivot.position.distance_to(vr._gun_rest_pos) < 0.01 and not vr._gn.active(), "sau đó súng về chỗ nghỉ")
	for id in GUNS:
		var d: Dictionary = vr._anim_parts[id]
		_check((d["node"] as Node3D).position.distance_to(d["pos"]) < 0.01, "%s: bộ phận về chỗ" % id)
	_check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == nodes0, "không rò node")

	print("[tay IK vẫn dính vật cầm, mọi súng]")
	for id in GUNS:
		var vi: Node3D = _fresh(id)
		vi.set_reloading(true)
		var worst: float = 0.0
		for i in 150:
			vi.update(DT, 0.0, true)
			worst = maxf(worst, vi.arm_error("gun"))
		_check(worst < 0.02, "%s: sai số tay-súng lớn nhất %.4f m khi nạp" % [id, worst])

	print("[API công khai còn nguyên]")
	var va2: Node3D = _fresh("pistol")
	for m in ["update", "play_swing", "raise", "parry_hit", "parry_fail", "kick", "set_reloading", "flinch", "reset", "set_weapon"]:
		_check(va2.has_method(m), "có %s" % m)
	va2.set_reloading(true)
	va2.reset()
	_check(not va2.reloading and not va2._gn.active(), "reset xoá nạp đạn")

	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
