extends SceneTree
## Chụp P2: 6 chủ đề tầng Vô Tận (từ chỗ xuất phát nhìn về cổng):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot_p2.gd -- docs/screenshots/p2

var out_dir: String = "docs/screenshots/p2"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	root.get_node("Global").reduced_fx = true   # áp chủ đề tức thì
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.map_id = "endless"
	arena.floor_n = 1
	arena.bake_nav = false
	root.add_child(arena)
	var cam := Camera3D.new()
	cam.far = 900.0
	cam.fov = 80.0
	root.add_child(cam)
	cam.current = true
	for f in range(1, 7):
		if f > 1:
			arena.load_floor(f)
		for i in 4:
			await physics_frame
		var sp: Vector3 = arena.spawn_point
		cam.global_position = sp + Vector3(0, 12.0, 0)
		cam.look_at(sp + Vector3(-sign(sp.x) * 40.0, 4.0, -sign(sp.z) * 40.0), Vector3.UP)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/floor%d.png" % [out_dir, f])
	quit()
