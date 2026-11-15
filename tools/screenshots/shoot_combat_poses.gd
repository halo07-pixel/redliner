extends SceneTree
## Chụp các tư thế chiến đấu cạnh nhau (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_combat_poses.gd -- docs/screenshots

var out_dir: String = "docs/screenshots"


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var arena: Node3D = load("res://scripts/arena.gd").new()
	root.add_child(arena)
	# [tên, loại, thời điểm chụp (s) sau khi bắt đầu, dữ liệu]
	var shots: Array = [
		["swing", "swordsman", 0.3, {"windup": 0.3, "active": 0.12, "recovery": 0.3}],
		["swing", "swordsman", 0.4, {"windup": 0.3, "active": 0.12, "recovery": 0.3}],
		["parry", "swordsman", 0.12, {}],
		["shoot", "gunner", 0.04, {}],
		["hurt", "swordsman", 0.125, {"direction": Vector3(0, 0, 1)}],
		["stagger", "elite", 0.5, {}],
		["die", "swordsman", 0.45, {}],
	]
	var xs: float = -(shots.size() - 1) * 0.8 - 2.0
	for i in shots.size():
		var s: Array = shots[i]
		var m: Node3D = load("res://scripts/mannequin.gd").new()
		m.color = Color(0.85, 0.2, 0.2)
		m.kind = s[1]
		m.position = Vector3(xs + 1.6 * i, 0.0, 6.0)
		m.rotation.y = -PI * 0.5
		arena.add_child(m)
		await process_frame
		var dur: float = 0.72 if s[0] == "swing" else (1.0 if s[0] == "stagger" else 0.45)
		m.play(s[0], dur, s[3])
		var frames: int = int(s[2] * 60.0)
		for f in frames:
			m.animate(1.0 / 60.0, 0.0, true, 0.0)
	var cam := Camera3D.new()
	cam.fov = 42.0
	root.add_child(cam)
	cam.global_position = Vector3(0.0, 1.2, 17.0)
	cam.look_at(Vector3(0.0, 0.9, 6.0))
	cam.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/m7_3_tu_the_chien_dau.png" % out_dir)
	print("saved m7_3_tu_the_chien_dau")
	quit()
