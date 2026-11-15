extends SceneTree
## Chụp các tư thế hoạt ảnh thân cạnh nhau (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_poses.gd -- docs/screenshots

var out_dir: String = "docs/screenshots"


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var arena: Node3D = load("res://scripts/arena.gd").new()
	root.add_child(arena)
	var poses: Array = [["idle", 0.0, true, ""], ["run", 7.0, true, ""], ["air", 6.0, false, ""], ["slide", 8.0, true, "slide"], ["dash", 10.0, true, "dash"], ["wallrun", 8.0, false, "wallrun"], ["grapple", 9.0, false, "grapple"]]
	var xs: float = -(poses.size() - 1) * 0.75
	for i in poses.size():
		var m: Node3D = load("res://scripts/mannequin.gd").new()
		m.color = Color(0.85, 0.2, 0.2)
		m.kind = "swordsman"
		m.position = Vector3(xs + 1.5 * i, 0.0, 6.0)
		m.rotation.y = -PI * 0.5 # nhìn ngang để thấy tư thế
		arena.add_child(m)
		await process_frame
		for f in 90:
			m.animate(1.0 / 60.0, poses[i][1], poses[i][2], 0.0 if poses[i][0] != "air" else -5.0, poses[i][3], 1.0)
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.global_position = Vector3(0.0, 1.3, 16.0)
	cam.look_at(Vector3(0.0, 1.0, 6.0))
	cam.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/m7_2_cac_tu_the.png" % out_dir)
	print("saved m7_2_cac_tu_the")
	quit()
