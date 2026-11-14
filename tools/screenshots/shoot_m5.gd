extends SceneTree
## Chụp màn hình mốc 5 (menu, hướng dẫn, HUD Redline, tạm dừng, tổng kết). Cần cửa sổ (Xvfb):
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot_m5.gd -- docs/screenshots

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
	await process_frame # đợi autoload nạp xong rồi mới đặt điểm giả
	var G: Node = root.get_node("Global")
	G.save_path = "user://shot_m5.cfg"
	G.high_score = 2450

	# 15-16. Menu chính + hướng dẫn
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await _frames(5)
	await _shot("15_menu_chinh")
	menu.show_help()
	await _frames(3)
	await _shot("16_huong_dan")
	menu.queue_free()
	await process_frame

	# 17. HUD đầy đủ ở trạng thái REDLINE, máu thấp, có chỉ báo hướng đòn
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(5)
	var player = main.player
	player.use_input = false
	player.global_position = Vector3(0.0, 0.1, 18.0)
	main.waves.wave = 2
	main.waves._next_wave()
	await _frames(30)
	player.instability.add(500.0)           # vào Redline
	player.hurtbox.take_hit({"damage": 70.0, "kind": "hitscan"}) # máu thấp -> viền đỏ
	main.hud.show_hit_indicator(deg_to_rad(60.0))
	main.score.register_kill(100, {})
	main.score.register_kill(150, {})
	await _frames(4)
	await _shot("17_hud_redline")

	# 18. Menu tạm dừng
	player.hurtbox.revive()
	main._set_paused(true)
	await _frames(3)
	await _shot("18_tam_dung")
	main._set_paused(false)
	await _frames(2)

	# 19. Màn hình tổng kết khi chết
	main.kills = 9
	player.hurtbox.take_hit({"damage": 9999.0, "kind": "hitscan"})
	await create_timer(1.5, true, false, true).timeout
	await _shot("19_tong_ket")
	paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_m5.cfg"))
	quit()
