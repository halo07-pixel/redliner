extends SceneTree
## Chụp M13: màn Cài đặt + khoảnh khắc trèo gờ (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_m13.gd -- docs/screenshots

var out_dir: String = "docs/screenshots"


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
	print("saved ", shot_name)


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var sm = load("res://scripts/settings_menu.gd").new()
	host.add_child(sm)
	for i in 6:
		await process_frame
	print("size ", sm.size, " host ", host.size, " vp ", root.size)
	await _shot("m13_1_cai_dat")
	host.queue_free()
	await process_frame
	# Trèo gờ: bệ cao 1.5 m trong đấu trường
	var arena: Node3D = load("res://scripts/arena.gd").new()
	root.add_child(arena)
	var b := StaticBody3D.new()
	b.collision_layer = Global.L_WORLD
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(8, 1.5, 6)
	c.shape = s
	b.add_child(c)
	var bm := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = s.size
	mesh.material = load("res://scripts/materials.gd").make("platform")
	bm.mesh = mesh
	b.add_child(bm)
	b.position = Vector3(0, 0.75, 6)
	arena.add_child(b)
	var player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = Vector3(0, 0.4, 9.4)
	player.rotation.y = 0.0
	player.camera.current = true
	await _frames(3)
	Engine.time_scale = 0.15 # render GL chậm: làm chậm game để bắt giữa lúc trèo
	player.velocity = Vector3(0, -1, -5)
	player.move_input = Vector2(0, -1)
	for i in 80:
		await physics_frame
		await process_frame
		if player.state == player.State.LEDGE and player.global_position.y > 1.0:
			break
	print("state ", player.state, " y ", player.global_position.y)
	await _shot("m13_2_treo_ge")
	Engine.time_scale = 1.0
	quit()
