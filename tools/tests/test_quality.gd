extends SceneTree
## Test headless M6.3: 3 mức đồ họa áp đúng lên môi trường/đèn/viewport, đổi mức qua Signal, lưu và tải lại.
##   timeout 120 godot --headless --path . -s tools/tests/test_quality.gd

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
	var g: Node = root.get_node("Global")
	var UIKit = load("res://scripts/ui_kit.gd")
	g.save_path = "user://test_quality.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(g.save_path))
	g.load_save()
	_check(g.quality == Global.QUALITY_DEFAULT, "mặc định là Vừa")
	_check(Global.QUALITY.size() == 3 and Global.QUALITY_NAMES.size() == 3, "có đúng 3 mức")

	var arena: Node3D = load("res://scripts/arena.gd").new()
	root.add_child(arena)
	await process_frame
	var env: Environment = arena.world_env
	var sun: DirectionalLight3D = arena.sun
	_check(sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "Vừa: bóng 2 cascade")
	_check(env.glow_enabled and env.fog_enabled and not env.ssao_enabled, "Vừa: glow+fog, không SSAO")

	g.set_quality(0)
	_check(not sun.shadow_enabled, "Thấp: tắt bóng")
	_check(not env.glow_enabled and not env.fog_enabled and not env.ssao_enabled, "Thấp: tắt glow/fog/SSAO")
	_check(is_equal_approx(root.scaling_3d_scale, 0.75) and root.msaa_3d == Viewport.MSAA_DISABLED, "Thấp: scale 0.75, không MSAA")

	g.set_quality(2)
	_check(sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "Cao: bóng 4 cascade")
	_check(env.ssao_enabled and env.glow_enabled and env.fog_enabled, "Cao: bật SSAO/glow/fog")
	_check(root.msaa_3d == Viewport.MSAA_2X and is_equal_approx(root.scaling_3d_scale, 1.0), "Cao: MSAA 2x, scale 1.0")
	_check(sun.directional_shadow_max_distance > Global.QUALITY[0]["shadow_dist"], "Cao: tầm bóng xa hơn Thấp")

	g.set_quality(99)
	_check(g.quality == 2, "mức ngoài phạm vi bị kẹp về Cao")

	# Lưu & tải lại, và điểm cao không làm mất mức đồ họa
	g.set_quality(0)
	g.submit_score(500)
	g.quality = 1
	g.high_score = 0
	g.load_save()
	_check(g.quality == 0 and g.high_score == 500, "lưu/tải lại giữ cả mức đồ họa lẫn điểm cao")

	# Nút xoay vòng
	var b: Button = UIKit.quality_button()
	_check(b.text == "Đồ họa: Thấp", "nút hiện mức hiện tại")
	b.pressed.emit()
	_check(g.quality == 1 and b.text == "Đồ họa: Vừa", "bấm nút: Thấp -> Vừa, chữ cập nhật")
	b.pressed.emit()
	b.pressed.emit()
	_check(g.quality == 0, "xoay vòng Cao -> Thấp")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(g.save_path))
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
