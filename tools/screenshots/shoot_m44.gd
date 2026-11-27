extends SceneTree
## Ảnh tĩnh M44: hàng 5 loại bot + Titan (thân low poly) và viewmodel. Chạy dưới Xvfb (GL dự phòng, không phải Forward+):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot_m44.gd -- docs/screenshots

func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir: String = "docs/screenshots"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.5, 0.58)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	world.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30.0, 10.0)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.25, 0.26, 0.3)
	floor_mi.material_override = fm
	world.add_child(floor_mi)
	var L = load("res://scripts/mannequin_lowpoly.gd")
	var kinds: Array = ["swordsman", "gunner", "elite", "rusher", "bomber", "titan"]
	var xs: Array = [-5.0, -3.0, -1.0, 1.0, 3.0, 5.5]
	for i in kinds.size():
		var m: Node3D = L.new()
		m.kind = kinds[i]
		m.color = Global.BOTS[kinds[i]]["color"] if Global.BOTS.has(kinds[i]) else Color(0.8, 0.3, 0.2)
		m.ik_feet = false
		m.position = Vector3(xs[i], 0.0, 0.0)
		world.add_child(m)
		if kinds[i] == "titan":
			m.scale = Vector3.ONE * 1.5
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.7, -8.5)
	cam.rotation_degrees = Vector3(-4.0, 180.0, 0.0)
	cam.fov = 55.0
	world.add_child(cam)
	cam.current = true
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/m44_bots.png" % out_dir)
	print("saved m44_bots")
	quit()
