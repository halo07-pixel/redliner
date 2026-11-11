extends SceneTree
## Test headless cho di chuyển. Chạy:
##   timeout 120 godot --headless --path . -s tools/tests/test_movement.gd
## Thoát với mã 1 nếu có test fail.

var failures: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame # đợi cây node sẵn sàng
	var arena := Node3D.new()
	arena.set_script(load("res://scripts/arena.gd"))
	root.add_child(arena)
	var player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false # test tự điền move_input / want_jump
	root.add_child(player)
	player.global_position = arena.spawn_point
	await _frames(10)

	var walk: float = Global.PLAYER["walk_speed"]
	_check(player.is_on_floor(), "đứng được trên sàn sau khi spawn")

	# 1. Đi tiến: đạt đúng walk_speed và dịch về phía -Z
	var z0: float = player.global_position.z
	player.move_input = Vector2(0.0, -1.0)
	await _frames(60)
	_check(absf(player.horizontal_speed() - walk) < 0.5, "đi tiến đạt ~walk_speed (%.2f m/s)" % player.horizontal_speed())
	_check(player.global_position.z < z0 - 3.0, "đi tiến dịch về phía -Z (%.1f m)" % (z0 - player.global_position.z))

	# 2. Thả phím: ma sát dừng hẳn
	player.move_input = Vector2.ZERO
	await _frames(120)
	_check(player.horizontal_speed() < 0.5, "thả phím thì dừng (%.2f m/s)" % player.horizontal_speed())

	# 3. Nhảy: lên cao rồi tiếp đất lại
	player.global_position = Vector3(0.0, 0.1, 18.0)
	await _frames(5)
	var max_y: float = 0.0
	player.want_jump = true
	await physics_frame
	player.want_jump = false
	for i in 120:
		await physics_frame
		max_y = maxf(max_y, player.global_position.y)
	_check(max_y > 1.2, "nhảy cao hơn 1.2 m (%.2f m)" % max_y)
	_check(player.is_on_floor(), "tiếp đất lại sau khi nhảy")

	# 4. Động lượng trên không KHÔNG bị cắt (không trần tốc độ, không ma sát không khí)
	player.global_position = Vector3(0.0, 8.0, 0.0)
	await _frames(2) # để cờ is_on_floor của frame trước được làm mới trước khi đặt vận tốc
	player.velocity = Vector3(0.0, 0.0, -20.0)
	await _frames(10)
	_check(player.horizontal_speed() > 19.9, "giữ động lượng 20 m/s trên không (%.2f m/s)" % player.horizontal_speed())

	# 5. Air-strafe: bấm vuông góc với vận tốc đang có thì cộng thêm tốc độ
	player.global_position = Vector3(0.0, 8.0, 0.0)
	await _frames(2)
	player.velocity = Vector3(0.0, 0.0, -20.0)
	player.move_input = Vector2(1.0, 0.0) # sang phải, vuông góc hướng bay
	await _frames(10)
	_check(player.horizontal_speed() > 20.0, "air-strafe cộng thêm tốc độ (%.2f m/s)" % player.horizontal_speed())

	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
