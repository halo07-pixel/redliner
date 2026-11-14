extends SceneTree
## Test headless mốc 5: Instability/Redline, lưu điểm cao, menu, tạm dừng, tổng kết.
##   timeout 240 godot --headless --path . -s tools/tests/test_menu_instability.gd

var failures: int = 0
var world: Node3D


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for c in node.get_children():
		var r := _find_button(c, text)
		if r != null:
			return r
	return null


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var I: Dictionary = Global.INSTABILITY

	# ---------------- INSTABILITY (logic thuần)
	print("[instability]")
	var ins = load("res://scripts/instability.gd").new()
	root.add_child(ins)
	var reds: Array = []
	ins.redline_changed.connect(func(on): reds.append(on))
	ins.add(30.0)
	_check(ins.value == 30.0 and not ins.redline, "đánh trúng cộng thanh (30)")
	ins.tick(1.0, 5.0)
	_check(is_equal_approx(ins.value, 30.0 - float(I["idle_decay"])), "chạy chậm thì thanh giảm dần (%.1f)" % ins.value)
	var v0: float = ins.value
	ins.tick(1.0, 20.0)
	_check(is_equal_approx(ins.value, v0 + float(I["speed_gain"])), "chạy nhanh thì thanh tăng dần (%.1f)" % ins.value)
	ins.lose(15.0)
	_check(is_equal_approx(ins.value, v0 + float(I["speed_gain"]) - 15.0), "bị đánh thì mất thanh")
	ins.add(200.0)
	_check(ins.redline and reds == [true], "thanh đầy -> vào REDLINE (phát signal)")
	var before: float = ins.value
	ins.add(10.0)
	ins.lose(50.0)
	_check(ins.value == before, "đang Redline: không tích thêm, không bị mất")
	ins.tick(3.0, 0.0)
	_check(is_equal_approx(ins.value, 50.0), "Redline cạn dần theo thời gian (%.1f)" % ins.value)
	ins.tick(3.1, 0.0)
	_check(not ins.redline and ins.value == 0.0 and reds == [true, false], "hết Redline -> thanh về 0")

	# ---------------- INSTABILITY trong game: kiếm, parry, bị đánh, Redline tăng sát thương
	print("[instability trong game]")
	world = Node3D.new()
	root.add_child(world)
	var fl := StaticBody3D.new()
	fl.collision_layer = Global.L_WORLD
	var fc := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(100, 1, 100)
	fc.shape = fs
	fl.add_child(fc)
	fl.position.y = -0.5
	world.add_child(fl)
	var player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	var dummy = load("res://scripts/enemy_dummy.gd").new()
	dummy.position = Vector3(0, 0, -2)
	dummy.rotation.y = PI
	world.add_child(dummy)
	await _frames(5)
	dummy.hurtbox.setup(Global.TEAM_ENEMY, 1000.0, dummy.parry)
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	await _frames(40)
	var decay_margin: float = float(I["idle_decay"]) * 1.0 # thanh tự giảm nhẹ trong lúc chờ 40 frame
	_check(player.instability.value > float(I["hit_gain"]) - decay_margin and player.instability.value <= float(I["hit_gain"]), "kiếm trúng cộng ~%.0f Instability (đọc %.1f sau khi giảm tự nhiên)" % [float(I["hit_gain"]), player.instability.value])
	player.hurtbox.take_hit({"damage": 10.0, "kind": "hitscan"})
	_check(player.instability.value == 0.0, "bị đánh làm mất thanh (về %.1f)" % player.instability.value)
	player.combat.want_parry = true
	await _frames(1)
	dummy.shoot_at(player.global_position + Vector3(0, 1.2, 0))
	await _frames(40)
	_check(player.instability.value > float(I["parry_gain"]) - decay_margin and player.instability.value <= float(I["parry_gain"]), "parry thành công cộng ~%.0f (đọc %.1f)" % [float(I["parry_gain"]), player.instability.value])
	player.instability.add(500.0)
	_check(player.instability.redline and is_equal_approx(player.melee.damage_mult, float(I["damage_mult"])), "Redline: kiếm tăng sát thương x%.1f" % float(I["damage_mult"]))
	var hp: float = dummy.hurtbox.health
	await _frames(30)
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	await _frames(40)
	var dealt: float = hp - dummy.hurtbox.health
	_check(is_equal_approx(dealt, float(Global.COMBAT["sword_damage"]) * float(I["damage_mult"])), "đòn kiếm trong Redline gây %.0f" % dealt)
	# dash hồi nhanh hơn khi Redline
	player.dash_charges = 0
	player._dash_recharge_t = 1.5
	await _frames(50) # 0.83s: hồi 1 lần nhanh gấp đôi (1.5/2 = 0.75s)
	_check(player.dash_charges >= 1, "Redline: dash hồi nhanh hơn (%d charge sau 0.83s)" % player.dash_charges)
	player.instability.reset()
	_check(not player.instability.redline and player.melee.damage_mult == 1.0, "reset: thoát Redline, sát thương về bình thường")

	# ---------------- COOLDOWN PARRY
	print("[parry ring]")
	var ratios: Array = []
	player.parry.cooldown_progress.connect(func(r): ratios.append(r))
	await _frames(90)
	player.parry.press()
	await _frames(30) # hụt -> phạt
	await _frames(60)
	_check(ratios.size() > 5 and ratios.back() == 1.0 and ratios.has(0.0) == false or ratios.back() == 1.0, "cooldown_progress đi từ thấp lên 1.0 (%d mẫu, cuối %.2f)" % [ratios.size(), ratios.back() if ratios.size() > 0 else -1.0])

	# ---------------- LƯU ĐIỂM CAO
	print("[lưu điểm]")
	var G: Node = root.get_node("Global")
	var test_path: String = "user://test_save_m5.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	var old_path: String = G.save_path
	G.save_path = test_path
	G.load_save()
	_check(G.high_score == 0, "chưa có file: điểm cao = 0")
	_check(G.submit_score(500) == true and G.high_score == 500, "điểm 500 phá kỷ lục")
	_check(G.submit_score(300) == false and G.high_score == 500, "điểm thấp hơn không ghi đè")
	G.high_score = 0
	G.load_save()
	_check(G.high_score == 500, "đọc lại từ file sau khi 'tắt game': 500")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	G.save_path = old_path
	G.high_score = 0

	# ---------------- MENU
	print("[menu]")
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await _frames(2)
	_check(menu.play_button != null and menu.help_button != null and menu.quit_button != null, "menu có 3 nút: Chơi / Hướng dẫn / Thoát")
	_check(not menu.help_panel.visible, "hướng dẫn ẩn lúc đầu")
	menu.help_button.pressed.emit()
	_check(menu.help_panel.visible, "bấm Hướng dẫn -> hiện bảng hướng dẫn")
	_check(_find_button(menu.help_panel, "Quay lại") != null, "bảng hướng dẫn có nút Quay lại")
	_find_button(menu.help_panel, "Quay lại").pressed.emit()
	_check(not menu.help_panel.visible, "Quay lại -> ẩn bảng")
	_check(load("res://scenes/main.tscn") is PackedScene, "scene game nạp được")
	menu.queue_free()

	# ---------------- MAIN: tạm dừng + tổng kết
	print("[tạm dừng / tổng kết]")
	player.queue_free()
	dummy.queue_free()
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(5)
	_check(not paused and not main.pause_menu.visible, "lúc đầu không tạm dừng")
	main._set_paused(true)
	_check(paused and main.pause_menu.visible, "tạm dừng: tree.paused và hiện menu tạm dừng")
	var tick0: int = Engine.get_physics_frames()
	var z0: float = main.player.global_position.z
	await _frames(10)
	_check(is_equal_approx(main.player.global_position.z, z0), "đang tạm dừng: nhân vật không cập nhật")
	main.pause_menu.resume_button.pressed.emit()
	_check(not paused and not main.pause_menu.visible, "nút Tiếp tục -> chạy lại")
	# chết -> tổng kết
	main.waves.wave = 3
	main.kills = 7
	main.score.score = 1234
	main.player.hurtbox.take_hit({"damage": 9999.0, "kind": "hitscan"})
	_check(main._over and main.player.dead, "chết -> _over")
	await create_timer(1.5, true, false, true).timeout
	_check(main.game_over.visible and paused, "hiện màn hình tổng kết và dừng game")
	var txt: String = main.game_over.summary_label.text
	_check(txt.contains("3") and txt.contains("1234") and txt.contains("7"), "tổng kết có wave 3, điểm 1234, 7 bot (%s)" % txt.replace("\n", " | "))
	_check(main.game_over.record_label.text.contains("KỶ LỤC"), "điểm 1234 > 0 -> KỶ LỤC MỚI")
	_check(_find_button(main.game_over, "Chơi lại") != null and _find_button(main.game_over, "Về menu") != null, "có nút Chơi lại và Về menu")
	paused = false
	root.get_node("Global").high_score = 0

	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.cfg"))
	quit(1 if failures > 0 else 0)
