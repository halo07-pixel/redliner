extends SceneTree
## Ảnh tĩnh M45: module bản đồ Vô Tận (toà nhà 3 kiểu, cột, bệ). Chạy dưới Xvfb (GL dự phòng, không phải Forward+):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot_m45.gd -- docs/screenshots

var out_dir: String = "docs/screenshots"


func _initialize() -> void:
	_run()


func _shot(n: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
	print("saved ", n)


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var Maps = load("res://scripts/maps.gd")
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.map_id = "endless"
	arena.floor_n = 1
	arena.bake_nav = false
	root.add_child(arena)
	var cam := Camera3D.new()
	cam.far = 700.0
	cam.fov = 70.0
	root.add_child(cam)
	cam.current = true
	for i in 4:
		await physics_frame
	var m: Dictionary = Maps.endless(1)
	var wall: Dictionary = {}
	var pillar: Dictionary = {}
	var stage: Dictionary = {}
	for b in m["boxes"]:
		if b["role"] == "wall" and wall.is_empty() and (b["size"] as Vector3).y > 18.0:
			wall = b
		elif b["role"] == "pillar" and pillar.is_empty():
			pillar = b
		elif b["role"] == "platform" and (b["size"] as Vector3).x >= 10.0 and stage.is_empty():
			stage = b
	var shots: Array = [["m45_building", wall, Vector3(26.0, 14.0, 38.0), 0.55], ["m45_pillar", pillar, Vector3(-14.0, 9.0, 20.0), 0.6], ["m45_stage", stage, Vector3(18.0, 9.0, 26.0), 0.0]]
	for s in shots:
		var b: Dictionary = s[1]
		if b.is_empty():
			continue
		var p: Vector3 = b["pos"]
		cam.global_position = p + (s[2] as Vector3)
		cam.look_at(p + Vector3(0.0, (b["size"] as Vector3).y * float(s[3]) - (b["size"] as Vector3).y * 0.2, 0.0), Vector3.UP)
		await _shot(s[0])
	cam.global_position = Vector3(-60.0, 70.0, -130.0)
	cam.look_at(Vector3(0.0, 8.0, -60.0), Vector3.UP)
	await _shot("m45_overview")
	quit()
