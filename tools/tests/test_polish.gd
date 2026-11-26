extends SceneTree
## Test headless M17: file save hỏng/thiếu khoá -> về mặc định, phiên bản, bảng FPS,
## vào/thoát ván lặp lại không để lại node, Vô Tận chạy lâu không làm node tăng dần.
##   timeout 600 godot --headless --path . -s tools/tests/test_polish.gd

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


func _nodes() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _size(n: Node) -> int:
	var c: int = 1
	for ch in n.get_children():
		c += _size(ch)
	return c


## Số node không tính bot, vật rơi và hạt XP (chúng tăng theo cỡ wave, không phải rò rỉ).
func _static_nodes(m: Node) -> int:
	var total: int = _size(m)
	for b in get_nodes_in_group("bots"):
		total -= _size(b)
	for n in m.find_children("*", "Area3D", true, false):
		if n.get_script() != null and (String(n.get_script().resource_path).ends_with("pickup.gd") or String(n.get_script().resource_path).ends_with("xp_orb.gd")):
			total -= _size(n)
	return total


func _initialize() -> void:
	_run()


func _write(text: String) -> void:
	var f := FileAccess.open(G.save_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://polish_test.cfg"

	# --- Phiên bản
	_check(String(G.VERSION).split(".").size() == 3, "VERSION dạng x.y.z (%s)" % G.VERSION)

	# --- Save hỏng
	_write("đây không phải ConfigFile [[[ = =")
	G.load_save()
	_check(G.difficulty == "normal", "file hỏng hoàn toàn -> mặc định")
	_write('[progress]\nhigh_score_normal="abc"\nhigh_score_hard=-50\nhigh_score_easy=[1,2]\n[graphics]\nquality=99\nreduced_fx={"a":1}\n[game]\nmap="khong_co"\nmode=5\ndifficulty=[]\n[settings]\n')
	G.load_save()
	_check(G.best_score("endless", "normal") == 0 and G.best_score("endless", "hard") == 0 and G.best_score("endless", "easy") == 0, "điểm sai kiểu / âm -> 0")
	_check(G.quality == G.QUALITY.size() - 1, "quality ngoài khoảng -> kẹp lại")
	_check(not G.reduced_fx and G.game_mode == "endless" and G.difficulty == "normal", "khoá sai kiểu -> mặc định")
	var keys: Array = G.DEFAULT_SETTINGS.keys()
	var s: String = "[settings]\n"
	for k in keys:
		s += '%s="rac"\n' % k
	_write(s)
	G.load_save()
	var all_def := true
	for k in keys:
		if G.settings[k] != G.DEFAULT_SETTINGS[k]:
			all_def = false
	_check(all_def, "setting sai kiểu -> giá trị mặc định")
	_write("[progress]\nhigh_score_endless_normal=1234\n")
	G.load_save()
	_check(G.best_score("endless", "normal") == 1234, "file thiếu khoá vẫn đọc được phần còn lại")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.save_path))
	G.load_save()

	# --- Bảng FPS
	var ov = load("res://scripts/perf_overlay.gd").new()
	root.add_child(ov)
	await process_frame
	_check(not ov.visible, "bảng FPS mặc định tắt")
	ov.toggle()
	await create_timer(0.7).timeout
	_check(ov.visible and ov.label.text.begins_with("FPS"), "F3 bật bảng FPS, có nội dung")
	ov.queue_free()

	# --- Vào / thoát ván lặp lại
	var base: int = _nodes()
	for i in 4:
		var m = load("res://scenes/main.tscn").instantiate()
		m.autostart_waves = false
		root.add_child(m)
		await _frames(5)
		m.queue_free()
		await _frames(5)
	_check(_nodes() <= base + 2, "vào/thoát ván 4 lần: không thừa node (%d -> %d)" % [base, _nodes()])

	# --- Vô Tận chạy lâu, liên tục hạ bot: node không tăng dần
	G.difficulty = "hard"
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(20)
	var pl = main.player
	pl.use_input = false
	pl.hurtbox.max_health = 1e9
	pl.hurtbox.health = 1e9
	main._start_mode()
	var samples: Array = []
	var frames: int = 0
	while frames < 60 * 40:
		await physics_frame
		frames += 1
		if frames % 600 == 0:
			samples.append(_static_nodes(main))
		for b in get_nodes_in_group("bots"):
			if not b.dead and frames % 20 == 0:
				b.hurtbox.take_hit({"damage": 9999.0, "kind": "x", "source": null, "direction": Vector3.ZERO})
				break
	_check(frames >= 60 * 40 and samples.size() >= 3, "Vô Tận chạy được %d khung" % frames)
	var growth: int = int(samples[samples.size() - 1]) - int(samples[0]) if samples.size() > 1 else 999
	_check(growth <= 30, "node (không tính bot/vật rơi) không tăng dần khi chạy lâu (%s)" % str(samples))
	main.queue_free()
	await _frames(10)
	_check(_nodes() <= base + 2, "thoát hẳn: node về mức ban đầu")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.save_path))
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(failures)
