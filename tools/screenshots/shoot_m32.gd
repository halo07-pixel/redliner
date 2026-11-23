extends SceneTree
## Chụp M32: người que glTF chạy/đứng với clip CC0 (trái) so với toàn bằng code (phải), nhìn ngang:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot_m32.gd -- docs/screenshots/m32
## Ảnh <tên>_<mili giây>.png; ghép bằng tools/screenshots/contact_sheet.py.

var out_dir: String = "docs/screenshots/m32"
const DT: float = 1.0 / 60.0


func _initialize() -> void:
	_run()


func _shot(n: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])


func _mq(kind: String, z: float, clips: bool) -> Node3D:
	var m = load("res://scripts/mannequin_gltf.gd").new()
	m.kind = kind
	root.add_child(m)
	m.position = Vector3(0.0, 0.0, z)
	m.animator.clips_enabled = clips
	return m


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var floor_ := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor_.mesh = pm
	root.add_child(floor_)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.5, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	root.add_child(env)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 38.0
	await process_frame
	cam.look_at_from_position(Vector3(5.2, 1.1, 0.0), Vector3(0.0, 0.95, 0.0), Vector3.UP)
	var kinds: Array = ["swordsman", "gunner"]
	for kind in kinds:
		var a := _mq(kind, -1.3, true)    # trái màn hình (nhìn từ +X, -Z ở bên trái): clip
		var b := _mq(kind, 1.3, false)    # phải: chỉ code
		for state in [["idle", 0.0, "", 80], ["run", 4.8, "", 80], ["cover", 0.0, "cover", 90]]:
			for i in int(state[3]):
				a.animate(DT, state[1], true, 0.0, state[2])
				b.animate(DT, state[1], true, 0.0, state[2])
				if i >= 40 and (i - 40) % 10 == 0 and i < 40 + 40:
					await _shot("%s_%s_%03d" % [kind, state[0], int((i - 40) * 16.7)])
		a.queue_free()
		b.queue_free()
	quit()
