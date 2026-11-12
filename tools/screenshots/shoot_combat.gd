extends SceneTree
## Chụp màn hình chiến đấu (cần cửa sổ, ví dụ dưới Xvfb):
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot_combat.gd -- docs/screenshots

var out_dir: String = "docs/screenshots"
var main: Node3D
var player


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
	print("saved ", shot_name)


func _teleport(pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	player.global_position = pos
	player.rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	player.head.rotation.x = deg_to_rad(pitch_deg)
	player.velocity = Vector3.ZERO
	await _frames(20)


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(5)
	player = main.player
	player.use_input = false
	var bia = main.arena.dummies[0]     # bia đỏ tại (0,0,-12)
	var cannon = load("res://scripts/enemy_dummy.gd").new() # bia phụ màu cam, dùng để bắn đạn
	cannon.color = Color(0.95, 0.55, 0.1)
	cannon.position = Vector3(-9.0, 0.0, -16.0)
	cannon.rotation.y = PI
	main.arena.add_child(cannon)
	await _frames(3)

	# 6. Vung kiếm trúng bia
	await _teleport(Vector3(0.0, 0.1, -9.6), 0.0, 0.0)
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	await _frames(8)
	await _shot("6_kiem_trung_bia")
	await _frames(40)

	# 7. Parry đạn: đạn cam bay tới, parry đúng lúc -> đạn xanh bay ngược lại
	await _teleport(Vector3(-9.0, 0.1, 4.0), 0.0, 0.0)
	var b = cannon.shoot_at(player.global_position + Vector3(0.0, 1.2, 0.0))
	var guard: int = 0
	while is_instance_valid(b) and b.global_position.distance_to(player.global_position + Vector3(0, 1.2, 0)) > 4.5 and guard < 200:
		await physics_frame
		guard += 1
	player.combat.want_parry = true
	await _frames(7)
	await _shot("7_parry_phan_dan")
	await _frames(60)

	# 8. Trúng đạn: thanh máu giảm
	player.hurtbox.take_hit({"damage": 55.0, "kind": "hitscan"})
	await _frames(3)
	await _shot("8_thanh_mau")

	# 9. Clash: hai kiếm chạm nhau
	player.hurtbox.revive()
	await _teleport(Vector3(0.0, 0.1, -10.0), 0.0, 0.0)
	player.combat.want_attack = true
	bia.swing()
	await _frames(1)
	player.combat.want_attack = false
	await _frames(9)
	await _shot("9_clash")
	await _frames(60)

	# 10. Chết
	player.hurtbox.take_hit({"damage": 999.0, "kind": "hitscan"})
	await _frames(3)
	await _shot("10_chet")
	quit()
