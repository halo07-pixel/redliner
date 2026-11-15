extends SceneTree
## Test headless M7.3: hoạt ảnh chiến đấu chồng lên di chuyển (swing/shoot/parry/hurt/stagger/die).
##   timeout 120 godot --headless --path . -s tools/tests/test_combat_animation.gd

var failures: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


## Bot dùng model glTF (overlay lưu ở `_overlay`), hình nhân khối dùng animator.
func _ov(m: Node3D) -> String:
	return String(m.animator.overlay.get("name", "")) if m.get("animator") != null else String(m.get("_overlay"))


func _ov_dur(m: Node3D) -> float:
	return float(m.animator.overlay["dur"]) if m.get("animator") != null else float(m.get("_overlay_left"))


func _initialize() -> void:
	_run()


func _make(kind: String) -> Node3D:
	var m: Node3D = load("res://scripts/mannequin.gd").new()
	m.kind = kind
	root.add_child(m)
	return m


func _run() -> void:
	await process_frame
	var m: Node3D = _make("swordsman")
	await process_frame
	var an = m.animator
	var d: Dictionary = {"windup": 0.3, "active": 0.12, "recovery": 0.3}
	var dur: float = 0.72

	# --- Tư thế overlay
	var sw0: Dictionary = an.overlay_pose("swing", 0.0, dur, d)
	var sw_wu: Dictionary = an.overlay_pose("swing", 0.299, dur, d)
	var sw_ac: Dictionary = an.overlay_pose("swing", 0.419, dur, d)
	_check(sw_wu["shoulder_r"].x > 120.0, "swing: cuối windup giơ kiếm lên cao")
	_check(sw_ac["shoulder_r"].x < 0.0, "swing: cuối active đã chém xuống")
	_check(sw_wu["spine"].y > 0.0 and sw_ac["spine"].y < 0.0, "swing: thân xoay ngược chiều giữa windup và active")
	_check(absf(sw0["shoulder_r"].x - (-15.0)) < 1.0, "swing: bắt đầu từ tư thế cầm kiếm")
	# Khớp thời lượng với tham số Signal: đổi windup -> mốc giơ kiếm đổi theo
	var fast: Dictionary = an.overlay_pose("swing", 0.15, 0.3 + 0.12 + 0.3, {"windup": 0.15, "active": 0.12, "recovery": 0.3})
	_check(absf(fast["shoulder_r"].x - 150.0) < 1.0, "swing: windup 0.15s đạt đỉnh đúng lúc 0.15s")
	var sh0: Dictionary = an.overlay_pose("shoot", 0.0, 0.25, {})
	var sh1: Dictionary = an.overlay_pose("shoot", 0.25, 0.25, {})
	_check(sh0["shoulder_r"].x > sh1["shoulder_r"].x + 10.0, "shoot: giật rồi hạ về tư thế nhắm")
	_check(an.overlay_pose("parry", 0.1, 0.28, {})["elbow_r"].x > 90.0, "parry: kiếm chắn ngang (khuỷu gập)")
	var h_back: Dictionary = an.overlay_pose("hurt", 0.125, 0.25, {"direction": Vector3(0, 0, 1)})
	var h_left: Dictionary = an.overlay_pose("hurt", 0.125, 0.25, {"direction": Vector3(1, 0, 0)})
	_check(h_back["spine"].x > 15.0, "hurt: giật ngửa khi bị đánh từ trước")
	_check(absf(h_left["spine"].z) > 5.0 and absf(h_back["spine"].z) < 1.0, "hurt: nghiêng theo hướng đòn")
	_check(an.overlay_pose("stagger", 0.3, 1.0, {})["head"].x < -20.0, "stagger: cúi đầu")
	var die_end: Dictionary = an.overlay_pose("die", 0.45, 0.45, {})
	_check(die_end["hips"].x > 80.0 and die_end["hips_y"].x < -0.6, "die: ngã ngửa, hông hạ xuống")

	# --- Trọng số / ưu tiên
	m.play("swing", 0.72, d)
	_check(an.overlay_weight() == 0.0, "overlay bắt đầu với trọng số 0 (pha trộn vào)")
	m.animate(0.03, 6.0, true, 0.0)
	var w1: float = an.overlay_weight()
	m.animate(0.05, 6.0, true, 0.0)
	_check(w1 > 0.0 and an.overlay_weight() == 1.0, "trọng số tăng dần rồi đạt 1")
	m.play("stagger", 1.0)
	m.play("hurt", 0.25, {})
	_check(an.overlay["name"] == "stagger", "hurt không ngắt stagger (ưu tiên cao hơn)")
	m.play("die", 0.45)
	m.play("stagger", 1.0)
	_check(an.overlay["name"] == "die", "không gì ngắt die")
	m.clear_overlay()

	# --- Chân vẫn chạy khi chém (overlay chỉ điều khiển tay/thân)
	var m2: Node3D = _make("swordsman")
	await process_frame
	m2.play("swing", 0.72, d)
	var lo: float = 1e9
	var hi: float = -1e9
	var sh_mid: float = -15.0
	for i in 60:
		m2.animate(1.0 / 60.0, 7.0, true, 0.0)
		var hr: float = m2.get_joint("hip_r").rotation_degrees.x
		lo = minf(lo, hr)
		hi = maxf(hi, hr)
		if i == 29:
			sh_mid = m2.get_joint("shoulder_r").rotation_degrees.x
	_check(hi - lo > 20.0, "đang chém: chân sau vẫn dao động theo nhịp chạy (biên độ %.1f độ)" % (hi - lo))
	_check(absf(sh_mid - (-15.0)) > 10.0, "đang chém: tay phải do overlay điều khiển")

	# --- Chém có chuẩn bị: hạ người ở windup, lao tới ở active
	var lg: Node3D = _make("swordsman")
	await process_frame
	lg.play("swing", 0.72, d)
	var min_y: float = 1.0
	var min_z: float = 0.0
	for i in 50:
		lg.animate(1.0 / 60.0, 0.0, true, 0.0)
		min_y = minf(min_y, lg.get_joint("hips").position.y)
		min_z = minf(min_z, lg.get_joint("hips").position.z)
	_check(min_y < 0.92 - 0.06, "chém: hạ người dồn lực (hông xuống %.3f)" % min_y)
	_check(min_z < -0.05, "chém: lao tới phía trước (%.3f m)" % min_z)

	# --- Hết overlay -> về tư thế nền, không giật
	var m3: Node3D = _make("swordsman")
	await process_frame
	m3.play("hurt", 0.25, {"direction": Vector3(0, 0, 1)})
	var maxstep: float = 0.0
	for i in 120:
		var before: Dictionary = {}
		for jn in m3.JOINT_NAMES:
			before[jn] = m3.get_joint(jn).rotation_degrees
		m3.animate(1.0 / 60.0, 0.0, true, 0.0)
		for jn in m3.JOINT_NAMES:
			var dd: Vector3 = (m3.get_joint(jn).rotation_degrees - before[jn]).abs()
			maxstep = maxf(maxstep, maxf(dd.x, maxf(dd.y, dd.z)))
	_check(maxstep < 20.0, "overlay vào/ra không giật (bước lớn nhất %.1f độ/frame)" % maxstep)
	_check(m3.animator.overlay.is_empty(), "overlay tự kết thúc sau thời lượng")
	_check(absf(m3.get_joint("spine").rotation_degrees.x) < 3.0, "về tư thế đứng sau khi hết hurt")

	# --- Chết: nằm lại, vẫn fade_out được
	var m4: Node3D = _make("elite")
	await process_frame
	m4.play("die", 0.45)
	for i in 60:
		m4.animate(1.0 / 60.0, 0.0, true, 0.0)
	_check(m4.get_joint("hips").rotation_degrees.x > 80.0 and not m4.animator.overlay.is_empty(), "die: giữ tư thế nằm sau khi hết thời lượng")
	m4.fade_out(0.1)
	var first: MeshInstance3D = m4.find_children("*", "MeshInstance3D", true, false)[0]
	_check(first.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "die: fade_out vẫn hoạt động")

	# --- Nối Signal thật
	var b = load("res://scripts/bot.gd").new()
	b.setup("swordsman", 1)
	root.add_child(b)
	await process_frame
	b.melee.swing_started.emit(0.3, 0.12, 0.3)
	_check(_ov(b.mannequin) == "swing" and absf(_ov_dur(b.mannequin) - 0.72) < 0.001, "bot: swing_started -> overlay swing đúng thời lượng")
	b.melee.staggered.emit(1.0)
	_check(_ov(b.mannequin) == "stagger", "bot: staggered -> overlay stagger")
	b.parry.parry_started.emit()
	_check(_ov(b.mannequin) == "stagger", "bot: stagger không bị parry ngắt")
	var g = load("res://scripts/bot.gd").new()
	g.setup("gunner", 1)
	root.add_child(g)
	await process_frame
	g.parry.parry_missed.emit()
	_check(_ov(g.mannequin) == "parry_miss", "bot: parry_missed -> overlay parry_miss")
	g.hurtbox.hurt.emit({"direction": Vector3(0, 0, -1), "damage": 1.0}, 10.0)
	_check(_ov(g.mannequin) == "hurt", "bot: hurt -> overlay hurt")
	g.shoot_at(Vector3(0, 1, -10))
	_check(_ov(g.mannequin) == "shoot", "bot xạ thủ: bắn -> overlay shoot")
	g._on_died()
	_check(_ov(g.mannequin) == "die", "bot: chết -> overlay die")

	var p: Node3D = load("res://scenes/player.tscn").instantiate()
	root.add_child(p)
	await process_frame
	p.melee.swing_started.emit(0.2, 0.1, 0.2)
	_check(p.body_view.animator.overlay.get("name", "") == "swing", "người chơi: chém -> thân chạy overlay swing")
	p.parry.parry_started.emit()
	_check(p.body_view.animator.overlay.get("name", "") == "parry", "người chơi: parry -> overlay parry")
	p.combat.shot_fired.emit(Vector3.ZERO, Vector3.ONE)
	_check(p.body_view.animator.overlay.get("name", "") == "shoot", "người chơi: bắn -> overlay shoot")
	p._on_died()
	_check(p.body_view.animator.overlay.get("name", "") == "die", "người chơi: chết -> overlay die")
	p.respawn(Vector3.ZERO)
	_check(p.body_view.animator.overlay.is_empty(), "người chơi: hồi sinh xóa overlay")
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
