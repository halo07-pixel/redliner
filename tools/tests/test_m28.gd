extends SceneTree
## M28: cảm giác parry - hitstop cấu hình, camera giật theo hướng đòn, tia lửa có hướng, âm thanh mới, bot báo đòn, số parry/phạt không đổi.
##   timeout 200 godot --headless --path . -s tools/tests/test_m28.gd

var failures: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var G: Node = root.get_node("Global")
	var S: Node = root.get_node("Sfx")

	print("[số parry/phạt KHÔNG đổi]")
	var C: Dictionary = G.COMBAT
	_check(is_equal_approx(float(C["parry_window"]), 0.18), "parry_window = 0.18")
	_check(is_equal_approx(float(C["parry_miss_cooldown"]), 0.8), "parry_miss_cooldown = 0.8")
	_check(is_equal_approx(float(C["reflect_damage_mult"]), 2.5), "reflect_damage_mult = 2.5")
	_check(is_equal_approx(float(C["reflect_speed_mult"]), 1.3), "reflect_speed_mult = 1.3")

	print("[hitstop parry trong khoảng cấu hình]")
	G.reduced_fx = false
	var hm: float = G.parry_hitstop_time("melee")
	var hb: float = G.parry_hitstop_time("bullet")
	_check(hm >= 0.06 and hm <= 0.09, "đỡ kiếm khựng %.3f s trong 60-90 ms" % hm)
	_check(hb > 0.0 and hb < hm, "phản đạn khựng ngắn hơn (%.3f s)" % hb)
	G.reduced_fx = true
	_check(is_equal_approx(G.parry_hitstop_time("melee"), hm * float(G.ANIM["pf_reduced_hitstop"])), "giảm hiệu ứng: khựng giảm theo hệ số")
	G.reduced_fx = false
	for k in ["pf_hitstop", "pf_hitstop_bullet", "pf_cam_kick", "pf_fov_punch", "pf_spark_cone", "pf_flash_energy", "pf_tell_lean", "pf_tell_time", "pf_miss_stumble"]:
		_check(G.TUNABLE_ANIM.has(k) and G.ANIM.has(k), "%s có trong bộ chỉnh F4" % k)
	G.tune["a.pf_hitstop"] = 0.07
	_check(is_equal_approx(G.parry_hitstop_time("melee"), 0.07), "chỉnh F4 áp dụng cho hitstop")
	G.tune.clear()

	print("[camera giật theo hướng đòn]")
	var fl := StaticBody3D.new()
	fl.collision_layer = G.L_WORLD
	var fc := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(100, 1, 100)
	fc.shape = fs
	fl.add_child(fc)
	fl.position = Vector3(0, -0.5, 0)
	root.add_child(fl)
	var player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	for i in 4:
		await physics_frame
	G.settings["cam_fx"] = 1.0
	player.parry_react(Vector3(1, 0, 0))   # đòn bay sang +X (từ bên trái người chơi, người chơi nhìn -Z)
	_check(player._pk_rot.x > 1.0, "pitch giật %.2f độ" % player._pk_rot.x)
	var roll_a: float = player._pk_rot.y
	_check(absf(roll_a) > 0.5, "roll giật %.2f độ" % roll_a)
	player._pk_rot = Vector2.ZERO
	player.parry_react(Vector3(-1, 0, 0))
	_check(player._pk_rot.y * roll_a < 0.0, "đòn từ phía ngược lại thì giật roll ngược chiều")
	_check(player._pk_fov > 1.0, "FOV nảy %.2f độ" % player._pk_fov)
	var peak_fov: float = player._pk_fov
	for i in 90:
		await process_frame
	_check(absf(player._pk_rot.x) < 0.1 and absf(player._pk_fov) < 0.1, "tắt dần về 0 sau ~1.5 s")
	_check(absf(player.camera.rotation.x) < 0.01 and peak_fov > 0.0, "camera trở lại thẳng")
	G.settings["cam_fx"] = 0.0
	player._pk_rot = Vector2.ZERO
	player._pk_fov = 0.0
	player.parry_react(Vector3(1, 0, 0))
	_check(player._pk_rot == Vector2.ZERO and player._pk_fov == 0.0, "cam_fx = 0: không giật")
	G.settings["cam_fx"] = 1.0
	G.reduced_fx = true
	player.parry_react(Vector3(1, 0, 0))
	_check(player._pk_rot == Vector2.ZERO, "giảm hiệu ứng: không giật")
	G.reduced_fx = false

	print("[tia lửa theo hướng]")
	var holder := Node3D.new()
	root.add_child(holder)
	var p0: CPUParticles3D = load("res://scripts/fx.gd").sparks(holder, Vector3.ZERO, Color.WHITE)
	_check(p0.spread == 180.0 and p0.direction == Vector3.UP, "mặc định phun mọi hướng như cũ")
	var p1: CPUParticles3D = load("res://scripts/fx.gd").sparks(holder, Vector3.ZERO, Color.WHITE, Vector3(0, 0, 1), 50.0)
	_check(p1.direction == Vector3(0, 0, 1) and p1.spread == 50.0, "có hướng + độ loe")

	print("[âm thanh mới]")
	for n in ["parry", "parry_low", "parry_miss", "tell"]:
		_check(G.SOUNDS.has(n) and S._streams.has(n), "âm '%s' đã đăng ký và có stream" % n)

	print("[bot báo đòn]")
	var mq = load("res://scripts/mannequin.gd").new()
	mq.kind = "swordsman"
	root.add_child(mq)
	await process_frame
	var data := {"windup": 0.5, "active": 0.12, "recovery": 0.3}
	mq.play("swing", 0.92, data)
	var tt: float = float(G.ANIM["pf_tell_time"])
	var tell_pose_a: float = 0.0
	var steps: int = int(tt * 0.5 * 60.0)
	for i in steps:
		mq.animate(1.0 / 60.0, 0.0, true, 0.0)
	tell_pose_a = (mq.get_joint("spine") as Node3D).rotation_degrees.x
	G.tune["a.pf_tell_lean"] = 0.0
	var mq2 = load("res://scripts/mannequin.gd").new()
	mq2.kind = "swordsman"
	root.add_child(mq2)
	await process_frame
	mq2.play("swing", 0.92, data)
	for i in steps:
		mq2.animate(1.0 / 60.0, 0.0, true, 0.0)
	var tell_pose_b: float = (mq2.get_joint("spine") as Node3D).rotation_degrees.x
	G.tune.clear()
	_check(absf(tell_pose_a - tell_pose_b) > 1.0, "gồng báo đòn đổi tư thế thân (%.1f so với %.1f độ)" % [tell_pose_a, tell_pose_b])
	mq.flash_weapon(0.1)
	var ov: int = 0
	for c in mq.weapon.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_overlay != null:
			ov += 1
	_check(ov > 0, "chớp sáng vũ khí đặt overlay (%d mesh)" % ov)
	for i in 30:
		await process_frame
	ov = 0
	for c in mq.weapon.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_overlay != null:
			ov += 1
	_check(ov == 0, "overlay được gỡ sau khi chớp")
	G.reduced_fx = true
	mq2.flash_weapon(0.1)
	var ov2: int = 0
	for c in mq2.weapon.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_overlay != null:
			ov2 += 1
	_check(ov2 == 0, "giảm hiệu ứng: không chớp")
	G.reduced_fx = false

	print("[parry hụt: loạng choạng rõ hơn, thời gian phạt không đổi]")
	var mq3 = load("res://scripts/mannequin.gd").new()
	mq3.kind = "swordsman"
	root.add_child(mq3)
	await process_frame
	mq3.play("parry_miss", float(G.ANIM["parry_miss_time"]))
	for i in 12:
		mq3.animate(1.0 / 60.0, 0.0, true, 0.0)
	var m_hi: float = absf((mq3.get_joint("spine") as Node3D).rotation_degrees.x)
	G.tune["a.pf_miss_stumble"] = 1.0
	var mq4 = load("res://scripts/mannequin.gd").new()
	mq4.kind = "swordsman"
	root.add_child(mq4)
	await process_frame
	mq4.play("parry_miss", float(G.ANIM["parry_miss_time"]))
	for i in 12:
		mq4.animate(1.0 / 60.0, 0.0, true, 0.0)
	var m_lo: float = absf((mq4.get_joint("spine") as Node3D).rotation_degrees.x)
	G.tune.clear()
	_check(m_hi > m_lo + 0.5, "biên độ loạng choạng lớn hơn (%.1f so với %.1f độ)" % [m_hi, m_lo])
	_check(is_equal_approx(float(C["parry_miss_cooldown"]), 0.8), "phạt vẫn 0.8 s")

	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
