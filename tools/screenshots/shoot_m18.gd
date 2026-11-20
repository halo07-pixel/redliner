extends SceneTree
## Chụp các tư thế viewmodel M18: nghỉ, chạy, lướt, dash, grapple, đỡ kiếm, chém:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_m18.gd -- docs/screenshots

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


func _pose(vm: Node3D, speed: float, st: String, lateral: float = 0.0) -> void:
	for i in 90:
		vm.update(1.0 / 60.0, speed, true, st, lateral)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(5)
	var player = main.player
	player.use_input = false
	player.global_position = Vector3(0.0, 0.1, 8.0)
	await _frames(10)
	player.set_process(false)
	var vm: Node3D = player.viewmodel
	_pose(vm, 0.0, "")
	await _shot("m18_nghi")
	_pose(vm, 11.0, "", 1.0)
	await _shot("m18_chay")
	_pose(vm, 12.0, "slide")
	await _shot("m18_luot")
	_pose(vm, 20.0, "dash")
	await _shot("m18_dash")
	_pose(vm, 14.0, "grapple")
	await _shot("m18_grapple")
	_pose(vm, 0.0, "")
	vm.raise()
	for i in 6:
		vm.update(1.0 / 60.0, 0.0, true, "")
	await create_timer(0.12).timeout
	await _shot("m18_do_kiem")
	quit()
