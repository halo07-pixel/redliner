extends SceneTree
## Chụp M34: bản đồ Vô Tận (nhìn từ trên xuống, ngang phố, cổng ra):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot_m34.gd -- docs/screenshots/m34

var out_dir: String = "docs/screenshots/m34"


func _initialize() -> void:
	_run()


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])


func _run() -> void:
	await process_frame   # root chưa "trong cây" trong _initialize: đặt global_position trước đó bị bỏ qua
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.map_id = "endless"
	arena.floor_n = 3
	arena.bake_nav = false
	root.add_child(arena)
	var portal: Area3D = load("res://scripts/portal.gd").new()
	root.add_child(portal)
	portal.global_position = arena.exit_point
	portal.set_open(true)
	var cam := Camera3D.new()
	cam.far = 900.0
	root.add_child(cam)
	cam.current = true
	for i in 5:
		await physics_frame
	cam.global_position = Vector3(0, 330, 0.1)
	cam.look_at(Vector3(0, 0, 0), Vector3.UP)
	cam.fov = 60.0
	await _shot("top_down")
	var sp: Vector3 = arena.spawn_point
	cam.global_position = sp + Vector3(0, 1.7, 0)
	cam.look_at(Vector3(0, 6, 0), Vector3.UP)
	cam.fov = 80.0
	await _shot("from_spawn")
	cam.global_position = arena.exit_point + Vector3(-sign(arena.exit_point.x) * 22.0, 14.0, -sign(arena.exit_point.z) * 22.0)
	cam.look_at(arena.exit_point + Vector3(0, 6, 0), Vector3.UP)
	await _shot("portal_open")
	portal.set_open(false)
	await _shot("portal_locked")
	quit()
