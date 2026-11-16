extends SceneTree
## Chụp toàn cảnh 3 đấu trường (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_m11.gd -- docs/screenshots

var out_dir: String = "docs/screenshots"


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var Maps = load("res://scripts/maps.gd")
	for id in Maps.IDS:
		var arena: Node3D = load("res://scripts/arena.gd").new()
		arena.map_id = id
		root.add_child(arena)
		var cam := Camera3D.new()
		arena.add_child(cam)
		var h: Vector2 = arena.half
		var far: float = maxf(h.x, h.y)
		cam.fov = 70.0
		cam.position = Vector3(h.x * 0.9, far * 1.1, far * 1.5)
		cam.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
		cam.far = 400.0
		cam.current = true
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/m11_%s.png" % [out_dir, id])
		print("saved ", id)
		arena.queue_free()
		await process_frame
	quit()
