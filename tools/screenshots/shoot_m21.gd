extends SceneTree
## Chụp M21: Khu phố nhìn từ trên cao và từ điểm xuất phát:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_m21.gd -- docs/screenshots/m21

var out_dir: String = "docs/screenshots/m21"


func _initialize() -> void:
	_run()


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.map_id = "district"
	root.add_child(arena)
	var cam := Camera3D.new()
	cam.far = 400.0
	root.add_child(cam)
	cam.current = true
	for i in 10:
		await physics_frame
	cam.global_position = Vector3(0, 150, 60)
	cam.look_at(Vector3(0, 0, 0), Vector3.UP)
	await _shot("overview")
	cam.global_position = Vector3(0, 1.7, 58)
	cam.look_at(Vector3(0, 8, 0), Vector3.UP)
	await _shot("from_spawn")
	cam.global_position = Vector3(-30, 6, -10)
	cam.look_at(Vector3(-42, 8, -42), Vector3.UP)
	await _shot("tower")
	quit()
