extends SceneTree
## Chụp màn hình các tình huống di chuyển (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot.gd -- docs/screenshots

var out_dir: String = "docs/screenshots"
var main: Node3D
var player


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, shot_name])
	print("saved ", shot_name, " ", img.get_size())


func _teleport(pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	player.global_position = pos
	player.rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	player.head.rotation.x = deg_to_rad(pitch_deg)
	player.velocity = Vector3.ZERO
	player.move_input = Vector2.ZERO
	player.want_slide = false
	player.want_jump = false
	player.want_grapple = false
	await _frames(25)


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	player = main.player
	player.use_input = false
	var player_cam: Camera3D = player.get_node("Head/Camera")

	# 1. Tổng quan đấu trường từ trên cao
	var cam := Camera3D.new()
	cam.fov = 70.0
	root.add_child(cam)
	cam.global_position = Vector3(0.0, 30.0, 40.0)
	cam.look_at(Vector3(0.0, 2.0, -6.0))
	cam.make_current()
	await _shot("1_arena_tong_quan")
	player_cam.make_current()
	cam.queue_free()

	# 2. Trượt xuống dốc
	await _teleport(Vector3(22.0, 6.5, -16.0), 180.0, -12.0)
	player.velocity += Vector3(0.0, 0.0, 7.0)
	player.want_slide = true
	await _frames(28)
	await _shot("2_slide_xuong_doc")

	# 3. Chạy tường
	await _teleport(Vector3(-20.6, 6.0, 6.0), 0.0, 0.0)
	player.velocity = Vector3(0.0, 0.0, -14.0)
	player.move_input = Vector2(0.0, -1.0)
	await _frames(22)
	await _shot("3_wallrun")

	# 4. Móc lên bục vàng
	await _teleport(Vector3(0.0, 0.1, 5.0), 0.0, 12.0)
	player.want_grapple = true
	await _frames(14)
	await _shot("4_grapple")
	player.want_grapple = false

	# 5. Dash trên không (HUD: speed tăng vọt, charge giảm; trên không thì quán tính được giữ)
	await _teleport(Vector3(0.0, 0.1, 18.0), 0.0, 0.0)
	player.move_input = Vector2(0.0, -1.0)
	player.want_jump = true
	await _frames(3)
	player.want_jump = false
	player.want_dash = true
	await _frames(1)
	await _shot("5_dash")
	quit()
