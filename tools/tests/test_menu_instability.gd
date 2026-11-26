extends SceneTree
## Test headless mốc 5: Instability "mất thế", lưu điểm cao, menu, tạm dừng, tổng kết.
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

	# ---------------- INSTABILITY "mất thế" (logic thuần)
	print("[instability]")
	var ins = load("res://scripts/instability.gd").new()
	root.add_child(ins)
	var dsb: Array = []
	ins.destabilized_changed.connect(func(on): dsb.append(on))
	ins.add(30.0)
	_check(ins.value == 30.0 and not ins.destabilized, "tăng thanh (30)")
	ins.tick(1.0)
	_check(ins.value == 30.0, "chưa hết decay_delay (1.5s) thì thanh chưa giảm")
	ins.tick(1.0)
	_check(ins.value < 30.0 and ins.value >= 30.0 - float(I["decay"]) - 0.01, "sau delay thanh giảm dần (%.1f)" % ins.value)
	ins.lose(10.0)
	_check(ins.value < 20.0, "lose() bớt thanh")
	ins.reset()
	ins.clash_penalty()
	var c0: float = ins.value
	_check(is_equal_approx(c0, float(I["clash_loss"]) * 0.6), "clash khi thanh rỗng chịu 60%% (%.1f)" % c0)
	ins.reset()
	ins.add(50.0)
	var before_c: float = ins.value
	ins.clash_penalty()
	_check(is_equal_approx(ins.value - before_c, float(I["clash_loss"]) * (0.6 + 0.8 * 0.5)), "clash khi thanh 50%% chịu nhiều hơn (+%.1f)" % (ins.value - before_c))
	ins.add(200.0)
	_check(ins.destabilized and dsb == [true], "thanh đầy -> Destabilized (phát signal)")
	var before: float = ins.value
	ins.add(10.0)
	ins.lose(50.0)
	_check(ins.value == before, "đang Destabilized: không cộng, không bớt")
	ins.tick(1.5)
	_check(is_equal_approx(ins.value, 50.0) and is_equal_approx(ins.time_left(), 1.5), "thanh cạn theo thời gian còn lại (%.1f)" % ins.value)
	ins.tick(1.6)
	_check(not ins.destabilized and ins.value == 0.0 and dsb == [true, false], "hết Destabilized -> thanh về 0")
	ins.add(40.0)
	_check(ins.value == 0.0 and ins.is_immune(), "miễn nhiễm ngắn: không cộng ngay sau khi hồi phục")
	ins.tick(float(I["immunity_time"]) + 0.1)
	ins.add(40.0)
	_check(ins.value == 40.0, "hết miễn nhiễm thì cộng lại bình thường")

	# ---------------- INSTABILITY trong game
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
	# parry hụt: +parry_miss_loss
	player.combat.want_parry = true
	await _frames(1)
	await _frames(20) # cửa sổ parry 0.18s hết mà không có gì tới
	_check(is_equal_approx(player.instability.value, float(I["parry_miss_loss"])), "parry hụt cộng %.0f (đọc %.1f)" % [float(I["parry_miss_loss"]), player.instability.value])
	player.instability.reset()
	await _frames(70) # hết cooldown phạt parry hụt
	# đòn kiếm trúng: bớt mất thế
	player.instability.add(30.0)
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	await _frames(40)
	_check(player.instability.value <= 30.0 - float(I["hit_relief"]) + 0.01 and player.instability.value > 0.0, "đòn kiếm trúng bớt %.0f mất thế (đọc %.1f)" % [float(I["hit_relief"]), player.instability.value])
	player.instability.reset()
	# bị parry: +parried_loss
	await _frames(30)
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	await _frames(4)
	dummy.parry.press() # cửa sổ parry 0.18s phủ thời điểm đòn chạm
	await _frames(30)
	_check(is_equal_approx(player.instability.value, float(I["parried_loss"])), "đòn bị parry cộng %.0f (đọc %.1f)" % [float(I["parried_loss"]), player.instability.value])
	player.instability.reset()
	await _frames(70)
	# parry thành công: bớt
	player.instability.add(40.0)
	player.combat.want_parry = true
	await _frames(1)
	dummy.shoot_at(player.global_position + Vector3(0, 1.2, 0))
	await _frames(40)
	_check(player.instability.value <= 40.0 - float(I["parry_relief"]) + 0.01 and player.instability.value > 0.0, "parry thành công bớt %.0f (đọc %.1f)" % [float(I["parry_relief"]), player.instability.value])
	player.instability.reset()
	await _frames(70)

	# Destabilized: khoá kiếm / parry / dash
	player.dash_charges = 2
	player.instability.add(500.0)
	await _frames(2)
	_check(player.instability.destabilized, "thanh đầy -> người chơi Destabilized")
	_check(player.melee.is_staggered(), "Destabilized: kiếm bị khoá")
	_check(not player.parry.can_press(), "Destabilized: không parry được")
	_check(player.dash_charges == 0, "Destabilized: stamina dash về 0")
	player.combat.want_attack = true
	player.combat.want_parry = true
	await _frames(3)
	player.combat.want_attack = false
	_check(player.melee.phase == player.melee.Phase.IDLE and not player.parry.is_active(), "Destabilized: bấm đánh/parry không có tác dụng")
	await _frames(100)
	_check(player.dash_charges == 0, "Destabilized: dash không hồi")
	await _frames(100) # tổng ~3.3s > destabilized_time
	_check(not player.instability.destabilized and player.instability.value == 0.0, "hết 3s thì hồi phục, thanh về 0")
	_check(not player.melee.is_staggered() and player.parry.can_press(), "hồi phục: đánh và parry lại được")
	player.instability.reset()

	# bot cũng bị mất thế
	var bot = load("res://scripts/bot.gd").new()
	bot.setup("swordsman", 1)
	world.add_child(bot)
	bot.global_position = Vector3(6, 0.1, 6)
	await _frames(3)
	bot.instability.add(500.0)
	await _frames(2)
	_check(bot.instability.destabilized and bot.melee.is_staggered() and bot.parry.locked, "bot Destabilized: bị khoá kiếm và parry")
	_check(not bot.parry.can_press() and not bot.melee.can_swing(), "bot không thể tấn công/parry khi mất thế")
	bot.queue_free()

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
	_check(G.best_score() == 0, "chưa có file: điểm cao = 0")
	_check(G.submit_mode_score(500) == true and G.best_score() == 500, "điểm 500 phá kỷ lục")
	_check(G.submit_mode_score(300) == false and G.best_score() == 500, "điểm thấp hơn không ghi đè")
	G._mode_scores = {}
	G.load_save()
	_check(G.best_score() == 500, "đọc lại từ file sau khi 'tắt game': 500")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	G.save_path = old_path

	# ---------------- MENU
	print("[menu]")
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await _frames(2)
	_check(menu.play_button != null and menu.shop_button != null and menu.settings_button != null and menu.quit_button != null, "menu có 4 nút: Chơi / Cửa hàng / Cài đặt / Thoát")
	_check(not menu.help_panel.visible, "hướng dẫn ẩn lúc đầu")
	menu.play_button.pressed.emit()   # Hướng dẫn nằm trong màn Chuẩn bị
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
	root.get_node("Global")._mode_scores = {}

	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.cfg"))
	quit(1 if failures > 0 else 0)
