extends SceneTree
## M41 "Cắt giảm": chỉ còn chế độ Vô Tận + Tập luyện, một bản đồ (lưới Vô Tận); Tập luyện chạy trên bản đồ Vô Tận tầng cố định
## với khu thử bot gần chỗ xuất phát. Menu còn 4 nút. Savegame cũ (sinh tồn / thời gian / bản đồ) vẫn nạp được.
##   timeout 290 godot --headless --path . -s tools/tests/test_m41.gd

var failures: int = 0
var G


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _wait(sec: float) -> void:
	await create_timer(sec, true, true, true).timeout


func _bots() -> Array:
	return get_nodes_in_group("bots").filter(func(b): return is_instance_valid(b) and not b.dead)


func _enter(mode_id: String) -> Node:
	G.set_mode(mode_id)
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(15)
	return main


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://m41.cfg"
	G.reduced_fx = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.save_path))
	G.load_save()
	var Maps = load("res://scripts/maps.gd")

	print("[dữ liệu: chỉ còn hai chế độ, một bản đồ]")
	_check(G.MODES == ["endless", "training"], "MODES = Vô Tận + Tập luyện")
	_check(G.game_mode == "endless", "mặc định: Vô Tận")
	var named: bool = true
	for m in G.MODES:
		named = named and G.MODE_NAMES.has(m) and G.MODE_DESCRIPTIONS.has(m)
	_check(named and G.MODE_NAMES.size() == 2 and G.MODE_DESCRIPTIONS.size() == 2, "mỗi chế độ có tên + mô tả, không còn chế độ thừa")
	_check(not Maps.has_method("get_map") and Maps.has_method("endless"), "Maps chỉ còn bản đồ Vô Tận")
	var a: Dictionary = Maps.endless(int(G.TRAINING["floor"]))
	var b: Dictionary = Maps.endless(int(G.TRAINING["floor"]))
	_check(a["boxes"].size() == b["boxes"].size() and a["spawn"] == b["spawn"] and a["exit"] == b["exit"], "tầng Tập luyện: cùng hạt giống -> cùng bản đồ")
	_check(a["half"] == Vector2(150.0, 150.0), "bản đồ lưới 6x6 ô 50 m = 300 m")

	print("[savegame cũ]")
	var cf := ConfigFile.new()
	cf.set_value("game", "mode", "survival")
	cf.set_value("game", "map", "district")
	cf.set_value("progress", "high_score", 1234)
	cf.set_value("progress", "high_score_endless_normal", 321)
	cf.set_value("meta", "gold", 77)
	cf.save(G.save_path)
	G.load_save()
	_check(G.game_mode == "endless", "mode sinh tồn trong file cũ -> Vô Tận")
	cf.set_value("game", "mode", "timed")
	cf.save(G.save_path)
	G.load_save()
	_check(G.game_mode == "endless", "mode thời gian trong file cũ -> Vô Tận")
	_check(G.gold == 77 and G.best_score("endless", "normal") == 321, "vàng và kỷ lục Vô Tận vẫn còn")
	G.set_mode("khong_co")
	_check(G.game_mode == "endless", "chế độ lạ bị bỏ qua")
	G.cycle_mode()
	_check(G.game_mode == "training", "xoay vòng -> Tập luyện")
	G.cycle_mode()
	_check(G.game_mode == "endless", "xoay vòng -> Vô Tận")
	_check(not G.submit_mode_score(999, "training") and G.best_score("training") == 0, "Tập luyện không có kỷ lục")
	G.set_mode("endless")

	print("[menu: 4 nút]")
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await _frames(2)
	var texts: Array = [menu.play_button.text, menu.shop_button.text, menu.settings_button.text, menu.quit_button.text]
	_check(texts == ["Chơi", "Cửa hàng", "Cài đặt", "Thoát"], "nút menu: %s" % str(texts))
	_check(menu.play_button.get_parent().get_children().filter(func(c): return c is Button).size() == 4, "đúng 4 nút trên menu chính")
	menu.play_button.pressed.emit()
	_check(menu.setup_panel.visible, "Chơi -> màn Chuẩn bị")
	_check(menu.mode_button.text.contains("Vô Tận"), "chế độ mặc định hiện Vô Tận")
	menu.mode_button.pressed.emit()
	_check(G.game_mode == "training" and menu.mode_desc_label.text.contains("Titan") and not menu.start_gun_button.visible, "Tập luyện: mô tả khu thử, ẩn súng khởi đầu")
	menu.mode_button.pressed.emit()
	_check(G.game_mode == "endless" and menu.start_gun_button.visible, "quay lại Vô Tận: hiện súng khởi đầu")
	menu.queue_free()
	await _frames(3)

	print("[Tập luyện trên bản đồ Vô Tận]")
	var main = await _enter("training")
	var arena = main.arena
	_check(arena.map_id == "endless" and arena.floor_n == int(G.TRAINING["floor"]), "bản đồ Vô Tận, tầng cố định %d" % int(G.TRAINING["floor"]))
	_check(main.portal == null and main.progress == null and main.level_ui == null, "không có cổng tầng, XP, thẻ nâng cấp")
	_check(not main.player.combat.locked and not main.player.combat.flaws.enabled, "mở đủ vũ khí, không lỗi súng")
	var all_guns: bool = true
	for g in G.WEAPON_ORDER:
		main.player.combat.switch_to(g)
		all_guns = all_guns and main.player.combat.weapon == g
	_check(all_guns, "chuyển được cả %d súng (kể cả súng chưa mua)" % G.WEAPON_ORDER.size())
	_check(main.player.global_position.distance_to(arena.spawn_point) < 2.0, "người chơi đứng ở chỗ xuất phát")
	_check(_bots().is_empty(), "trước khi bắt đầu: chưa có bot")
	main._start_mode()
	await _frames(3)
	var slots: Array = G.TRAINING["slots"]
	var live: Array = _bots()
	_check(live.size() == slots.size(), "khu thử sinh %d bot" % slots.size())
	var types_ok: bool = true
	var pos_ok: bool = true
	for i in slots.size():
		var want: Vector3 = arena.spawn_point + Vector3(slots[i][1].x, 0.0, slots[i][1].y)
		var found: Array = live.filter(func(bt): return bt.has_meta("practice_slot") and int(bt.get_meta("practice_slot")) == i)
		types_ok = types_ok and found.size() == 1 and String(found[0].type_name) == String(slots[i][0])
		pos_ok = pos_ok and found.size() == 1 and Vector2(found[0].position.x - want.x, found[0].position.z - want.z).length() < 3.0
	_check(types_ok, "mỗi ô một loại bot: cận chiến / xạ thủ / pháo thủ bom")
	_check(pos_ok, "bot nằm đúng ô gần chỗ xuất phát")
	var near: bool = true
	for bt in live:
		near = near and bt.global_position.distance_to(arena.spawn_point) < 30.0
	_check(near, "khu thử trong 30 m quanh chỗ xuất phát")
	var gone_pos: Vector3 = Vector3.ZERO
	var victim = live[0]
	var slot_i: int = int(victim.get_meta("practice_slot"))
	var want0: Vector3 = arena.spawn_point + Vector3(slots[slot_i][1].x, 0.0, slots[slot_i][1].y)
	victim.hurtbox.take_hit({"damage": 99999.0, "kind": "sword", "source": main.player, "direction": Vector3.FORWARD})
	await _frames(3)
	_check(victim.dead and _bots().size() == slots.size() - 1, "hạ một bot: còn %d" % (slots.size() - 1))
	await _wait(float(G.TRAINING["respawn_time"]) + 0.25)
	var back: Array = _bots().filter(func(bt): return bt.has_meta("practice_slot") and int(bt.get_meta("practice_slot")) == slot_i)
	_check(_bots().size() == slots.size() and back.size() == 1 and back[0] != victim, "bot chết hồi sinh sau %.1f s" % float(G.TRAINING["respawn_time"]))
	_check(back.size() == 1 and (back[0].get_meta("practice_home") as Vector3).distance_to(want0) < 0.01, "hồi sinh đúng chỗ cũ (ô %d)" % slot_i)
	_check(main.score.score == 0 and Global_gold_untouched(main), "Tập luyện: không điểm, không vàng")

	print("[Tập luyện: Titan bằng phím T]")
	var n_before: int = _bots().size()
	main._toggle_practice_titan()
	await _frames(3)
	var titans: Array = _bots().filter(func(bt): return "is_titan" in bt)
	_check(titans.size() == 1 and _bots().size() == n_before + 1, "T gọi một Titan")
	var tt: Vector3 = arena.spawn_point + Vector3(G.TRAINING["titan_offset"].x, 0.0, G.TRAINING["titan_offset"].y)
	_check(Vector2(titans[0].position.x - tt.x, titans[0].position.z - tt.z).length() < 8.0, "Titan ở khu thử")
	main._toggle_practice_titan()
	await _frames(3)
	_check(_bots().filter(func(bt): return "is_titan" in bt).is_empty(), "T lần nữa xoá Titan")

	print("[Tập luyện: người chơi chết -> hồi sinh, không game over]")
	main.player.global_position = arena.spawn_point + Vector3(3.0, 0.0, 3.0)
	main.player.hurtbox.take_hit({"damage": 99999.0, "kind": "bullet", "source": null, "direction": Vector3.FORWARD})
	await _frames(3)
	_check(main.player.hurtbox.health > 0.0 or main.player.dead, "trạng thái sau đòn chí mạng hợp lệ")
	main.player.hurtbox.health = 0.0
	main.player.hurtbox.died.emit()
	await _frames(3)
	_check(main.player.dead and not main._over, "chết: chưa có màn kết thúc")
	await _wait(float(G.TRAINING["player_respawn"]) + 0.8)
	_check(not main.player.dead and not main._over and not main.game_over.visible, "đã hồi sinh, không có game over")
	_check(main.player.global_position.distance_to(arena.spawn_point) < 2.0, "hồi sinh đúng chỗ xuất phát")
	_check(main.player.hurtbox.health > 0.0, "hồi sinh với máu đầy")
	main.queue_free()
	await _frames(10)

	print("[Vô Tận vẫn nguyên: cổng + XP, không khu thử]")
	var em = await _enter("endless")
	em._start_mode()
	await _frames(3)
	_check(em.portal != null and em.progress != null and em.arena.map_id == "endless", "Vô Tận: có cổng, XP")
	_check(em.arena.floor_n == 1, "Vô Tận bắt đầu ở tầng 1")
	_check(_bots().filter(func(bt): return bt.has_meta("practice_slot")).is_empty(), "Vô Tận: không có bot khu thử")
	em.queue_free()
	await _frames(10)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.save_path))
	print("")
	if failures == 0:
		print("TẤT CẢ ĐẠT")
	else:
		printerr("CÓ %d LỖI" % failures)
	quit(1 if failures > 0 else 0)


## Tập luyện không được cộng vàng chạy (run_gold chỉ tồn tại khi có XP/Vô Tận).
func Global_gold_untouched(main: Node) -> bool:
	return main.run_gold == 0
