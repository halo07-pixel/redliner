extends SceneTree
## Chụp P3: sân khấu (bệ + dốc + bức che) tầng 2 Vô Tận: cận cảnh + nhìn từ trên xuống.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot_p3.gd -- docs/screenshots/p3


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var out_dir: String = "docs/screenshots/p3"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	root.get_node("Global").reduced_fx = true
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.map_id = "endless"
	arena.floor_n = 2
	arena.bake_nav = false
	root.add_child(arena)
	var cam := Camera3D.new()
	cam.far = 900.0
	cam.fov = 75.0
	root.add_child(cam)
	cam.current = true
	for i in 4:
		await physics_frame
	var c := Vector3.ZERO
	for b in load("res://scripts/maps.gd").endless(2)["boxes"]:
		if b["role"] == "platform" and (b["size"] as Vector3).y >= 1.99:
			c = b["pos"]
			break
	var shots: Array = [
		["stage_close", c + Vector3(-30.0, 9.0, 22.0), c + Vector3(0.0, 1.5, 0.0)],
		["stage_ramp", c + Vector3(26.0, 3.0, 0.0), c + Vector3(0.0, 2.0, 0.0)],
		["stage_top", c + Vector3(0.1, 60.0, 0.0), c],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP if s[0] != "stage_top" else Vector3.RIGHT)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, s[0]])
	quit()
