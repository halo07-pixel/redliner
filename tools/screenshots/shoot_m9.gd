extends SceneTree
## Chụp HUD stamina dash và cú ground slam (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_m9.gd -- docs/screenshots

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
	main.waves.wave = 2
	main.waves.start()
	await _frames(40)
	player.velocity = Vector3(0, 0, -8)
	player.want_dash = true
	await _frames(8)
	await _shot("m9_1_stamina_dash")
	player.global_position = Vector3(0.0, 9.0, 12.0)
	player.velocity = Vector3.ZERO
	player.head.rotation.x = deg_to_rad(-35.0)
	await _frames(3)
	player.want_slam = true
	await _frames(6)
	await _shot("m9_2_ground_slam_roi")
	await _frames(20)
	await _shot("m9_3_ground_slam_cham_dat")
	quit()
