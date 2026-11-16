extends SceneTree
## Chụp người que GodoDude + vũ khí thật: tư thế gốc, chạy, chém, bắn (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_stickman.gd -- docs/screenshots

var out_dir: String = "docs/screenshots"


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var arena: Node3D = load("res://scripts/arena.gd").new()
	root.add_child(arena)
	var kinds: Array = [["swordsman", Color(0.85, 0.25, 0.2)], ["elite", Color(0.9, 0.7, 0.2)], ["gunner", Color(0.25, 0.5, 0.9)]]
	var ms: Array = []
	for i in kinds.size():
		var m: Node3D = load("res://scripts/mannequin_gltf.gd").new()
		m.color = kinds[i][1]
		m.kind = kinds[i][0]
		m.position = Vector3(-1.6 + 1.6 * i, 0.0, 6.0)
		m.rotation.y = -PI * 0.5
		arena.add_child(m)
		ms.append(m)
	await process_frame
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.global_position = Vector3(0.0, 1.2, 10.5)
	cam.look_at(Vector3(0.0, 1.0, 6.0))
	cam.make_current()
	var shots: Array = [["1_dung", 0.0, ""], ["2_chay", 7.0, ""], ["3_chem_ban", 0.0, "act"]]
	for s in shots:
		for m in ms:
			m.clear_overlay()
		for f in 60:
			for m in ms:
				m.animate(1.0 / 60.0, s[1], true, 0.0)
			await physics_frame
		if s[2] == "act":
			for m in ms:
				m.play("shoot" if m.kind == "gunner" else "swing", 0.6, {"windup": 0.25, "active": 0.1, "recovery": 0.25})
			for f in 22:
				for m in ms:
					m.animate(1.0 / 60.0, 0.0, true, 0.0)
				await physics_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/m7_7_%s.png" % [out_dir, s[0]])
		print("saved ", s[0])
	quit()
