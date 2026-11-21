extends SceneTree
## Test headless M20: IK hình nhân (hai khớp, bám chân, nhìn mục tiêu, tay đỡ báng), hoạt ảnh tiếp xúc (clash, parry, vùng trúng),
## bộ chỉnh hoạt ảnh. Chạy:  timeout 300 godot --headless --path . -s tools/tests/test_m20.gd

const DT: float = 1.0 / 60.0
var failures: int = 0
var world: Node3D


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _block(p_kind: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var m: Node3D = load("res://scripts/mannequin.gd").new()
	m.kind = p_kind
	m.position = pos
	world.add_child(m)
	return m


func _gltf(p_kind: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var m: Node3D = load("res://scripts/mannequin_gltf.gd").new()
	m.kind = p_kind
	m.position = pos
	world.add_child(m)
	return m


func _floor_box(center: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = center
	world.add_child(b)
	return b


func _settle(m: Node3D, frames: int, speed: float = 0.0) -> void:
	for i in frames:
		m.animate(DT, speed, true, 0.0)


func _run() -> void:
	await process_frame
	var G: Node = root.get_node("Global")
	var IK: GDScript = load("res://scripts/rig_ik.gd")
	world = Node3D.new()
	root.add_child(world)

	print("[IK hai khớp: chính xác]")
	for factory in ["block", "gltf"]:
		var m: Node3D = _block("gunner") if factory == "block" else _gltf("gunner")
		await process_frame
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var worst: float = 0.0
		for leg in [true, false]:
			for i in 150:
				(m.get_joint("hips") as Node3D).rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-1.0, 1.0), rng.randf_range(-0.2, 0.2))
				var names: Array = ["hip_l", "knee_l", "ankle_l"] if leg else ["shoulder_r", "elbow_r", "hand_r"]
				var up: Node3D = m.get_joint(names[0])
				var lo: Node3D = m.get_joint(names[1])
				var en: Node3D = m.get_joint(names[2])
				var reach: float = lo.position.length() + en.position.length()
				var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 0.3), rng.randf_range(-1, 1)).normalized()
				var t: Vector3 = up.global_position + dir * rng.randf_range(0.3, 0.97) * reach
				IK.apply_limb(up, lo, en, t, leg, 1.0)
				worst = maxf(worst, en.global_position.distance_to(t))
		_check(worst < 0.0005, "%s: đầu chi tới đúng đích, tay và chân, hông xoay ngẫu nhiên (sai số lớn nhất %.6f m)" % [factory, worst])
		(m.get_joint("hips") as Node3D).rotation = Vector3.ZERO
		var up2: Node3D = m.get_joint("hip_l")
		var far: Vector3 = up2.global_position + Vector3(0.0, -5.0, 0.0)
		IK.apply_limb(up2, m.get_joint("knee_l"), m.get_joint("ankle_l"), far, true, 1.0)
		var reach2: float = m.get_joint("knee_l").position.length() + m.get_joint("ankle_l").position.length()
		_check(m.get_joint("ankle_l").global_position.distance_to(up2.global_position) <= reach2 + 0.001 and is_finite(m.get_joint("knee_l").rotation.x), "%s: đích ngoài tầm: duỗi thẳng, không giãn xương, không NaN" % factory)
		# trộn trọng số
		(m.get_joint("hip_l") as Node3D).rotation = Vector3.ZERO
		(m.get_joint("knee_l") as Node3D).rotation = Vector3.ZERO
		var tgt: Vector3 = up2.global_position + Vector3(0.1, -0.5, -0.3)
		IK.apply_limb(up2, m.get_joint("knee_l"), m.get_joint("ankle_l"), tgt, true, 0.0)
		_check(m.get_joint("knee_l").rotation.length() < 0.0001, "%s: trọng số 0 giữ nguyên FK" % factory)
		IK.apply_limb(up2, m.get_joint("knee_l"), m.get_joint("ankle_l"), tgt, true, 0.5)
		var half: float = m.get_joint("ankle_l").global_position.distance_to(tgt)
		IK.apply_limb(up2, m.get_joint("knee_l"), m.get_joint("ankle_l"), tgt, true, 1.0)
		_check(half > 0.01 and m.get_joint("ankle_l").global_position.distance_to(tgt) < 0.0005, "%s: trọng số 0.5 nằm giữa FK và IK" % factory)
		m.queue_free()

	print("[bám chân: bậc thang và hố]")
	var ground_names: Array = ["block", "gltf"]
	for factory in ground_names:
		var fl: StaticBody3D = _floor_box(Vector3(0.0, -0.5, 0.0), Vector3(20.0, 1.0, 20.0))        # sàn y = 0
		var step: StaticBody3D = _floor_box(Vector3(-0.11, 0.125, 0.0), Vector3(0.2, 0.25, 2.0))   # bậc cao 0.25 chỉ dưới chân trái
		var bm: Node3D = _block("swordsman", Vector3(0.0, 0.0, 0.0)) if factory == "block" else _gltf("swordsman", Vector3(0.0, 0.0, 0.0))
		await physics_frame
		await physics_frame
		_settle(bm, 90)
		var ank_l: Vector3 = bm.get_joint("ankle_l").global_position
		var ank_r: Vector3 = bm.get_joint("ankle_r").global_position
		_check(absf(ank_r.y - 0.07) < 0.06 and ank_l.y > ank_r.y + 0.15, "%s: chân trái đặt lên bậc 0.25 m, chân phải trên sàn (y trái %.3f, phải %.3f)" % [factory, ank_l.y, ank_r.y])
		_check(is_finite((bm.get_joint("knee_l") as Node3D).rotation.x), "%s: gối hữu hạn" % factory)
		step.queue_free()
		await physics_frame
		await physics_frame
		_settle(bm, 90)
		_check(absf(bm.animator.ik.hip_off) < 0.02, "%s: bỏ bậc: hông về chỗ (%.3f)" % [factory, bm.animator.ik.hip_off])
		# hố: sàn dưới chân phải thấp 0.2
		fl.queue_free()
		var pit_l: StaticBody3D = _floor_box(Vector3(-2.1, -0.5, 0.0), Vector3(4.0, 1.0, 20.0))
		var pit_r: StaticBody3D = _floor_box(Vector3(2.0, -0.7, 0.0), Vector3(4.0, 1.0, 20.0))
		var pit_m: StaticBody3D = _floor_box(Vector3(0.0, -0.7, 0.0), Vector3(0.2, 1.0, 20.0))
		await physics_frame
		await physics_frame
		_settle(bm, 120)
		var hy: float = bm.get_joint("hips").position.y
		_check(bm.animator.ik.hip_off < -0.1, "%s: một chân thấp hơn 0.2 m: hông hạ xuống (%.3f)" % [factory, bm.animator.ik.hip_off])
		_check(bm.get_joint("ankle_r").global_position.y < bm.get_joint("ankle_l").global_position.y - 0.1, "%s: chân phải với xuống sàn thấp" % factory)
		for b in [pit_l, pit_r, pit_m]:
			b.queue_free()
		bm.queue_free()
		await physics_frame

	print("[bám chân: sàn phẳng không đổi hoạt ảnh chạy]")
	var flat: StaticBody3D = _floor_box(Vector3(0.0, -0.5, 0.0), Vector3(40.0, 1.0, 40.0))
	var rm: Node3D = _block("swordsman")
	await physics_frame
	await physics_frame
	var max_off: float = 0.0
	for i in 180:
		rm.animate(DT, 7.0, true, 0.0)
		max_off = maxf(max_off, maxf(absf(rm.animator.ik.hip_off), maxf(absf(rm.animator.ik.foot_off[0]), absf(rm.animator.ik.foot_off[1]))))
	_check(max_off < 0.03, "chạy trên sàn phẳng: IK chân gần như không can thiệp (lệch lớn nhất %.3f m)" % max_off)
	rm.ik_feet = false
	rm.animator.ik.hip_off = 0.0
	var hips_before: float = rm.get_joint("hips").position.y
	_settle(rm, 5)
	_check(absf(rm.animator.ik.hip_off) < 0.0001, "ik_feet = false: tắt bám chân")
	rm.queue_free()

	print("[nhìn mục tiêu]")
	var lm: Node3D = _block("swordsman")
	await physics_frame
	var tgt_pos: Vector3 = Vector3(2.0, 3.0, -3.0)
	_settle(lm, 90)
	var head: Node3D = lm.get_joint("head")
	var base_ang: float = (-head.global_transform.basis.z).angle_to((tgt_pos - head.global_position).normalized())
	lm.set_look_target(tgt_pos)
	_settle(lm, 90)
	var look_ang: float = (-head.global_transform.basis.z).angle_to((tgt_pos - head.global_position).normalized())
	_check(look_ang < base_ang - 0.1, "đầu quay về phía mục tiêu (góc lệch %.2f -> %.2f rad)" % [base_ang, look_ang])
	lm.set_look_target(Vector3(0.0, 1.5, 6.0))   # ngay sau lưng
	_settle(lm, 120)
	_check(absf(lm.animator.ik.look_yaw) <= deg_to_rad(float(G.ANIM["look_max_yaw"])) + 0.001, "mục tiêu sau lưng: yaw bị chặn ở giới hạn (%.2f rad)" % lm.animator.ik.look_yaw)
	lm.set_look_target(null)
	_settle(lm, 150)
	_check(absf(lm.animator.ik.look_w) < 0.02 or absf(lm.animator.ik.look_yaw) < 0.05 or lm.animator.ik.look_w < 0.5, "bỏ mục tiêu: thôi nhìn mượt")
	lm.set_look_target(tgt_pos)
	lm.play("die", 0.45)
	_settle(lm, 40)
	_check(lm.animator.ik.look_w < 0.1, "đang chết: không quay đầu nhìn")
	lm.queue_free()

	print("[tay trái đỡ báng súng]")
	for factory in ["block", "gltf"]:
		var gm: Node3D = _block("gunner") if factory == "block" else _gltf("gunner")
		await physics_frame
		_settle(gm, 60)
		var elbow: Node3D = gm.get_joint("elbow_l")
		var palm: Vector3 = gm.get_joint("hand_l").global_position + elbow.global_transform.basis.orthonormalized() * Vector3(0.0, -0.06, 0.0)
		var grip: Vector3 = gm.support_grip()
		var with_ik: float = palm.distance_to(grip)
		G.tune["a.support_hand"] = 0.0
		_settle(gm, 90)
		var palm0: Vector3 = gm.get_joint("hand_l").global_position + elbow.global_transform.basis.orthonormalized() * Vector3(0.0, -0.06, 0.0)
		var without: float = palm0.distance_to(gm.support_grip())
		G.tune.clear()
		_check(with_ik < without - 0.03 or with_ik < 0.08, "%s: IK đưa tay trái gần báng hơn FK (%.3f m so với %.3f m)" % [factory, with_ik, without])
		gm.queue_free()

	print("[hoạt ảnh tiếp xúc: overlay]")
	var rm2: Node3D = _block("swordsman")
	await physics_frame
	var an = rm2.animator
	var c0: Dictionary = an.overlay_pose("clash", 0.0, 0.5, {"direction": Vector3(0.0, 0.0, 1.0)})
	var c1: Dictionary = an.overlay_pose("clash", 0.4, 0.5, {"direction": Vector3(0.0, 0.0, 1.0)})
	_check((c0["shoulder_r"] as Vector3).x > 90.0 and (c1["shoulder_r"] as Vector3).x < 20.0, "clash: kiếm bật lên ngay rồi hạ về")
	_check(float((c0["hips_z"] as Vector3).x) > 0.1, "clash: bị đẩy lùi (hips_z %.2f)" % float((c0["hips_z"] as Vector3).x))
	var cl: Dictionary = an.overlay_pose("clash", 0.1, 0.5, {"direction": Vector3(-1.0, 0.0, 0.2)})
	var cr: Dictionary = an.overlay_pose("clash", 0.1, 0.5, {"direction": Vector3(1.0, 0.0, 0.2)})
	_check(signf((cl["spine"] as Vector3).y) == -signf((cr["spine"] as Vector3).y), "clash: thân xoay theo hướng đẩy trái/phải")
	var s0: Dictionary = an.overlay_pose("stagger", 0.02, 1.0, {})
	var s1: Dictionary = an.overlay_pose("stagger", 0.6, 1.0, {})
	_check((s0["shoulder_r"] as Vector3).x > 60.0 and (s1["shoulder_r"] as Vector3).x < 20.0, "bị parry/choáng: kiếm bị hất bật lên rồi buông")
	var p0: Dictionary = an.overlay_pose("parry_hit", 0.0, 0.3, {})
	var p1: Dictionary = an.overlay_pose("parry_hit", 0.08, 0.3, {})
	var p2: Dictionary = an.overlay_pose("parry_hit", 0.29, 0.3, {})
	_check((p0["shoulder_r"] as Vector3).x < -50.0 and (p1["shoulder_r"] as Vector3).x > (p0["shoulder_r"] as Vector3).x + 40.0 and (p2["shoulder_r"] as Vector3).x > -30.0, "parry thành công: đẩy kiếm ra rồi thu về")
	var ht: Dictionary = an.overlay_pose("hurt", 0.1, 0.25, {"direction": Vector3(0, 0, 1), "zone": "head"})
	var tt: Dictionary = an.overlay_pose("hurt", 0.1, 0.25, {"direction": Vector3(0, 0, 1), "zone": "torso"})
	var lt: Dictionary = an.overlay_pose("hurt", 0.1, 0.25, {"direction": Vector3(0, 0, 1), "zone": "legs"})
	_check((ht["head"] as Vector3).x < (tt["head"] as Vector3).x - 20.0, "trúng đầu: đầu hất mạnh hơn trúng thân")
	_check((lt["+knee_l"] as Vector3).x < (tt["+knee_l"] as Vector3).x - 10.0 and float((lt["+hips_y"] as Vector3).x) < float((tt["+hips_y"] as Vector3).x) - 0.05, "trúng chân: khuỵu gối sâu, hông hạ")
	rm2.play("clash", 0.5, {"direction": Vector3(0, 0, 1)})
	rm2.play("swing", 0.5, {"windup": 0.2, "active": 0.1, "recovery": 0.2})
	_check(an.overlay["name"] == "clash", "clash (ưu tiên 2) không bị chém (ưu tiên 1) cắt ngang")
	for i in 40:
		rm2.animate(DT, 0.0, true, 0.0)
	_check(is_finite(rm2.get_joint("shoulder_r").rotation.x), "chạy overlay clash: giá trị hữu hạn")
	rm2.queue_free()

	print("[hoạt ảnh tiếp xúc: nối Signal bot và người chơi]")
	var bot = load("res://scripts/bot.gd").new()
	bot.setup("swordsman", 1)
	bot.position = Vector3(5.0, 0.0, 5.0)
	world.add_child(bot)
	await physics_frame
	bot.melee.clashed.emit(Vector3(0.0, 0.0, 1.0))
	_check(bot.mannequin.animator.overlay.get("name", "") == "clash", "bot: melee.clashed -> overlay clash")
	bot.mannequin.clear_overlay()
	bot.parry.parried.emit({})
	_check(bot.mannequin.animator.overlay.get("name", "") == "parry_hit", "bot: parry.parried -> overlay parry_hit")
	_check(bot.hit_zone({"point": bot.global_position + Vector3(0.0, 1.62, 0.0)}) == "head" and bot.hit_zone({"point": bot.global_position + Vector3(0.0, 0.3, 0.0)}) == "legs" and bot.hit_zone({"point": bot.global_position + Vector3(0.0, 1.1, 0.0)}) == "torso" and bot.hit_zone({}) == "torso", "bot: vùng trúng theo độ cao điểm trúng (đầu/chân/thân, không có điểm = thân)")
	bot.mannequin.clear_overlay()
	bot._on_hurt({"direction": Vector3(0, 0, 1), "point": bot.global_position + Vector3(0.0, 1.7, 0.0)}, 10.0)
	_check(bot.mannequin.animator.overlay["data"].get("zone", "") == "head", "bot: bị trúng đầu -> overlay hurt vùng head")
	bot.queue_free()

	var p: Node3D = load("res://scenes/player.tscn").instantiate()
	world.add_child(p)
	await physics_frame
	p.melee.clashed.emit(Vector3(0.0, 0.0, 1.0))
	_check(p.viewmodel._sw.clip_name == "clash" and p.body_view.animator.overlay.get("name", "") == "clash", "người chơi: clashed -> viewmodel + thân cùng phản ứng clash")
	var v: Node3D = p.viewmodel
	var maxp: float = 0.0
	var pp: Vector3 = v.sword_pivot.position
	for i in 90:
		v.update(DT, 0.0, true)
		maxp = maxf(maxp, v.sword_pivot.position.distance_to(pp))
		pp = v.sword_pivot.position
	_check(maxp < 0.2 and v.sword_pivot.position.distance_to(v._sword_rest_pos) < 0.03, "clash viewmodel: không nhảy tư thế (bước lớn nhất %.3f m) và về nghỉ" % maxp)
	p.body_view.clear_overlay()
	p.parry.parried.emit({})
	_check(v._sw.clip_name == "parry_hit" and p.body_view.animator.overlay.get("name", "") == "parry_hit", "người chơi: parry thành công -> kiếm bật ra + thân phản ứng")
	_check(not p.body_view.ik_feet, "thân người chơi tắt IK chân (chỉ để đổ bóng)")
	p.queue_free()

	print("[bộ chỉnh hoạt ảnh]")
	var tuner: CanvasLayer = load("res://scripts/anim_tuner.gd").new()
	root.add_child(tuner)
	await process_frame
	var base_k: float = float(G.VIEWMODEL["swing_active_k"])
	_check(is_equal_approx(float(G.tv("swing_active_k")), base_k), "chưa chỉnh: tv() trả hằng số gốc")
	_check(tuner.set_value("v.swing_active_k", 900.0) and is_equal_approx(float(G.tv("swing_active_k")), 900.0), "chỉnh v.swing_active_k = 900: viewmodel đọc giá trị mới")
	_check(tuner.set_value("a.cam_lunge", 2.0) and is_equal_approx(float(G.ta("cam_lunge")), 2.0), "chỉnh a.cam_lunge")
	_check(not tuner.set_value("v.khong_co", 1.0), "khoá không có: bị từ chối")
	var txt: String = tuner.export_text()
	_check(txt.contains("v.swing_active_k = 900") and txt.contains("a.cam_lunge = 2"), "xuất: chỉ liệt kê giá trị đã đổi (%s)" % txt.replace("\n", "; "))
	var vm: Node3D = load("res://scripts/viewmodel.gd").new()
	root.add_child(vm)
	await process_frame
	vm.play_swing(0.12, 0.1, 0.28)
	_check(is_equal_approx(float(vm._sw.keys[2]["k"]), 900.0), "clip chém mới dùng độ cứng đã chỉnh (k = %.0f)" % float(vm._sw.keys[2]["k"]))
	tuner.set_value("v.swing_active_k", base_k)
	_check(not G.tune.has("v.swing_active_k"), "đặt lại đúng mặc định: bỏ khỏi danh sách ghi đè")
	tuner.reset_all()
	_check(G.tune.is_empty() and tuner.export_text() == "", "đặt lại: xoá hết ghi đè")
	_check(not tuner.panel.visible, "bộ chỉnh ẩn khi chưa bật debug")
	G.anim_debug = true
	for i in 3:
		vm.update(DT, 0.0, true)
	await process_frame
	_check(tuner.panel.visible, "bật anim_debug: bộ chỉnh hiện")
	_check(G.anim_debug_samples.size() >= 6 and G.anim_debug_samples.size() <= 480, "đường cong kiếm có mẫu (%d giá trị, giới hạn 480)" % G.anim_debug_samples.size())
	for i in 400:
		vm.update(DT, 0.0, true)
	_check(G.anim_debug_samples.size() <= 480, "bộ đệm đường cong không phình quá 480")
	G.anim_debug = false
	await process_frame
	_check(not tuner.panel.visible, "tắt anim_debug: bộ chỉnh ẩn")

	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
