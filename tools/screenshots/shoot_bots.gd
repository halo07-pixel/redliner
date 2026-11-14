extends SceneTree
## Chụp màn hình bot/wave/điểm (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot_bots.gd -- docs/screenshots

var out_dir: String = "docs/screenshots"
var main: Node3D
var player


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
	print("saved ", shot_name)


func _kill_all() -> void:
	for b in root.get_tree().get_nodes_in_group("bots"):
		if not b.dead:
			b.hurtbox.take_hit({"damage": 9999.0, "kind": "hitscan"})


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(5)
	player = main.player
	player.use_input = false
	player.global_position = Vector3(0.0, 0.1, 18.0)
	var waves = main.waves

	# 11. Wave 3: đủ 3 loại bot (đỏ = lính kiếm, cam = xạ thủ, tím = tinh nhuệ) tiến vào đấu trường
	waves.wave = 2
	waves._next_wave()
	await _frames(100)
	var cam := Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.global_position = Vector3(0.0, 20.0, 30.0)
	cam.look_at(Vector3(0.0, 0.0, -6.0))
	cam.make_current()
	await _shot("11_wave_3_dong_bot")
	cam.queue_free()
	player.camera.make_current()
	_kill_all()
	await _frames(40)
	main.score.reset()

	# 12. Lính kiếm báo đòn / chém ngay trước mặt
	var bot = load("res://scripts/bot.gd").new()
	bot.setup("swordsman", 1)
	bot.position = Vector3(0.0, 0.0, 15.8)
	main.arena.add_child(bot)
	bot.dodge_chance = 0.0
	bot.parry_chance = 0.0
	player.global_position = Vector3(0.0, 0.1, 18.0)
	var guard: int = 0
	while bot.melee.phase != bot.melee.Phase.WINDUP and guard < 300:
		await physics_frame
		guard += 1
	await _frames(14)
	await _shot("12_bot_chem")
	await _frames(60)
	bot.hurtbox.take_hit({"damage": 9999.0, "kind": "hitscan"})
	await _frames(40)
	main.score.reset()

	# 13. Hạ 2 bot liên tiếp: điểm + combo
	waves.wave = 0
	waves._next_wave()
	await _frames(3)
	var list: Array = root.get_tree().get_nodes_in_group("bots")
	list[0].hurtbox.take_hit({"damage": 9999.0, "kind": "hitscan"})
	list[1].hurtbox.take_hit({"damage": 9999.0, "kind": "melee"})
	await _frames(3)
	await _shot("13_diem_combo")

	# 14. Hạ bot cuối: WAVE XONG
	list[2].hurtbox.take_hit({"damage": 9999.0, "kind": "hitscan"})
	await _frames(3)
	await _shot("14_wave_xong")
	quit()
