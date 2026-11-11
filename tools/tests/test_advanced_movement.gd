extends SceneTree
## Test headless: slide, dash, wallrun, grapple.
##   timeout 180 godot --headless --path . -s tools/tests/test_advanced_movement.gd

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

	# ---------------- SLIDE
	print("[slide]")
	player.velocity = Vector3(0, 0, -12)
	player.want_slide = true
	await _frames(2)
	_check(player.state == player.State.SLIDE, "chạy nhanh + Ctrl -> vào trạng thái SLIDE")
	var cap: CapsuleShape3D = player.get_node("Body").shape
	_check(cap.height < 1.2, "hạ thấp hitbox khi trượt (%.2f m)" % cap.height)
	await _frames(30)
	_check(player.horizontal_speed() > 12.0, "trượt giữ tốc độ, ma sát nhỏ (%.1f m/s sau 0.5s)" % player.horizontal_speed())
	player.want_slide = false
	await _frames(3)
	_check(player.state == player.State.NORMAL and cap.height > 1.7, "thả Ctrl -> đứng dậy")
	# Đi chậm thì không trượt được
	await _frames(120)
	player.velocity = Vector3(0, 0, -3)
	player.want_slide = true
	await _frames(2)
	_check(player.state == player.State.NORMAL, "đi chậm + Ctrl -> không trượt")
	player.want_slide = false

	# Trượt xuống dốc thì tăng tốc
	await _reset(Vector3(40, 6.4, -16), Vector3.ZERO)
	player.rotation.y = PI # quay mặt về +Z (xuống dốc)
	await _frames(30)
	_check(player.is_on_floor(), "đứng được trên dốc")
	player.velocity = player.velocity + Vector3(0, 0, 7.0)
	player.want_slide = true
	await _frames(2)
	var v0: float = player.horizontal_speed()
	await _frames(40)
	_check(player.state == player.State.SLIDE and player.horizontal_speed() > v0 + 3.0, "trượt xuống dốc tăng tốc (%.1f -> %.1f m/s)" % [v0, player.horizontal_speed()])
	player.want_slide = false

	# ---------------- DASH
	print("[dash]")
	await _reset(Vector3(0, 0.1, 0))
	await _frames(5)
	player.move_input = Vector2(0, -1)
	player.want_dash = true
	await _frames(1)
	_check(player.horizontal_speed() > 14.0, "dash cộng vận tốc (%.1f m/s)" % player.horizontal_speed())
	_check(player.dash_charges == 1, "dash tiêu 1 charge (còn %d)" % player.dash_charges)
	player.want_dash = true
	await _frames(1)
	_check(player.dash_charges == 1, "dash liền tay bị chặn bởi cooldown")
	await _frames(20)
	player.want_dash = true
	await _frames(1)
	_check(player.dash_charges == 0, "dash lần 2 hết charge (còn %d)" % player.dash_charges)
	await _frames(20)
	player.want_dash = true
	await _frames(1)
	_check(player.dash_charges == 0, "hết charge thì không dash được")
	await _frames(100) # > 1.5s
	_check(player.dash_charges >= 1, "charge hồi lại sau %d frame (%d)" % [100, player.dash_charges])
	# dash cộng dồn trên không
	await _reset(Vector3(0, 20, 0), Vector3(0, 0, -10))
	player.want_dash = true
	player.move_input = Vector2(0, -1)
	await _frames(1)
	_check(player.horizontal_speed() > 26.0, "dash trên không cộng thêm vào quán tính 10 m/s (%.1f)" % player.horizontal_speed())

	# ---------------- WALLRUN
	print("[wallrun]")
	# Tường ở x=-4.5, người chơi ở x=-3.6 (cách mặt tường 0.9m) bên trái, chạy về -Z
	await _reset(Vector3(-3.6, 6.0, -2.0), Vector3(0, 0, -12))
	player.move_input = Vector2(0, -1)
	await _frames(15)
	_check(player.state == player.State.WALLRUN, "trên không + sát tường + bấm tiến -> WALLRUN")
	_check(player.velocity.y > -4.0, "bám tường: rơi chậm (vy=%.1f, rơi tự do sẽ ~ -6)" % player.velocity.y)
	_check(player.horizontal_speed() > 9.0, "giữ tốc độ dọc tường (%.1f m/s)" % player.horizontal_speed())
	player.want_jump = true
	await _frames(2)
	player.want_jump = false
	_check(player.state == player.State.NORMAL and player.velocity.x > 5.0, "nhảy khỏi tường: bật ra xa (vx=%.1f)" % player.velocity.x)
	await _frames(10)
	_check(player.state == player.State.NORMAL, "khóa bám lại ngay sau khi nhảy khỏi tường")
	# Tốc độ thấp thì không bám
	await _reset(Vector3(-3.6, 6.0, -2.0), Vector3(0, 0, -1))
	player.move_input = Vector2(0, -1)
	await _frames(5)
	_check(player.state != player.State.WALLRUN, "đi chậm -> không bám tường")

	# ---------------- GRAPPLE
	print("[grapple]")
	await _reset(Vector3(0, 5.0, 0), Vector3.ZERO)
	player.global_position = Vector3(0, 12.0, -40)
	await _frames(1)
	player.velocity = Vector3.ZERO
	var started: Array = []
	player.grapple_started.connect(func(p): started.append(p))
	player.want_grapple = true
	await _frames(2)
	_check(player.state == player.State.GRAPPLE and started.size() == 1, "chuột phải trúng tường -> GRAPPLE, phát signal")
	_check(absf(started[0].z + 79.5) < 0.2, "điểm móc đúng mặt tường (z=%.1f)" % started[0].z)
	var z0: float = player.global_position.z
	await _frames(40)
	_check(player.global_position.z < z0 - 8.0, "bị kéo về phía điểm móc (%.1f m)" % (z0 - player.global_position.z))
	await _frames(120)
	_check(player.state == player.State.NORMAL, "tới gần điểm móc thì tự thả")
	player.want_grapple = false
	# Thả giữa chừng giữ quán tính
	await _reset(Vector3(0, 12.0, -40), Vector3.ZERO)
	player.want_grapple = true
	await _frames(40)
	var sp: float = player.velocity.length()
	player.want_grapple = false
	await _frames(1)
	_check(player.state == player.State.NORMAL and player.velocity.length() > sp * 0.9, "thả phím giữ quán tính (%.1f -> %.1f m/s)" % [sp, player.velocity.length()])
	# Không trúng gì thì không móc
	await _reset(Vector3(0, 12.0, -40), Vector3.ZERO)
	player.rotation.y = PI # quay lưng lại tường -> sau lưng không có gì trong tầm 60m
	player.global_position = Vector3(0, 12.0, -10)
	await _frames(1)
	player.want_grapple = true
	await _frames(3)
	_check(player.state != player.State.GRAPPLE, "hướng ra khoảng trống -> không móc")

	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
