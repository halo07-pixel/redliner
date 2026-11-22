extends SceneTree
## Test headless M13: coyote time, jump buffer, trèo gờ, bước chân, camera, cài đặt, đổi phím, tay cầm.
##   timeout 250 godot --headless --path . -s tools/tests/test_feel.gd

var failures: int = 0
var world: Node3D
var player
var G


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _box(size: Vector3, pos: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = Global.L_WORLD
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	b.position = pos
	world.add_child(b)
	return b


func _fresh(pos: Vector3) -> void:
	if player != null:
		player.queue_free()
		await process_frame
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = pos
	await _frames(3)


func _clear_world() -> void:
	if world != null:
		world.queue_free()
		await process_frame
	world = Node3D.new()
	root.add_child(world)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://test_feel.cfg"
	G.load_save()
	G.reset_settings()
	G.reduced_fx = false

	print("[coyote time]")
	await _clear_world()
	_box(Vector3(8, 1, 8), Vector3(0, -0.5, 0))          # bệ đứng, mép tại z=-4
	_box(Vector3(200, 1, 200), Vector3(0, -20.5, 0))     # đáy sâu
	await _fresh(Vector3(0, 0.1, 0))
	await _frames(10) # đợi tiếp đất hẳn
	player.move_input = Vector2(0, -1)
	var guard: int = 0
	while player.is_on_floor() and guard < 200:
		await _frames(1)
		guard += 1
	_check(not player.is_on_floor() and player.global_position.z < -3.5, "đã đi khỏi mép bệ")
	await _frames(3) # ~0.05 s sau mép
	player.want_jump = true
	await _frames(1)
	player.want_jump = false
	_check(player.velocity.y > 5.0, "nhảy được ngay sau mép (coyote), vy=%.1f" % player.velocity.y)
	await _fresh(Vector3(0, 0.1, 0))
	await _frames(10)
	player.move_input = Vector2(0, -1)
	guard = 0
	while player.is_on_floor() and guard < 200:
		await _frames(1)
		guard += 1
	await _frames(14) # ~0.23 s: quá coyote
	player.want_jump = true
	await _frames(1)
	player.want_jump = false
	_check(player.velocity.y <= 0.5, "quá thời gian coyote: không nhảy được (vy=%.1f)" % player.velocity.y)

	print("[jump buffer]")
	await _clear_world()
	_box(Vector3(200, 1, 200), Vector3(0, -0.5, 0))
	await _fresh(Vector3(0, 0.45, 0))
	player.velocity = Vector3(0, -8, 0)
	player.want_jump = true       # bấm 1 nhịp, sắp chạm đất
	await _frames(1)
	player.want_jump = false
	var max_vy: float = -99.0
	for i in 12:
		await _frames(1)
		max_vy = maxf(max_vy, player.velocity.y)
	_check(max_vy > 5.0, "bấm nhảy sớm ~0.05 s trước khi đáp: tự nhảy khi chạm đất (vy=%.1f)" % max_vy)
	await _fresh(Vector3(0, 4.0, 0))
	player.velocity = Vector3.ZERO
	player.want_jump = true       # bấm quá sớm (rơi > 0.12 s)
	await _frames(1)
	player.want_jump = false
	max_vy = -99.0
	var landed: bool = false
	for i in 60:
		await _frames(1)
		if landed:
			max_vy = maxf(max_vy, player.velocity.y)
		if player.is_on_floor():
			landed = true
	_check(max_vy < 1.0, "bấm quá sớm: lệnh nhảy hết hạn, không nhảy (vy=%.1f)" % max_vy)

	print("[trèo gờ]")
	await _clear_world()
	_box(Vector3(200, 1, 200), Vector3(0, -0.5, 0))
	_box(Vector3(6, 1.5, 4), Vector3(0, 0.75, -5))       # bệ cao 1.5 m, mặt trước z=-3
	await _fresh(Vector3(0, 0.4, -2.4))
	player.velocity = Vector3(0, -1, -5)
	player.move_input = Vector2(0, -1)
	var climbed: Array = []
	player.ledge_climbed.connect(func(): climbed.append(1))
	var saw: bool = false
	for i in 8:
		await _frames(1)
		if player.state == player.State.LEDGE:
			saw = true
	_check(saw, "đang rơi sát bệ cao 1.5 m và giữ tiến: vào trạng thái LEDGE")
	await _frames(40)
	_check(climbed.size() == 1, "phát ledge_climbed")
	_check(player.global_position.y > 1.4 and player.global_position.z < -3.2, "đã lên mặt bệ (y=%.2f, z=%.2f)" % [player.global_position.y, player.global_position.z])
	_check(player.state == player.State.NORMAL and player.horizontal_speed() > 3.0, "giữ đà ngang sau khi trèo (%.1f m/s)" % player.horizontal_speed())
	await _frames(20)
	_check(player.is_on_floor(), "đứng được trên bệ")
	# không giữ tiến -> không trèo
	await _fresh(Vector3(0, 0.4, -2.4))
	player.velocity = Vector3(0, -1, -3)
	player.move_input = Vector2.ZERO
	saw = false
	for i in 10:
		await _frames(1)
		if player.state == player.State.LEDGE:
			saw = true
	_check(not saw, "không giữ phím tiến: không bị hút lên bệ")
	# hủy khi bị đánh
	await _fresh(Vector3(0, 0.4, -2.4))
	player.velocity = Vector3(0, -1, -5)
	player.move_input = Vector2(0, -1)
	for i in 8:
		await _frames(1)
		if player.state == player.State.LEDGE:
			break
	player.hurtbox.take_hit({"damage": 5.0, "kind": "melee", "source": null, "direction": Vector3.FORWARD})
	await _frames(1)
	_check(player.state != player.State.LEDGE, "bị đánh giữa chừng: huỷ trèo gờ")
	# dash huỷ
	await _fresh(Vector3(0, 0.4, -2.4))
	player.dash_stamina = 100.0
	player.velocity = Vector3(0, -1, -5)
	player.move_input = Vector2(0, -1)
	for i in 8:
		await _frames(1)
		if player.state == player.State.LEDGE:
			break
	player.want_dash = true
	await _frames(2)
	_check(player.state != player.State.LEDGE, "dash giữa chừng: huỷ trèo gờ")

	await _clear_world()
	_box(Vector3(200, 1, 200), Vector3(0, -0.5, 0))
	_box(Vector3(6, 3.2, 4), Vector3(0, 1.6, -5))        # quá cao
	await _fresh(Vector3(0, 0.4, -2.4))
	player.velocity = Vector3(0, -1, -5)
	player.move_input = Vector2(0, -1)
	saw = false
	for i in 20:
		await _frames(1)
		if player.state == player.State.LEDGE:
			saw = true
	_check(not saw and player.global_position.y < 1.0, "tường cao 3.2 m: không trèo được")

	await _clear_world()
	_box(Vector3(200, 1, 200), Vector3(0, -0.5, 0))
	_box(Vector3(6, 1.5, 4), Vector3(0, 0.75, -5))
	_box(Vector3(6, 0.5, 4), Vector3(0, 3.15, -5))       # trần thấp phía trên mặt bệ (đáy 2.9 m)
	await _fresh(Vector3(0, 0.4, -2.4))
	player.velocity = Vector3(0, -1, -5)
	player.move_input = Vector2(0, -1)
	saw = false
	for i in 12:
		await _frames(1)
		if player.state == player.State.LEDGE:
			saw = true
	_check(not saw, "không đủ chỗ đứng trên bệ (trần thấp): không trèo")

	print("[bước chân]")
	await _clear_world()
	_box(Vector3(200, 1, 200), Vector3(0, -0.5, 0))
	await _fresh(Vector3(0, 0.1, 40))
	await _frames(20)
	var steps: Array = []
	player.footstep.connect(func(sp): steps.append(sp))
	await _frames(40)
	_check(steps.is_empty(), "đứng yên: không có tiếng bước")
	player.move_input = Vector2(0, -1)
	await _frames(60)
	var s1: int = steps.size()
	var travelled: float = 40.0 - player.global_position.z
	_check(s1 >= 3 and s1 <= 6, "đi ~%.1f m phát %d tiếng bước (stride 2.2 m)" % [travelled, s1])
	player.global_position.y = 6.0
	steps.clear()
	await _frames(10)
	_check(steps.is_empty(), "trên không: không có tiếng bước")

	print("[camera: lắc đầu / nghiêng]")
	await _clear_world()
	_box(Vector3(400, 1, 400), Vector3(0, -0.5, 0))
	await _fresh(Vector3(0, 0.1, 100))
	player.move_input = Vector2(0, -1)
	var base: Vector3 = player._cam_base
	var dev: float = 0.0
	for i in 40:
		await process_frame
		await _frames(1)
		dev = maxf(dev, absf(player.camera.position.y - base.y))
	_check(dev > 0.005, "chạy trên sàn: camera lắc nhẹ (%.3f m)" % dev)
	G.set_setting("bob", 0.0)
	await _frames(30)
	for i in 10:
		await process_frame
	_check(player.camera.position.distance_to(base) < 0.002, "bob = 0: camera đứng yên")
	G.set_setting("bob", 1.0)
	G.set_reduced_fx(true)
	dev = 0.0
	for i in 20:
		await process_frame
		await _frames(1)
		dev = maxf(dev, absf(player.camera.position.y - base.y))
	_check(dev < 0.01, "giảm hiệu ứng: không lắc đầu (%.4f)" % dev)
	var roll: float = absf(player.head.rotation.z)
	_check(roll < 0.002, "giảm hiệu ứng: không nghiêng khi di chuyển")
	G.set_reduced_fx(false)
	player.move_input = Vector2(1, 0)
	await _frames(40)
	for i in 20:
		await process_frame
	_check(absf(player.head.rotation.z) > 0.005, "đi ngang: camera nghiêng nhẹ")

	print("[cài đặt]")
	var got: Array = []
	G.settings_changed.connect(func(): got.append(1))
	G.set_setting("fov", 500.0)
	_check(G.settings["fov"] == 110.0 and got.size() == 1, "FOV bị kẹp 70..110 và phát settings_changed")
	G.set_setting("mouse_mult", 0.0)
	_check(G.settings["mouse_mult"] == 0.2, "độ nhạy chuột kẹp tối thiểu 0.2")
	G.set_setting("fov", 100.0)
	await _frames(1)
	for i in 120:   # FOV đuổi theo bằng lò xo (0.22 s) nên chờ lâu hơn
		await process_frame
	_check(player.camera.fov >= 99.0, "FOV nền áp dụng cho camera (%.1f)" % player.camera.fov)
	G.set_setting("fov", 90.0)
	G.set_setting("nope", 1)
	_check(not G.settings.has("nope"), "khoá lạ bị bỏ qua")
	await _fresh(Vector3(0, 0.1, 0))
	player._pitch = 0.0
	player.apply_look(Vector2(0, 0.2))
	var p_normal: float = player._pitch
	player._pitch = 0.0
	G.set_setting("invert_y", true)
	player.apply_look(Vector2(0, 0.2))
	var p_inv: float = player._pitch
	G.set_setting("invert_y", false)
	_check(p_normal < 0.0 and p_inv > 0.0, "đảo trục Y đổi chiều nhìn (%.2f / %.2f)" % [p_normal, p_inv])
	player.apply_look(Vector2(0, 99.0))
	_check(absf(player._pitch) <= PI * 0.49 + 0.001, "góc ngẩng bị kẹp")
	G.set_setting("pad_deadzone", 0.3)
	_check(is_equal_approx(InputMap.action_get_deadzone("look_left"), 0.3) and is_equal_approx(InputMap.action_get_deadzone("move_forward"), 0.3), "vùng chết analog áp lên InputMap")
	G.set_setting("pad_deadzone", 0.2)
	G.set_setting("fov", 80.0)
	G.reduced_fx = false
	G.load_save()
	_check(G.settings["fov"] == 80.0, "cài đặt được lưu và nạp lại")
	G.reset_settings()
	_check(G.settings["fov"] == 90.0 and G.settings["mouse_mult"] == 1.0, "reset_settings về mặc định")

	print("[đổi phím]")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_J
	_check(G.rebind("jump", ev), "gán Nhảy = J")
	_check(InputMap.action_get_events("jump").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_J), "InputMap có phím J cho jump")
	_check(not InputMap.action_get_events("jump").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_SPACE), "phím Space cũ bị bỏ")
	_check(G.binding_text("jump").contains("J"), "binding_text hiện phím mới (%s)" % G.binding_text("jump"))
	_check(InputMap.action_get_events("jump").any(func(e): return e is InputEventJoypadButton), "đổi phím không xoá nút tay cầm")
	var ev2 := InputEventKey.new()
	ev2.physical_keycode = KEY_J
	_check(not G.rebind("slide", ev2) and G.binding_conflict("slide", ev2) == "jump", "trùng phím J với Nhảy: bị chặn")
	var evm := InputEventMouseButton.new()
	evm.button_index = MOUSE_BUTTON_MIDDLE
	_check(G.rebind("dash", evm), "gán Dash = chuột giữa")
	_check(G.binding_text("dash").contains("Chuột giữa"), "chuột giữa hiển thị đúng")
	var evx := InputEventMouseMotion.new()
	_check(not G.rebind("dash", evx), "sự kiện không hợp lệ bị từ chối")
	G._apply_binding_data("jump", [["k", KEY_SPACE]]) # đưa bộ nhớ về mặc định, file vẫn giữ J
	G.load_save()
	_check(G.binding_text("jump").contains("J"), "phím đã đổi được lưu và nạp lại")
	G.reset_bindings()
	_check(G.binding_text("jump").contains("Space") or G.binding_text("jump").contains("Khoảng"), "reset_bindings: Nhảy về Space (%s)" % G.binding_text("jump"))
	_check(not G.binding_text("dash").contains("giữa"), "reset_bindings: Dash về Shift")

	print("[tay cầm]")
	var has_motion: Callable = func(a: String, axis: int) -> bool:
		return InputMap.action_get_events(a).any(func(e): return e is InputEventJoypadMotion and e.axis == axis)
	_check(has_motion.call("move_forward", JOY_AXIS_LEFT_Y) and has_motion.call("move_right", JOY_AXIS_LEFT_X), "cần trái = di chuyển")
	_check(has_motion.call("look_left", JOY_AXIS_RIGHT_X) and has_motion.call("look_up", JOY_AXIS_RIGHT_Y), "cần phải = nhìn")
	_check(has_motion.call("attack", JOY_AXIS_TRIGGER_RIGHT) and has_motion.call("grapple", JOY_AXIS_TRIGGER_LEFT), "trigger = chém / móc")
	for a in ["jump", "slide", "dash", "heavy", "shoot", "parry", "slam", "reload", "zoom", "weapon_next", "weapon_prev", "ui_cancel"]:
		_check(InputMap.action_get_events(a).any(func(e): return e is InputEventJoypadButton), "nút tay cầm cho %s" % a)

	print("[màn cài đặt (giao diện)]")
	var sm = load("res://scripts/settings_menu.gd").new()
	root.add_child(sm)
	await _frames(2)
	_check(sm._key_buttons.size() == G.REMAPPABLE.size(), "có ô đổi phím cho mọi hành động (%d)" % sm._key_buttons.size())
	var closed: Array = []
	sm.closed.connect(func(): closed.append(1))
	sm._key_buttons["jump"].pressed.emit()
	_check(sm._listening == "jump", "bấm ô: chờ phím mới")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_K
	k.pressed = true
	sm._input(k)
	_check(G.binding_text("jump").contains("K") and sm._listening == "", "nhấn K: gán xong cho Nhảy")
	sm._key_buttons["slide"].pressed.emit()
	var k2 := InputEventKey.new()
	k2.physical_keycode = KEY_K
	k2.pressed = true
	sm._input(k2)
	_check(sm._msg.text.contains("đang dùng") and not G.binding_text("slide").contains("K"), "trùng phím: báo lỗi, không đổi")
	sm._key_buttons["slide"].pressed.emit()
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	sm._input(esc)
	_check(sm._listening == "", "Esc huỷ việc đổi phím")
	sm._sliders["fov"][0].value = 100.0
	_check(G.settings["fov"] == 100.0, "kéo thanh FOV đổi cài đặt")
	sm._on_reset()
	_check(G.binding_text("jump").contains("K") == false and G.settings["fov"] == 90.0, "nút Mặc định đặt lại phím và cài đặt")
	sm.closed.emit()
	_check(closed.size() == 1, "phát closed")
	sm.queue_free()
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await _frames(2)
	menu.settings_button.pressed.emit()
	_check(menu.settings_panel.visible, "menu chính mở được Cài đặt")
	menu.queue_free()
	var pm = load("res://scripts/pause_menu.gd").new()
	root.add_child(pm)
	await _frames(2)
	pm.set_open(true)
	pm.settings_button.pressed.emit()
	_check(pm.settings_panel.visible, "menu tạm dừng mở được Cài đặt")
	pm.set_open(false)
	_check(not pm.settings_panel.visible, "đóng tạm dừng thì Cài đặt cũng đóng")
	pm.queue_free()

	G.reset_bindings()
	G.reset_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_feel.cfg"))
	print("----", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
