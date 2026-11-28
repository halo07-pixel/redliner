extends SceneTree
## M47 "Hoạt ảnh Blender cho bot low poly": thư viện clip dựng bằng keyframe trong Blender (tools/blender/make_clips.py -> clips.glb) nạp được,
## clip lặp khép vòng, góc Euler liên tục (vai > 90° không lật), RigAnimator dùng clip cho chạy/đứng và overlay chém/bắn/choáng,
## thân GodoDude vẫn dùng thư viện CC0 cũ, thiếu clip thì rơi về hoạt ảnh bằng code.
##   timeout 150 godot --headless --path . -s tools/tests/test_m47.gd

var failures: int = 0
var G
var L
var Anim


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _max_abs_x(clip: Dictionary, joint: String) -> float:
	var m: float = 0.0
	for f in clip["eul"]:
		m = maxf(m, absf((f[joint] as Vector3).x))
	return m


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	L = load("res://scripts/lowpoly_clips.gd")
	Anim = load("res://scripts/rig_animator.gd")
	print("[Thư viện clip]")
	_check(FileAccess.file_exists("res://assets/animations/lowpoly/clips.glb") and L.available(), "clips.glb nạp được")
	var want: Array = ["Sword_Idle", "Pistol_Idle", "Crouch_Idle", "Walk", "Jog_Fwd", "Sprint", "Slash", "Shoot", "Stagger"]
	for n in want:
		_check(L.clip_names().has(n), "có clip %s" % n)
	for n in L.LOOPING:
		var c: Dictionary = L.get_clip(n)
		var a: Dictionary = L.sample(c, 0.0)
		var b: Dictionary = L.sample(c, float(c["length"]) - 0.0001)
		var worst: float = 0.0
		for j in L.JOINTS:
			worst = maxf(worst, rad_to_deg((a["rot"][j] as Quaternion).angle_to(b["rot"][j] as Quaternion)))
		_check(c["loop"] and worst < 6.0, "%s: lặp khép vòng (lệch đầu-cuối %.2f°)" % [n, worst])
	_check(absf(float(L.get_clip("Walk")["length"]) - 1.0) < 0.05 and absf(float(L.get_clip("Sprint")["length"]) - 0.5) < 0.05, "độ dài Walk 1.0 s, Sprint 0.5 s")
	var sl: Dictionary = L.get_clip("Slash")
	_check(not sl["loop"] and absf(float(sl["length"]) - 1.3) < 0.05, "Slash chạy một lần ~1.3 s")
	var s0: Dictionary = L.sample(sl, 0.0)
	var s1: Dictionary = L.sample(sl, float(L.SLASH["windup"]))
	var s2: Dictionary = L.sample(sl, float(L.SLASH["windup"]) + float(L.SLASH["active"]))
	_check((s1["eul"]["shoulder_r"] as Vector3).x > 140.0, "Slash: hết lấy đà kiếm giơ cao (%.0f°, không bị lật góc)" % (s1["eul"]["shoulder_r"] as Vector3).x)
	_check((s2["eul"]["shoulder_r"] as Vector3).x < 0.0 and float(s2["hips_z"]) < -0.1, "Slash: cuối cú chém tay hạ xuống, hông lao tới")
	_check((s0["eul"]["shoulder_r"] as Vector3).distance_to(Vector3(-15, 0, 0)) < 1.0, "Slash: bắt đầu từ thế sẵn sàng")
	var hips: Array = []
	for n in ["Walk", "Jog_Fwd", "Sprint"]:
		hips.append(_max_abs_x(L.get_clip(n), "hip_l"))
	_check(hips[0] < hips[1] and hips[1] < hips[2], "biên độ chân tăng dần Walk < Jog < Sprint (%s)" % str(hips))
	_check(float(L.sample(L.get_clip("Crouch_Idle"), 0.0)["hips_y"]) < -0.2, "Crouch_Idle hạ hông")

	print("[Clip overlay trong RigAnimator]")
	var arena = load("res://tools/tests/fixtures/flat_arena.gd").new()
	arena.bake_nav = false
	root.add_child(arena)
	await _frames(3)
	var b = load("res://scripts/bot.gd").new()
	b.setup("swordsman", 1)
	b.position = Vector3(0.0, 0.2, 0.0)
	arena.add_child(b)
	await _frames(3)
	var an = b.mannequin.animator
	_check(an.clip_lib == L and an.clips_enabled, "bot low poly dùng thư viện clip Blender")
	var op: Dictionary = an.clip_overlay_pose("swing", 0.3, 0.8, {"windup": 0.3, "active": 0.1, "recovery": 0.4})
	_check(not op.is_empty() and (op["shoulder_r"] as Vector3).x > 140.0, "overlay swing lấy từ clip (vai phải %.0f° cuối lấy đà)" % (op["shoulder_r"] as Vector3).x)
	_check(op.has("+knee_l") and not op.has("knee_l") and op.has("+hips_y"), "chân/hông cộng thêm, tay/thân thay thế")
	var op2: Dictionary = an.clip_overlay_pose("swing", 0.3 + 0.1, 0.8, {"windup": 0.3, "active": 0.1, "recovery": 0.4})
	_check((op2["shoulder_r"] as Vector3).x < 0.0, "hết pha chém tay đã hạ (%.0f°)" % (op2["shoulder_r"] as Vector3).x)
	_check(not an.clip_overlay_pose("shoot", 0.1, 0.3, {}).is_empty() and not an.clip_overlay_pose("stagger", 0.2, 1.0, {}).is_empty(), "shoot và stagger có clip")
	_check(an.clip_overlay_pose("hurt", 0.1, 0.4, {}).is_empty() and an.clip_overlay_pose("die", 0.1, 1.0, {}).is_empty(), "hurt/die vẫn do code (phụ thuộc hướng đòn)")
	b.mannequin.play("swing", 0.8, {"windup": 0.3, "active": 0.1, "recovery": 0.4})
	var raised: float = 0.0
	for i in 24:
		b.mannequin.animate(1.0 / 60.0, 0.0, true, 0.0)
		raised = maxf(raised, (b.mannequin.get_joint("shoulder_r") as Node3D).rotation_degrees.x)
	_check(raised > 90.0, "khớp vai phải thật sự giơ lên khi chém (%.0f°)" % raised)
	an.anim_state = "run"
	an._md_s = Vector2(0.0, 1.0)
	var run_pick: Array = an._pick_clip(5.0)
	_check(String(run_pick[0]) == "Jog_Fwd", "chạy 5 m/s chọn clip Jog_Fwd")
	an.clips_enabled = false
	_check(an.clip_overlay_pose("swing", 0.1, 0.8, {"windup": 0.3, "active": 0.1, "recovery": 0.4}).is_empty(), "tắt clip -> overlay rơi về code")
	an.clips_enabled = true
	b.mannequin.play("swing", 0.5, {"windup": 0.2, "active": 0.1, "recovery": 0.2})
	b.mannequin.animate(1.0 / 60.0, 0.0, true, 0.0)
	b.mannequin.play("hurt", 0.4, {"direction": Vector3(0, 0, 1), "zone": "torso"})
	b.mannequin.animate(1.0 / 60.0, 0.0, true, 0.0)
	b.mannequin.play("die", 1.0, {"direction": Vector3(0, 0, 1), "zone": "head"})
	for i in 10:
		b.mannequin.animate(1.0 / 60.0, 0.0, true, 0.0)
	_check(true, "swing -> hurt -> die không lỗi")
	b.queue_free()
	var ti = load("res://scripts/titan.gd").new()
	ti.setup("titan", 1)
	ti.position = Vector3(0.0, 0.2, 0.0)
	arena.add_child(ti)
	await _frames(3)
	_check(ti.mannequin.animator.clip_lib == L and ti.mannequin.animator.clips_enabled, "Titan cũng dùng clip Blender")
	ti.queue_free()
	arena.queue_free()

	print("[Thân GodoDude giữ thư viện CC0]")
	var ual: Script = load("res://scripts/clip_lib.gd")
	var dummy = load("res://scripts/mannequin_gltf.gd").new()
	dummy.kind = "swordsman"
	root.add_child(dummy)
	await _frames(2)
	if dummy.animator != null:
		_check(dummy.animator.clip_lib == ual, "MannequinGltf vẫn dùng ClipLib (UAL)")
	dummy.queue_free()
	print("")
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
