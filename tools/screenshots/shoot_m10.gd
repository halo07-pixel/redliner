extends SceneTree
## Chụp 4 súng ở góc nhìn người chơi + vụ nổ pháo (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_m10.gd -- docs/screenshots

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
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(5)
	var player = main.player
	player.use_input = false
	player.global_position = Vector3(0.0, 0.1, 18.0)
	await _frames(20)
	var i: int = 1
	for id in Global.WEAPON_ORDER:
		player.combat.switch_to(id)
		await _frames(40) # đợi rút súng xong
		await _shot("m10_%d_%s" % [i, id])
		i += 1
	# Pháo nổ: 3 kẻ địch phía trước, bắn xuống đất giữa họ
	main.waves.wave = 2
	main.waves._next_wave()
	await _frames(30)
	player.combat.switch_to("launcher")
	await _frames(40)
	player.head.rotation.x = deg_to_rad(-8.0)
	player.combat._shot_cd = 0.0
	player.combat.want_shoot = true
	await _frames(1)
	player.combat.want_shoot = false
	await _frames(22)
	await _shot("m10_5_phao_no")
	quit()
