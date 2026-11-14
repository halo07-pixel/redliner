extends SceneTree
## Chụp 3 loại bot + bia cạnh nhau, cận và xa (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_characters.gd -- docs/screenshots

var out_dir: String = "docs/screenshots"


func _shot(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, shot_name])
	print("saved ", shot_name)


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
	var kinds: Array = ["dummy", "swordsman", "gunner", "elite"]
	var colors: Array = [Color(0.85, 0.2, 0.2), Color(0.85, 0.2, 0.2), Color(0.95, 0.55, 0.1), Color(0.6, 0.25, 0.85)]
	for i in kinds.size():
		var m: Node3D = load("res://scripts/mannequin.gd").new()
		m.color = colors[i]
		m.kind = kinds[i]
		m.position = Vector3(-3.0 + 2.0 * i, 0.0, 6.0)
		m.rotation.y = PI * 0.85 # mặt hơi chếch về camera
		arena.add_child(m)
	for i in 3:
		await process_frame
	var cam := Camera3D.new()
	cam.fov = 45.0
	root.add_child(cam)
	cam.global_position = Vector3(0.0, 1.4, 11.0)
	cam.look_at(Vector3(0.0, 1.0, 6.0))
	cam.make_current()
	await _shot("m7_1_nhan_vat_can")
	cam.global_position = Vector3(0.0, 2.5, 30.0)
	cam.look_at(Vector3(0.0, 1.0, 6.0))
	cam.fov = 40.0
	await _shot("m7_1_nhan_vat_xa")
	quit()
