extends SceneTree
## Chụp M20: bám chân trên bậc, tay đỡ báng, nhìn mục tiêu, clash/parry/trúng đầu của bot (glTF):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_m20.gd -- docs/screenshots/m20

const DT: float = 1.0 / 60.0
var out_dir: String = "docs/screenshots/m20"
var world: Node3D
var cam: Camera3D


func _initialize() -> void:
	_run()


func _shot(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])


func _box(center: Vector3, size: Vector3, col: Color) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	b.add_child(mi)
	b.position = center
	world.add_child(b)


func _bot(kind: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var m: Node3D = load("res://scripts/mannequin_gltf.gd").new()
	m.kind = kind
	m.position = pos
	m.rotation_degrees.y = yaw_deg
	world.add_child(m)
	return m


func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = Node3D.new()
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.65, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	world.add_child(env)
	cam = Camera3D.new()
	world.add_child(cam)
	cam.current = true
	_box(Vector3(0.0, -0.5, 0.0), Vector3(14.0, 1.0, 14.0), Color(0.4, 0.42, 0.45))
	_box(Vector3(-0.11, 0.125, 0.0), Vector3(0.2, 0.25, 1.0), Color(0.75, 0.55, 0.3))   # bậc dưới chân trái
	await physics_frame
	await physics_frame

	# 1. Bám chân: kiếm sĩ đứng nhìn từ sau-phải (bậc 0.25 dưới chân trái)
	var sm: Node3D = _bot("swordsman", Vector3(0.0, 0.0, 0.0))
	await physics_frame
	for i in 90:
		sm.animate(DT, 0.0, true, 0.0)
	_look(Vector3(2.0, 0.5, 1.8), Vector3(0.0, 0.45, 0.0))
	await _shot("chan_bac_truoc")
	sm.ik_feet = false
	sm.animator.ik.foot_off = [0.0, 0.0]
	sm.animator.ik.hip_off = 0.0
	for i in 90:
		sm.animate(DT, 0.0, true, 0.0)
	await _shot("chan_bac_tat_ik")
	sm.queue_free()

	# 2. Tay đỡ báng + nhìn mục tiêu cao
	var gm: Node3D = _bot("gunner", Vector3(3.0, 0.0, 0.0))
	await physics_frame
	gm.set_look_target(Vector3(3.5, 2.6, -4.0))
	for i in 90:
		gm.animate(DT, 0.0, true, 0.0)
	_look(Vector3(5.2, 1.4, -1.6), Vector3(3.0, 1.2, -0.3))
	await _shot("xa_thu_do_bang")
	G_tune(0.0)
	for i in 90:
		gm.animate(DT, 0.0, true, 0.0)
	await _shot("xa_thu_khong_ik_tay")
	G_tune(-1.0)

	# 3. Clash / parry / trúng đầu
	var cm: Node3D = _bot("swordsman", Vector3(-3.0, 0.0, 0.0))
	await physics_frame
	for i in 60:
		cm.animate(DT, 0.0, true, 0.0)
	cm.play("clash", 0.5, {"direction": Vector3(0.0, 0.0, 1.0)})
	for i in 5:
		cm.animate(DT, 0.0, true, 0.0)
	_look(Vector3(-1.2, 1.3, 2.6), Vector3(-3.0, 1.0, 0.0))
	await _shot("clash_05")
	for i in 20:
		cm.animate(DT, 0.0, true, 0.0)
	await _shot("clash_25")
	cm.clear_overlay()
	for i in 60:
		cm.animate(DT, 0.0, true, 0.0)
	cm.play("hurt", 0.25, {"direction": Vector3(0.0, 0.0, 1.0), "zone": "head"})
	for i in 7:
		cm.animate(DT, 0.0, true, 0.0)
	await _shot("trung_dau")
	print("saved ", out_dir)
	quit()


func G_tune(v: float) -> void:
	var g: Node = root.get_node("Global")
	if v < 0.0:
		g.tune.clear()
	else:
		g.tune["a.support_hand"] = v
