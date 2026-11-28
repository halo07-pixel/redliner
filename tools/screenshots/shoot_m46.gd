extends SceneTree
## Ảnh tĩnh M46: 3 vật nhặt low poly cạnh nhau + cửa sổ module ban đêm (tầng 4). Chạy dưới Xvfb (GL dự phòng):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot_m46.gd -- docs/screenshots

func _initialize() -> void:
	_run()


func _shot(n: String, out_dir: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
	print("saved ", n)


func _run() -> void:
	await process_frame
	var out_dir: String = "docs/screenshots"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.map_id = "endless"
	arena.floor_n = 4
	arena.bake_nav = false
	root.add_child(arena)
	var Pickup = load("res://scripts/pickup.gd")
	var sp: Vector3 = arena.spawn_point
	var kinds: Array = ["health", "ammo", "stamina"]
	for i in 3:
		var p: Area3D = Pickup.spawn(arena, sp + Vector3(-1.4 + 1.4 * i, 0.0, -4.0), kinds[i])
		p.age = -100.0
	var cam := Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	for i in 6:
		await physics_frame
	cam.global_position = sp + Vector3(0.0, 1.9, -1.0)
	cam.look_at(sp + Vector3(0.0, 0.9, -4.0), Vector3.UP)
	await _shot("m46_items", out_dir)
	cam.global_position = Vector3(-60.0, 60.0, -130.0)
	cam.look_at(Vector3(0.0, 8.0, -60.0), Vector3.UP)
	await _shot("m46_night", out_dir)
	quit()
