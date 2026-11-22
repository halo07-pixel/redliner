extends SceneTree
## Chụp M24: Titan trên Khu phố:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_m24.gd -- docs/screenshots/m24

var out_dir: String = "docs/screenshots/m24"


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
	var t = load("res://scripts/titan.gd").new()
	t.setup("titan", 5)
	t.position = Vector3(0, 0.1, 32)
	root.add_child(t)
	var cam := Camera3D.new()
	cam.far = 400.0
	root.add_child(cam)
	cam.current = true
	for i in 10:
		await physics_frame
	t.set_physics_process(false)
	cam.global_position = Vector3(-6, 1.7, 56)
	cam.look_at(Vector3(0, 6, 32), Vector3.UP)
	await _shot("titan_front")
	cam.global_position = Vector3(14, 14, 58)
	cam.look_at(Vector3(0, 6, 32), Vector3.UP)
	await _shot("titan_high")
	quit()
