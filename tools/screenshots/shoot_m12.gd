extends SceneTree
## Chụp M12: vệt kiếm, sóng parry, vật nhặt, thùng nổ (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_m12.gd -- docs/screenshots

var out_dir: String = "docs/screenshots"


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(shot_name: String) -> void:
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
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(5)
	var player = main.player
	player.use_input = false
	player.global_position = Vector3(-2.0, 0.1, 2.0)
	player.rotation.y = 0.0
	await _frames(20)
	# Vật nhặt + thùng nổ phía trước (yard: thùng nổ ở (-8,0,-4), (6,0,-18); thùng gỗ (4,0,4))
	var P = load("res://scripts/pickup.gd")
	P.spawn(main, Vector3(-3.0, 0.1, -2.0), "health")
	P.spawn(main, Vector3(-1.0, 0.1, -2.5), "ammo")
	P.spawn(main, Vector3(1.0, 0.1, -2.0), "stamina")
	await _frames(10)
	await _shot("m12_1_pickups_thung")
	# Vệt kiếm giữa pha chém
	Engine.time_scale = 0.12 # render GL chậm: làm chậm game để bắt được giữa cú chém
	player.combat.want_heavy = true
	await _frames(2)
	player.combat.want_heavy = false
	var trail = null
	for ch in player.melee.get_children():
		if ch.has_method("point_count"):
			trail = ch
	# chụp khi vệt đang dài nhất
	var best: int = 0
	for i in 40:
		await physics_frame
		await process_frame
		if trail.point_count() >= 6:
			break
	await _shot("m12_2_vet_kiem")
	Engine.time_scale = 1.0
	await _frames(80)
	# Sóng parry
	var Fx = load("res://scripts/fx.gd")
	var pos: Vector3 = player.head.global_position - player.head.global_transform.basis.z * 2.0
	Fx.ring(main, pos, Color(0.5, 0.9, 1.0, 0.9), -player.head.global_transform.basis.z)
	await _frames(6)
	await _shot("m12_3_song_parry")
	await _frames(30)
	# Thùng nổ
	player.global_position = Vector3(-8.0, 0.1, 8.0)
	await _frames(10)
	var barrel = main.arena.props[0]
	barrel.hurtbox.take_hit({"damage": 99.0, "kind": "hitscan", "source": player, "direction": Vector3.FORWARD})
	await _frames(8)
	await _shot("m12_4_thung_no")
	quit()
