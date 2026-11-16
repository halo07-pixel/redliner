extends SceneTree
## Test headless M9: slide boost/hop, stamina dash, grapple redirect, ground slam, recoil.
##   timeout 180 godot --headless --path . -s tools/tests/test_m9_movement.gd

var failures: int = 0
var player
var world: Node3D


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _box(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = Global.L_WORLD
	b.position = pos
	b.rotation_degrees = rot
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	world.add_child(b)


func _reset(pos: Vector3, vel := Vector3.ZERO) -> void:
	player.queue_free()
	await process_frame
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = pos
	await _frames(3)
	player.velocity = vel


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(200, 1, 200), Vector3(0, -0.5, 0))                 # sàn
	_box(Vector3(1, 12, 40), Vector3(-5, 6, -20))                   # tường chạy (mặt x=-4.5)
	_box(Vector3(30, 20, 1), Vector3(0, 10, -80))                   # tường để móc
	_box(Vector3(10, 1, 30), Vector3(40, 3, -10), Vector3(20, 0, 0)) # dốc 20°
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	await _frames(10)

	var C: Dictionary = Global.PLAYER

	# ---------------- SLIDE BOOST có cooldown + SLIDE HOP
	print("[slide boost / slide hop]")
	player.velocity = Vector3(0, 0, -10)
	player.want_slide = true
	await _frames(1)
	var v_after: float = player.horizontal_speed()
	_check(v_after >= 10.0 + float(C["slide_boost"]) - 0.6, "vào slide được cộng boost (%.1f m/s)" % v_after)
	player.want_slide = false
	await _frames(3)
	player.velocity = Vector3(0, 0, -10)
	player.want_slide = true # ngay sau đó: boost còn cooldown
	await _frames(1)
	_check(player.horizontal_speed() < 10.5, "slide lại ngay: không được boost (%.1f m/s)" % player.horizontal_speed())
	player.want_slide = false
	await _frames(150)
	player.velocity = Vector3(0, 0, -14)
	player.want_slide = true
	await _frames(3)
	var sp_slide: float = player.horizontal_speed()
	player.want_jump = true
	await _frames(2)
	player.want_jump = false
	player.want_slide = false
	_check(not player.is_on_floor() and player.horizontal_speed() > sp_slide - 1.0 + float(C["slide_hop_boost"]) * 0.6, "slide hop: nhảy khi trượt giữ + cộng tốc độ (%.1f -> %.1f)" % [sp_slide, player.horizontal_speed()])

	# ---------------- STAMINA DASH
	print("[stamina dash]")
	await _reset(Vector3(0, 0.1, 0), Vector3.ZERO)
	_check(is_equal_approx(player.dash_stamina, float(C["dash_stamina_max"])) and player.dash_charges == 2, "bắt đầu đầy stamina (2 charge)")
	var changes: Array = []
	player.stamina_changed.connect(func(v, _m): changes.append(v))
	player.want_dash = true
	await _frames(1)
	_check(is_equal_approx(player.dash_stamina, float(C["dash_stamina_max"]) - float(C["dash_cost"])), "dash tốn %.0f stamina" % float(C["dash_cost"]))
	var after_dash: float = player.dash_stamina
	await _frames(10) # < regen_delay 0.25s ≈ 15 frame
	_check(is_equal_approx(player.dash_stamina, after_dash), "ngay sau dash: stamina chưa hồi (độ trễ)")
	await _frames(20)
	_check(player.dash_stamina > after_dash + 3.0, "sau độ trễ stamina hồi dần (%.1f)" % player.dash_stamina)
	_check(changes.size() > 0, "phát signal stamina_changed")
	player.dash_stamina = 30.0
	player.want_dash = true
	await _frames(2)
	_check(is_equal_approx(player.dash_stamina, 30.0) or player.dash_stamina > 30.0, "không đủ stamina thì không dash")
	player.dash_stamina = float(C["dash_stamina_max"])
	player.instability.add(500.0)
	await _frames(2)
	_check(player.dash_stamina == 0.0, "Destabilized: stamina dash về 0")
	await _frames(30)
	_check(player.dash_stamina == 0.0, "Destabilized: stamina không hồi")
	player.instability.reset()

	# ---------------- GRAPPLE REDIRECT
	print("[grapple redirect]")
	await _reset(Vector3(0, 0.1, -40), Vector3.ZERO)
	player.rotation.y = 0.0
	player.head.rotation.x = deg_to_rad(10.0)
	player.want_grapple = true
	await _frames(40)
	_check(player.state == player.State.GRAPPLE and player.velocity.length() > 10.0, "đang móc và được kéo (%.1f m/s)" % player.velocity.length())
	# xoay ống ngắm sang phải 90° rồi nhả: vận tốc phải bẻ theo hướng nhìn mới
	player.rotation.y = -PI * 0.5
	var spd: float = player.velocity.length()
	var before_dot: float = player.velocity.normalized().dot(-player.global_transform.basis.z)
	player.want_grapple = false
	await _frames(1)
	var after_dot: float = player.velocity.normalized().dot(-player.global_transform.basis.z)
	_check(after_dot > before_dot + 0.3, "nhả móc: vận tốc bẻ theo hướng nhìn (cos %.2f -> %.2f)" % [before_dot, after_dot])
	_check(player.velocity.length() >= spd - 0.5, "redirect giữ (hoặc tăng) độ lớn vận tốc (%.1f -> %.1f)" % [spd, player.velocity.length()])
	player.head.rotation.x = 0.0

	# ---------------- GROUND SLAM
	print("[ground slam]")
	await _reset(Vector3(0, 0.1, 0), Vector3.ZERO)
	player.want_slam = true
	await _frames(2)
	_check(player.state == player.State.NORMAL, "đứng trên đất: không slam được")
	var bot = load("res://scripts/bot.gd").new()
	bot.setup("swordsman", 1)
	world.add_child(bot)
	bot.global_position = Vector3(3, 0.1, 0)
	bot.set_physics_process(false)
	var hp0: float = bot.hurtbox.health
	var slams: Array = []
	player.slammed.connect(func(p, r): slams.append(r))
	player.global_position = Vector3(0, 8.0, 0)
	player.velocity = Vector3.ZERO
	await _frames(3)
	player.want_slam = true
	await _frames(2)
	_check(player.state == player.State.SLAM, "trên không cao: nhấn C -> SLAM")
	_check(player.velocity.y <= -float(C["slam_speed"]) + 1.0, "lao xuống với %.0f m/s (%.1f)" % [float(C["slam_speed"]), player.velocity.y])
	await _frames(40)
	_check(slams.size() == 1 and player.state == player.State.NORMAL, "chạm đất: phát slammed và về NORMAL")
	_check(bot.hurtbox.health < hp0, "bot trong bán kính bị sát thương (%.0f -> %.0f)" % [hp0, bot.hurtbox.health])
	_check(bot.melee.is_staggered(), "bot bị choáng")
	_check(player.velocity.y > 3.0 or not player.is_on_floor(), "người chơi nảy lên sau slam")
	bot.queue_free()
	player.global_position = Vector3(0, 8.0, 0)
	await _frames(30)
	player.want_slam = true
	await _frames(2)
	_check(player.state == player.State.SLAM or player.is_on_floor(), "slam cooldown không gây lỗi")

	# ---------------- RECOIL
	print("[recoil]")
	await _reset(Vector3(0, 6.0, 0), Vector3.ZERO)
	player.head.rotation.x = deg_to_rad(-60.0) # nhìn xuống
	player.combat.want_shoot = true
	await _frames(2)
	player.combat.want_shoot = false
	_check(player.velocity.y > 3.0, "bắn xuống khi ở trên không: bị đẩy lên (vy %.1f)" % player.velocity.y)
	await _reset(Vector3(0, 0.1, 0), Vector3.ZERO)
	await _frames(15) # đã đứng vững trên sàn
	player.head.rotation.x = deg_to_rad(-60.0)
	player.combat.want_shoot = true
	await _frames(2)
	player.combat.want_shoot = false
	_check(player.velocity.y < 1.0, "bắn khi đứng đất: không recoil (vy %.1f)" % player.velocity.y)

	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
