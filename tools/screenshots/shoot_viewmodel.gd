extends SceneTree
## Chụp góc nhìn thứ nhất: đứng, chém, bắn, nạp đạn, trượt (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_viewmodel.gd -- docs/screenshots

var out_dir: String = "docs/screenshots"
var player


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
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(5)
	player = main.player
	player.use_input = false
	player.global_position = Vector3(0.0, 0.1, 8.0)
	player.rotation = Vector3.ZERO
	await _frames(20)
	await _shot("m7_4_dung")
	var vm: Node3D = player.viewmodel
	vm.play_swing(0.2, 0.1, 0.3)
	await create_timer(0.25).timeout
	await _shot("m7_4_chem")
	await create_timer(0.6).timeout
	Engine.time_scale = 0.05 # chậm lại để bắt được khoảnh khắc chớp nòng khi render chậm
	vm.kick()
	await create_timer(0.02).timeout
	await _shot("m7_4_ban")
	Engine.time_scale = 1.0
	await create_timer(0.3).timeout
	vm.set_reloading(true)
	await create_timer(0.45).timeout
	await _shot("m7_4_nap_dan")
	quit()
