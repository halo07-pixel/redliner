extends SceneTree
## Chụp M16: màn Chuẩn bị, hướng dẫn, HUD chế độ thời gian, màn tổng kết (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_m16.gd -- docs/screenshots

var out_dir: String = "docs/screenshots"


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
	print("saved ", shot_name)


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var G = root.get_node("Global")
	G.save_path = "user://shoot_m16.cfg"
	G.load_save()
	G.set_mode("timed")
	G.submit_mode_score(1250, "timed")
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	for i in 6:
		await process_frame
	menu.play_button.pressed.emit()
	for i in 4:
		await process_frame
	await _shot("m16_1_chuan_bi")
	menu.setup_panel.visible = false
	menu.help_button.pressed.emit()
	for i in 4:
		await process_frame
	await _shot("m16_2_huong_dan")
	menu.queue_free()
	await process_frame

	G.selected_map = "yard"
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(6)
	main.player.use_input = false
	main._start_mode()
	await _frames(30)
	main.mode.time_left = 47.3
	main.mode.kills = 9
	main.mode.objective_changed.emit(main.mode.objective_text())
	main.mode.time_changed.emit(main.mode.time_left)
	main.hud.flash("+3 s", Color(0.5, 0.9, 1.0))
	await _frames(10)
	await _shot("m16_3_hud_thoi_gian")
	main.mode.time_left = 6.4
	main.mode.time_changed.emit(main.mode.time_left)
	await _frames(4)
	await _shot("m16_4_hud_gap")
	main.stats.record_kill("swordsman")
	main.stats.record_kill("swordsman")
	main.stats.record_kill("rusher")
	main.stats.record_kill("gunner")
	for i in 12:
		main.stats.record_shot()
	for i in 7:
		main.stats.record_hit(true)
	main.stats.tick(83.0)
	main.kills = 4
	main.score.score = 980
	main.mode.kills = 25
	main.mode.time_left = 12.0
	var r: Dictionary = main.build_result("CHIẾN THẮNG!", true, 1100, 1250, false)
	main.game_over.show_result(r)
	await _frames(4)
	await _shot("m16_5_tong_ket")
	main.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shoot_m16.cfg"))
	quit(0)
