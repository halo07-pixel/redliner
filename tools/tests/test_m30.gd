extends SceneTree
## M30: chuyển động bot theo hướng và tình huống - chạy tiến/lùi/ngang, quay người, núp, vault, ngã theo hướng đòn.
##   timeout 250 godot --headless --path . -s tools/tests/test_m30.gd

const DT: float = 1.0 / 60.0
var failures: int = 0
var world: Node3D
var player


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


func _mq(kind: String = "swordsman") -> Node3D:
	var m = load("res://scripts/mannequin.gd").new()
	m.kind = kind
	root.add_child(m)
	return m


func _joint(m: Node3D, j: String) -> Vector3:
	return (m.get_joint(j) as Node3D).rotation_degrees


## Chạy `frames` khung ở tốc độ 6 m/s theo hướng cục bộ `dir`, trả về mannequin.
func _run_dir(dir: Vector2, frames: int, turn: float = 0.0) -> Node3D:
	var m := _mq()
	m.set_motion(dir, turn)
	for i in frames:
		m.animate(DT, 6.0, true, 0.0)
	return m


func _run() -> void:
	await process_frame
	var G: Node = root.get_node("Global")
	G.reduced_fx = false

	print("[mặc định: đi thẳng như cũ]")
	var a := _mq()
	var b := _mq()
	b.set_motion(Vector2(0.0, 1.0), 0.0)
	for i in 60:
		a.animate(DT, 6.0, true, 0.0)
		b.animate(DT, 6.0, true, 0.0)
	_check(_joint(a, "hip_l").is_equal_approx(_joint(b, "hip_l")), "không gọi set_motion = đi thẳng")

	print("[chạy tiến / lùi / ngang khác nhau]")
	var fw := _run_dir(Vector2(0, 1), 40)
	var bk := _run_dir(Vector2(0, -1), 40)
	var rs := _run_dir(Vector2(1, 0), 40)
	var ls := _run_dir(Vector2(-1, 0), 40)
	_check(_joint(fw, "spine").x < _joint(bk, "spine").x - 3.0, "lùi ngả người ra sau (tiến %.1f, lùi %.1f độ)" % [_joint(fw, "spine").x, _joint(bk, "spine").x])
	_check(absf(_joint(rs, "hips").y - _joint(fw, "hips").y) > 5.0, "đi ngang xoay hông về hướng đi")
	_check(_joint(rs, "hips").y * _joint(ls, "hips").y < 0.0, "phải và trái xoay hông ngược nhau")
	_check(_joint(rs, "spine").y * _joint(rs, "hips").y < 0.0, "vai giữ hướng nhìn (ngược hông)")
	var ra := absf(_joint(rs, "hip_l").z) + absf(_joint(rs, "hip_r").z)
	var fa := absf(_joint(fw, "hip_l").z) + absf(_joint(fw, "hip_r").z)
	_check(ra > fa + 0.5, "chân bắt chéo khi đi ngang (%.1f so với %.1f)" % [ra, fa])
	var ph0: float = fw.animator.phase
	var pb0: float = bk.animator.phase
	for i in 4:
		fw.animate(DT, 6.0, true, 0.0)
		bk.animate(DT, 6.0, true, 0.0)
	var dpf: float = wrapf(fw.animator.phase - ph0, -PI, PI)
	var dpb: float = wrapf(bk.animator.phase - pb0, -PI, PI)
	_check(dpf > 0.0 and dpb < 0.0, "bước chân đổi chiều khi lùi (tiến %+.2f, lùi %+.2f rad)" % [dpf, dpb])
	var mx_f: float = 0.0
	var mx_b: float = 0.0
	for i in 60:
		fw.animate(DT, 6.0, true, 0.0)
		bk.animate(DT, 6.0, true, 0.0)
		mx_f = maxf(mx_f, absf(_joint(fw, "hip_l").x))
		mx_b = maxf(mx_b, absf(_joint(bk, "hip_l").x))
	_check(mx_b < mx_f * 0.95, "lùi bước ngắn hơn (%.1f so với %.1f độ)" % [mx_b, mx_f])

	print("[quay người: thân dẫn trước, đứng yên cũng quay]")
	var t0 := _mq()
	var t1 := _mq()
	t1.set_motion(Vector2(0, 1), 360.0)
	for i in 30:
		t0.animate(DT, 0.0, true, 0.0)
		t1.animate(DT, 0.0, true, 0.0)
	_check(absf(_joint(t1, "spine").y - _joint(t0, "spine").y) > 5.0, "quay nhanh: thân lệch dẫn %.1f độ" % (_joint(t1, "spine").y - _joint(t0, "spine").y))
	var t2 := _mq()
	t2.set_motion(Vector2(0, 1), -360.0)
	for i in 30:
		t2.animate(DT, 0.0, true, 0.0)
	_check(_joint(t1, "spine").y * _joint(t2, "spine").y < 0.0, "quay trái và phải dẫn ngược chiều")
	t1.set_motion(Vector2(0, 1), 0.0)
	for i in 60:
		t1.animate(DT, 0.0, true, 0.0)
	_check(absf(_joint(t1, "spine").y - _joint(t0, "spine").y) < 3.0, "hết quay: thân trở về")

	print("[núp / vault đổi tư thế rồi về]")
	var idle := _mq()
	for i in 40:
		idle.animate(DT, 0.0, true, 0.0)
	var cv := _mq()
	for i in 40:
		cv.animate(DT, 0.0, true, 0.0, "cover")
	_check(cv.animator.anim_state == "cover", "trạng thái núp")
	_check(cv.animator.pick_state(6.0, true, "cover") == "run", "đang chạy thì không ở trạng thái núp")
	_check(_joint(cv, "knee_l").x < _joint(idle, "knee_l").x - 40.0, "núp: gối gập sâu (%.0f độ)" % _joint(cv, "knee_l").x)
	var peek0: float = cv.animator.target_pose("cover", 0.0, 0.0, 0.0, 1.0, 0.0)["hips_y"].x
	cv.play("shoot", 0.4, {})
	for i in 12:
		cv.animate(DT, 0.0, true, 0.0, "cover")
	var peek1: float = cv.animator.target_pose("cover", 0.0, 0.0, 0.0, 1.0, 0.0)["hips_y"].x
	_check(peek1 > peek0 + 0.05, "ló ra khi bắn (hông %.2f -> %.2f m)" % [peek0, peek1])
	for i in 120:
		cv.animate(DT, 0.0, true, 0.0)
	_check(absf(_joint(cv, "knee_l").x - _joint(idle, "knee_l").x) < 3.0, "hết núp: đứng dậy")
	var vl := _mq()
	for i in 30:
		vl.animate(DT, 3.0, false, 4.0, "vault")
	_check(vl.animator.anim_state == "vault" and _joint(vl, "spine").x < -15.0, "vault: gập thân")

	print("[ngã theo hướng đòn cuối]")
	var falls: Dictionary = {}
	for d in [["trước", Vector3(0, 0, 1)], ["sau", Vector3(0, 0, -1)], ["phải", Vector3(1, 0, 0)], ["trái", Vector3(-1, 0, 0)]]:
		var m := _mq()
		m.play("die", 1.0, {"direction": d[1], "zone": "torso"})
		for i in 80:
			m.animate(DT, 0.0, true, 0.0)
		falls[d[0]] = _joint(m, "hips")
	_check(falls["trước"].x > 50.0 and falls["sau"].x < -50.0, "trúng từ trước ngã ngửa, từ sau ngã sấp (%.0f / %.0f độ)" % [falls["trước"].x, falls["sau"].x])
	_check(falls["phải"].z * falls["trái"].z < 0.0 and absf(falls["phải"].z) > 30.0, "trúng từ bên thì ngã nghiêng, trái/phải ngược nhau")
	var dh := _mq()
	dh.play("die", 1.0, {"direction": Vector3(0, 0, 1), "zone": "head"})
	var dt_ := _mq()
	dt_.play("die", 1.0, {"direction": Vector3(0, 0, 1), "zone": "torso"})
	var dl := _mq()
	dl.play("die", 1.0, {"direction": Vector3(0, 0, 1), "zone": "legs"})
	for i in 80:
		dh.animate(DT, 0.0, true, 0.0)
		dt_.animate(DT, 0.0, true, 0.0)
		dl.animate(DT, 0.0, true, 0.0)
	_check(_joint(dh, "head").x < _joint(dt_, "head").x - 10.0, "trúng đầu: cổ hất mạnh hơn")
	_check(_joint(dl, "knee_l").x < _joint(dt_, "knee_l").x - 20.0, "trúng chân: sụp gối")
	var d0 := _mq()
	d0.play("die", 1.0)
	for i in 80:
		d0.animate(DT, 0.0, true, 0.0)
	_check(_joint(d0, "hips").x > 50.0, "không có dữ liệu: ngã ngửa như cũ")

	print("[không nhảy tư thế, hữu hạn, không rò node]")
	var rg := _mq()
	await process_frame
	var nodes0: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var rng := RandomNumberGenerator.new()
	rng.seed = 30
	var prev: Dictionary = {}
	var worst: float = 0.0
	var finite: bool = true
	var names: Array = ["", "cover", "vault", "slide"]
	var cur_state: String = ""
	for f in 1500:
		if rng.randi() % 25 == 0:
			cur_state = names[rng.randi() % names.size()]
		if rng.randi() % 20 == 0:
			rg.set_motion(Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)), rng.randf_range(-500, 500))
		if rng.randi() % 60 == 0:
			rg.play(["shoot", "swing", "hurt"][rng.randi() % 3], 0.3, {"windup": 0.2, "active": 0.1, "recovery": 0.2, "direction": Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))})
		rg.animate(DT, rng.randf_range(0.0, 7.0), rng.randf() > 0.1, rng.randf_range(-3, 3), cur_state)
		for j in ["hips", "spine", "hip_l", "knee_l"]:
			var r: Vector3 = _joint(rg, j)
			finite = finite and is_finite(r.x) and is_finite(r.y) and is_finite(r.z)
			if prev.has(j):
				worst = maxf(worst, maxf(absf(wrapf(r.x - prev[j].x, -180, 180)), maxf(absf(wrapf(r.y - prev[j].y, -180, 180)), absf(wrapf(r.z - prev[j].z, -180, 180)))))
			prev[j] = r
	_check(finite, "1500 khung ngẫu nhiên: giá trị hữu hạn")
	_check(worst < 40.0, "góc khớp nhảy tối đa mỗi khung %.1f độ (lò xo, không giật cục)" % worst)
	_check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == nodes0, "không rò node")

	print("[bot thật: nhận hướng đi cục bộ và trạng thái]")
	world = Node3D.new()
	root.add_child(world)
	var fl := StaticBody3D.new()
	fl.collision_layer = G.L_WORLD
	var fc := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(80, 1, 80)
	fc.shape = fs
	fl.add_child(fc)
	fl.position = Vector3(0, -0.5, 0)
	world.add_child(fl)
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	var bot = load("res://scripts/bot.gd").new()
	bot.setup("swordsman", 1)
	bot.position = Vector3(0, 0.1, -20)
	world.add_child(bot)
	await _frames(60)
	var md: Vector2 = bot.mannequin.animator.move_dir
	_check(bot.has_method("_animate_body"), "bot có _animate_body")
	_check(md.y > 0.3, "bot lao vào người chơi: hướng đi cục bộ là tiến (%.2f, %.2f)" % [md.x, md.y])
	bot._vault_push_t = 0.3
	await _frames(3)
	_check(bot.mannequin.animator.anim_state == "vault", "bot đang vault -> dáng vault")
	bot._vault_push_t = 0.0
	bot._cover_pt = bot.global_position
	bot._cover_t = 2.0
	bot.velocity = Vector3.ZERO
	await _frames(20)
	_check(bot.mannequin.animator.anim_state in ["cover", "run"], "bot ở điểm nấp: dáng núp khi đứng yên (%s)" % bot.mannequin.animator.anim_state)

	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
