extends SceneTree
## Chụp tổng quan đấu trường ở 3 mức đồ họa (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_quality.gd -- docs/screenshots

var out_dir: String = "docs/screenshots"


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var g: Node = root.get_node("Global")
	g.save_path = "user://shoot_quality.cfg" # không đụng file lưu thật
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	for i in 5:
		await physics_frame
	var cam := Camera3D.new()
	cam.fov = 70.0
	root.add_child(cam)
	cam.global_position = Vector3(0.0, 30.0, 40.0)
	cam.look_at(Vector3(0.0, 2.0, -6.0))
	cam.make_current()
	for level in [0, 1, 2]:
		g.set_quality(level)
		for i in 5:
			await physics_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_viewport().get_texture().get_image()
		var path := "%s/m6_3_chat_luong_%s.png" % [out_dir, ["thap", "vua", "cao"][level]]
		img.save_png(path)
		print("saved ", path, " ", img.get_size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(g.save_path))
	quit()
