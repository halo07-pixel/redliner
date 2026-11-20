extends SceneTree
## Test headless M18: hoạt ảnh/hiệu ứng rõ ràng (tư thế theo trạng thái, đỡ kiếm, dây móc, vệt tốc độ, bụi).
##   timeout 300 godot --headless --path . -s tools/tests/test_m18.gd

var failures: int = 0
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


func _pose(vm: Node3D, speed: float, st: String, lateral: float = 0.0, n: int = 90) -> void:
	for i in n:
		vm.update(1.0 / 60.0, speed, true, st, lateral)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://m18_test.cfg"
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(10)
	var pl = main.player
	pl.use_input = false
	pl.set_process(false)
	var vm: Node3D = pl.viewmodel
	vm.reset()
	var rest_pos: Vector3 = vm._sword_rest_pos

	print("[tư thế theo trạng thái]")
	_pose(vm, 0.0, "")
	var idle_rot: Vector3 = vm.sword_pivot.rotation_degrees
	for st in ["slide", "dash", "grapple", "wallrun"]:
		_pose(vm, 12.0, st)
		var d: float = vm.sword_pivot.rotation_degrees.distance_to(idle_rot) + vm.sword_pivot.position.distance_to(rest_pos) * 100.0
		_check(d > 8.0, "kiếm ở trạng thái %s khác hẳn tư thế nghỉ (lệch %.1f)" % [st, d])
	_pose(vm, 0.0, "")
	_check(vm.sword_pivot.position.distance_to(rest_pos) < 0.02 and vm.sword_pivot.rotation_degrees.distance_to(idle_rot) < 5.0, "ra khỏi trạng thái thì kiếm trở về tư thế nghỉ")
	_check(vm.sword_pivot.rotation_degrees.x > 60.0, "kiếm vẫn cầm thẳng lên khi nghỉ")
	_pose(vm, 12.0, "slide")
	var gun_slide: Vector3 = vm.gun_pivot.rotation_degrees
	_check(gun_slide.z < -5.0, "súng nghiêng khi lướt (z %.1f)" % gun_slide.z)
	_pose(vm, 0.0, "")

	print("[chạy / đi ngang]")
	_pose(vm, 11.0, "", 0.0)
	var run_x: float = vm.sword_pivot.rotation_degrees.x
	_check(run_x < idle_rot.x - 3.0, "chạy nhanh: kiếm hạ về trước (%.1f < %.1f)" % [run_x, idle_rot.x])
	_pose(vm, 6.0, "", 1.0)
	var roll_r: float = vm.rotation_degrees.z
	_pose(vm, 6.0, "", -1.0)
	var roll_l: float = vm.rotation_degrees.z
	_check(roll_r * roll_l < 0.0 and absf(roll_r - roll_l) > 8.0, "đi ngang trái/phải nghiêng tay ngược nhau (%.1f / %.1f)" % [roll_r, roll_l])
	var G_settings: Dictionary = G.settings
	var old_bob: float = float(G_settings["bob"])
	G_settings["bob"] = 0.0
	_pose(vm, 12.0, "slide")
	_check(vm.sword_pivot.position.distance_to(rest_pos) < 0.02, "cường độ bob = 0 tắt tư thế trạng thái")
	G_settings["bob"] = old_bob
	_pose(vm, 0.0, "")

	print("[đỡ kiếm]")
	vm.raise()
	await create_timer(0.1).timeout
	var gr: Vector3 = vm.sword_pivot.rotation_degrees
	_check(gr.y > 60.0, "giơ kiếm đỡ: lưỡi quét ngang (yaw %.1f)" % gr.y)
	_check(vm.sword_pivot.position.distance_to(Vector3(G.VIEWMODEL["guard_pos"])) < 0.1, "kiếm lên giữa màn hình khi đỡ")
	await create_timer(float(G.COMBAT["parry_window"]) + 0.4).timeout
	_pose(vm, 0.0, "", 0.0, 30)
	_check(vm.sword_pivot.rotation_degrees.distance_to(idle_rot) < 6.0, "hết cửa sổ parry: kiếm về nghỉ")
	var v0: float = vm._pos_spring.v.z
	vm.parry_hit()
	_check(vm._pos_spring.v.z < v0 - 1.0, "parry thành công: cú đẩy ra trước")
	vm.parry_fail()
	await create_timer(0.1).timeout
	_check(vm.sword_pivot.position.y < rest_pos.y - 0.1, "parry hụt: kiếm bị hất xuống")
	await create_timer(0.9).timeout
	_pose(vm, 0.0, "", 0.0, 30)
	_check(vm.sword_pivot.position.distance_to(rest_pos) < 0.03, "sau parry hụt kiếm về nghỉ")
	# chen ngang liên tục không kẹt
	for i in 5:
		vm.raise()
		await create_timer(0.03).timeout
		vm.play_swing(0.1, 0.05, 0.1)
		await create_timer(0.03).timeout
		vm.parry_fail()
		await create_timer(0.03).timeout
	await create_timer(1.0).timeout
	_pose(vm, 0.0, "", 0.0, 30)
	_check(vm.sword_pivot.position.distance_to(rest_pos) < 0.03 and vm.sword_pivot.rotation_degrees.distance_to(idle_rot) < 6.0, "chen ngang chém/đỡ liên tục: không kẹt tư thế")

	print("[chém]")
	vm.play_swing(0.2, 0.1, 0.3)
	await create_timer(0.22).timeout
	_check(vm.sword_pivot.position.z > rest_pos.z + 0.05, "windup kéo kiếm ra sau (z)")
	await create_timer(0.2).timeout
	_check(vm.sword_pivot.position.z < rest_pos.z - 0.1, "active: kiếm lao tới trước (z)")
	await create_timer(0.5).timeout

	print("[chớp nòng]")
	vm.kick()
	_check(vm.muzzle_flash.visible and vm._flash_light.visible, "bắn: có chớp nòng + ánh sáng")
	await create_timer(0.15).timeout
	_pose(vm, 0.0, "", 0.0, 10)
	_check(not vm.muzzle_flash.visible and not vm._flash_light.visible, "chớp nòng tắt sau flash_time")
	G.reduced_fx = true
	vm.kick()
	_check(not vm._flash_light.visible, "giảm hiệu ứng: không bật đèn chớp nòng")
	G.reduced_fx = false

	print("[dây móc]")
	var rope = pl.rope
	rope.show_to(pl.global_position + Vector3(0.0, 5.0, -10.0))
	await create_timer(0.03).timeout
	var p1: float = rope.progress
	_check(p1 > 0.0 and p1 < 1.0 and not rope.is_attached(), "dây đang phóng ra (tiến độ %.2f)" % p1)
	await create_timer(0.3).timeout
	_check(rope.progress >= 1.0 and rope.is_attached(), "dây đã bám: có đầu móc")
	rope.hide_rope()
	_check(not rope.is_attached(), "nhả dây: ẩn đầu móc")

	print("[vệt tốc độ]")
	var sl = load("res://scripts/speed_lines.gd").new()
	root.add_child(sl)
	await process_frame
	sl.set_speed(5.0)
	await _frames(5)
	_check(not sl.rect.visible, "chậm: không có vệt tốc độ")
	sl.set_speed(25.0)
	for i in 30:
		await process_frame
	_check(sl.rect.visible and sl.intensity > 0.5, "nhanh: hiện vệt tốc độ (%.2f)" % sl.intensity)
	G.reduced_fx = true
	sl.set_speed(25.0)
	await create_timer(1.2).timeout
	_check(not sl.rect.visible, "giảm hiệu ứng: không vẽ vệt tốc độ")
	G.reduced_fx = false
	sl.queue_free()

	print("[bụi + dọn dẹp]")
	var Fx = load("res://scripts/fx.gd")
	var n0: int = main.get_child_count()
	Fx.dust(main, pl.global_position)
	await process_frame
	_check(main.get_child_count() == n0 + 1, "bụi sinh ra")
	await create_timer(1.3).timeout
	_check(main.get_child_count() == n0, "bụi tự dọn sau khi tan")

	main.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.save_path))
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(failures)
