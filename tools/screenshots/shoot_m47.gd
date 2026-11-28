extends SceneTree
## Ảnh tĩnh M47: hàng 5 loại bot + Titan (thân low poly) và viewmodel. Chạy dưới Xvfb (GL dự phòng, không phải Forward+):
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
	# 5 tư thế lấy từ clip Blender: đứng yên | cuối lấy đà | cuối cú chém | bắn (đỉnh giật) | choáng
	var cases: Array = [
		["swordsman", -4.5, "", 0.0], ["swordsman", -2.3, "swing", 0.3], ["swordsman", -0.1, "swing", 0.4],
		["gunner", 2.1, "shoot", 0.02], ["elite", 4.3, "stagger", 0.35],
	]
	for c in cases:
		var m: Node3D = L.new()
		m.kind = c[0]
		m.color = Global.BOTS[c[0]]["color"]
		m.ik_feet = false
		m.position = Vector3(c[1], 0.0, 0.0)
		world.add_child(m)
		if c[2] != "":
			var dur: float = 0.8 if c[2] == "swing" else (0.3 if c[2] == "shoot" else 1.0)
			m.play(c[2], dur, {"windup": 0.3, "active": 0.1, "recovery": 0.4})
			for i in int(float(c[3]) * 120.0):
				m.animate(1.0 / 120.0, 0.0, true, 0.0)
		else:
			for i in 30:
				m.animate(1.0 / 60.0, 0.0, true, 0.0)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.5, -7.0)
	cam.rotation_degrees = Vector3(-4.0, 180.0, 0.0)
	cam.fov = 55.0
	world.add_child(cam)
	cam.current = true
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/m47_poses.png" % out_dir)
	print("saved m47_poses")
	quit()
