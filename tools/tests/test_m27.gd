extends SceneTree
## M27: Titan dễ thử - phím T trong Tập luyện (Khu phố), "bắt đầu từ wave N", mô tả menu, không ghi kỷ lục khi chơi thử.
##   timeout 250 godot --headless --path . -s tools/tests/test_m27.gd

var failures: int = 0
var G


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _titans() -> Array:
	var out: Array = []
	for b in get_nodes_in_group("bots"):
		if "is_titan" in b and not b.is_queued_for_deletion():
			out.append(b)
	return out


func _initialize() -> void:
	_run()


func _game(mode: String, map: String, start_wave: int = 1):
	G.set_mode(mode)
	G.set_difficulty("normal")
	G.selected_map = map
	G.start_wave = start_wave
	var m = load("res://scenes/main.tscn").instantiate()
	m.autostart_waves = false
	root.add_child(m)
	await _frames(8)
	m.player.use_input = false
	return m


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://test_m27.cfg"
	G.load_save()

	print("[menu + phím]")
	_check(G.REMAPPABLE.any(func(r): return r[0] == "spawn_titan") and InputMap.has_action("spawn_titan"), "có phím gọi Titan (T), đổi phím được")
	_check(String(G.MODE_DESCRIPTIONS["training"]).contains("T"), "mô tả Tập luyện nhắc phím T")
	var UIKit = load("res://scripts/ui_kit.gd")
	G.start_wave = 1
	var b: Button = UIKit.start_wave_button()
	_check(b.text.contains("1"), "nút wave khởi đầu: mặc định wave 1")
	b.pressed.emit()
	_check(G.start_wave == 5 and b.text.contains("5") and b.text.contains("không tính kỷ lục"), "bấm: wave 5, cảnh báo không tính kỷ lục")
	for i in 3:
		b.pressed.emit()
	_check(G.start_wave == 1, "xoay vòng 1 -> 5 -> 10 -> 15 -> 1")

	print("[tập luyện trên Khu phố]")
	var m1 = await _game("training", "district")
	_check(m1.arena.titans and m1.waves.titans_enabled, "Khu phố bật Titan")
	_check(_titans().size() == 0, "chưa gọi: không có Titan")
	m1._start_mode()
	await _frames(3)
	m1._toggle_practice_titan()
	await _frames(3)
	_check(_titans().size() == 1, "phím T: gọi một Titan")
	_check(m1.hud._boss_bar != null and m1.hud._boss_bar.visible, "thanh máu Titan hiện")
	var t = _titans()[0]
	var d: float = t.global_position.distance_to(m1.player.global_position)
	_check(d > 20.0, "Titan sinh cách người chơi %.0f m" % d)
	var others: int = get_nodes_in_group("bots").size() - 1
	m1._toggle_practice_titan()
	await _frames(3)
	_check(_titans().size() == 0 and not m1.hud._boss_bar.visible, "bấm T lần nữa: xoá Titan, ẩn thanh máu")
	_check(get_nodes_in_group("bots").size() == others, "bot tập khác không bị ảnh hưởng")
	m1.queue_free()
	await _frames(5)

	print("[tập luyện trên map nhỏ]")
	var m2 = await _game("training", "yard")
	m2._start_mode()
	await _frames(3)
	m2._toggle_practice_titan()
	await _frames(3)
	_check(_titans().size() == 0, "Sân tập: T không sinh Titan")
	m2.queue_free()
	await _frames(5)

	print("[sinh tồn bắt đầu từ wave 5]")
	var m3 = await _game("survival", "district", 5)
	m3._start_mode()
	await _frames(5)
	_check(m3.waves.wave == 5, "bắt đầu ở wave 5 (wave=%d)" % m3.waves.wave)
	_check(_titans().size() == 1, "wave 5: có Titan")
	var best0: int = G.best_score()
	_check(not G.submit_mode_score(999999), "chơi thử từ wave cao: không ghi kỷ lục")
	_check(G.best_score() == best0, "kỷ lục không đổi")
	m3.queue_free()
	await _frames(5)
	G.start_wave = 1
	var m4 = await _game("survival", "district", 1)
	m4._start_mode()
	await _frames(5)
	_check(m4.waves.wave == 1 and _titans().size() == 0, "wave 1 như cũ: chưa có Titan")
	m4.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_m27.cfg"))
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
