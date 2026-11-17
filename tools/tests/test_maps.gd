extends SceneTree
## Test headless M11: 3 map dựng được, spawn hợp lệ (không nằm trong khối), chọn map + lưu, rơi khỏi map.
##   timeout 200 godot --headless --path . -s tools/tests/test_maps.gd

var failures: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _blocked(arena: Node3D, p: Vector3, radius: float, height: float) -> bool:
	var sh := CapsuleShape3D.new()
	sh.radius = radius
	sh.height = height
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0.0, height * 0.5 + 0.05, 0.0))
	q.collision_mask = Global.L_WORLD
	return not arena.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var G = root.get_node("Global")
	var Maps = load("res://scripts/maps.gd")
	G.save_path = "user://test_maps.cfg"
	G.load_save()
	_check(G.selected_map == "yard", "mặc định map = yard")

	for id in Maps.IDS:
		print("[", id, "]")
		var data: Dictionary = Maps.get_map(id)
		_check(Global.MAP_NAMES.has(id) and Global.MAP_NAMES[id] == data["name"], "tên map khớp Global.MAP_NAMES")
		_check(data["boxes"].size() >= 8, "có đủ khối địa hình (%d)" % data["boxes"].size())
		_check(data["bot_spawns"].size() >= 5, "có >= 5 điểm sinh bot")
		var arena: Node3D = load("res://scripts/arena.gd").new()
		arena.map_id = id
		var loaded: Array = []
		arena.map_loaded.connect(func(m): loaded.append(m))
		root.add_child(arena)
		await _frames(3)
		_check(loaded == [id], "Arena phát map_loaded(%s)" % id)
		_check(not _blocked(arena, arena.spawn_point, 0.4, 1.8), "điểm xuất phát người chơi không kẹt trong khối")
		var bad: int = 0
		var inside: int = 0
		var h: Vector2 = arena.half
		for p in arena.bot_spawns:
			if _blocked(arena, p, 0.4, 1.8):
				bad += 1
			if absf(p.x) > h.x or absf(p.z) > h.y:
				inside += 1
		_check(bad == 0, "mọi điểm sinh bot đều trống")
		_check(inside == 0, "mọi điểm sinh bot nằm trong sàn")
		_check(arena.dummies.size() == data["dummies"].size(), "có bia tập")
		for d in arena.dummies:
			_check(not _blocked(arena, d.position, 0.4, 1.8), "bia tập không kẹt trong khối")
		# người chơi đứng được trên sàn và thấy đủ khối
		var player = load("res://scenes/player.tscn").instantiate()
		player.use_input = false
		root.add_child(player)
		player.global_position = arena.spawn_point
		await _frames(30)
		_check(player.is_on_floor() and absf(player.global_position.y) < 0.3, "người chơi đáp xuống sàn tại điểm xuất phát")
		# Bot đứng vững trên sàn tại mọi điểm sinh
		var floor_ok: int = 0
		for p in arena.bot_spawns:
			var b = load("res://scripts/bot.gd").new()
			b.setup("swordsman", 1)
			b.position = p
			arena.add_child(b)
			await _frames(25)
			if absf(b.global_position.y) < 0.3:
				floor_ok += 1
			b.queue_free()
		_check(floor_ok == arena.bot_spawns.size(), "bot đứng được trên sàn ở mọi điểm sinh (%d/%d)" % [floor_ok, arena.bot_spawns.size()])
		player.queue_free()
		arena.queue_free()
		await process_frame

	print("[khác biệt giữa các map]")
	var sizes: Array = []
	for id in Maps.IDS:
		var d: Dictionary = Maps.get_map(id)
		sizes.append(str(d["half"]) + str(d["boxes"].size()))
	_check(sizes[0] != sizes[1] and sizes[1] != sizes[2] and sizes[0] != sizes[2], "3 map khác nhau về cỡ/số khối")
	_check(Maps.get_map("khong_co")["name"] == Maps.get_map("yard")["name"], "id lạ quay về yard")

	print("[chọn map + lưu]")
	var seen: Array = []
	G.map_changed.connect(func(m): seen.append(m))
	G.cycle_map()
	_check(G.selected_map == "alley" and seen == ["alley"], "cycle_map: yard -> alley, phát map_changed")
	G.set_map("tower")
	_check(G.selected_map == "tower", "set_map(tower)")
	G.set_map("bậy")
	_check(G.selected_map == "tower", "id sai bị bỏ qua")
	G.cycle_map()
	_check(G.selected_map == "yard", "cycle_map vòng về yard")
	G.set_map("alley")
	G.selected_map = "yard"
	G.load_save()
	_check(G.selected_map == "alley", "map được lưu và tải lại từ file")
	var arena2: Node3D = load("res://scripts/arena.gd").new()
	root.add_child(arena2)
	await _frames(2)
	_check(arena2.map_id == "alley", "Arena mặc định dùng map đã chọn")
	arena2.queue_free()

	print("[menu có nút chọn map]")
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await _frames(2)
	_check(menu.map_button != null and menu.map_button.text.contains("Hẻm tường"), "nút bản đồ hiện map đang chọn")
	menu.map_button.pressed.emit()
	_check(G.selected_map == "tower" and menu.map_button.text.contains("Tháp"), "bấm nút: đổi sang Tháp, chữ cập nhật")
	menu.queue_free()

	print("[rơi khỏi map]")
	G.selected_map = "yard"
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(5)
	main.player.use_input = false
	var hp: float = main.player.hurtbox.health
	main.player.global_position = Vector3(0.0, main.arena.void_y - 5.0, 0.0)
	await _frames(3)
	_check(main.player.global_position.distance_to(main.arena.spawn_point) < 1.5, "rơi khỏi map: về điểm xuất phát")
	_check(main.player.hurtbox.health < hp and main.player.hurtbox.health > 0.0, "mất máu nhưng chưa chết (%.0f)" % main.player.hurtbox.health)
	_check(main.waves != null and main.waves._spawns == main.arena.bot_spawns, "wave dùng điểm sinh của map")
	main.queue_free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_maps.cfg"))
	print("----", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
