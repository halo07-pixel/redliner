extends SceneTree
## Test headless M14: đường cong độ khó, mức độ khó, 2 loại bot mới, navmesh (tìm đường, hết kẹt),
## giới hạn bot áp sát, phản ứng khi người chơi Destabilized, lùi sau khi bị parry, pháo thủ.
##   timeout 300 godot --headless --path . -s tools/tests/test_smart_bots.gd

var failures: int = 0
var world: Node3D
var player
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


func _box(size: Vector3, pos: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = Global.L_WORLD
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	b.position = pos
	world.add_child(b)
	return b


func _clear_world() -> void:
	for n in get_nodes_in_group("bots"):
		n.queue_free()
	if player != null:
		player.queue_free()
		player = null
	if world != null:
		world.queue_free()
		await process_frame
	world = Node3D.new()
	root.add_child(world)


func _player(pos: Vector3) -> void:
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = pos
	player.hurtbox.health = 1.0e6
	player.hurtbox.max_health = 1.0e6
	await _frames(3)


func _bot(type_name: String, pos: Vector3, wave: int = 1):
	var b = load("res://scripts/bot.gd").new()
	b.setup(type_name, wave)
	b.position = pos
	world.add_child(b)
	return b


## Bake navmesh cho `world` (giống Arena._build_nav) và đợi navmesh đồng bộ.
func _bake() -> void:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 40.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Global.L_WORLD
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, world)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	var reg := NavigationRegion3D.new()
	reg.navigation_mesh = nm
	world.add_child(reg)
	await _frames(15)


func _min_dist_run(b, frames: int, goal_dist: float) -> float:
	var best: float = 1e9
	for i in frames:
		await _frames(1)
		if not is_instance_valid(b):
			break
		best = minf(best, b.global_position.distance_to(player.global_position))
		if best <= goal_dist:
			break
	return best


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://test_smart.cfg"
	G.load_save()
	var D: Dictionary = Global.DIFFICULTY

	print("[đường cong độ khó]")
	var prev: Dictionary = G.bot_stats("swordsman", 1, "normal")
	var mono: bool = true
	for w in range(2, 30):
		var cur: Dictionary = G.bot_stats("swordsman", w, "normal")
		if cur["health"] < prev["health"] or cur["speed"] < prev["speed"] or cur["reaction"] > prev["reaction"] or cur["parry"] < prev["parry"] or cur["dodge"] < prev["dodge"]:
			mono = false
		prev = cur
	_check(mono, "máu/tốc độ/parry/né không giảm, phản ứng không chậm đi theo wave")
	var base: Dictionary = Global.BOTS["swordsman"]
	var far: Dictionary = G.bot_stats("swordsman", 500, "normal")
	_check(far["health"] <= base["health"] * D["health_max_mult"] + 0.01, "máu có trần (%.0f)" % far["health"])
	_check(far["speed"] <= base["speed"] * D["speed_max_mult"] + 0.01, "tốc độ có trần (%.1f)" % far["speed"])
	_check(far["reaction"] >= base["reaction"] * D["reaction_min_mult"] - 0.001, "phản ứng có sàn (%.2f)" % far["reaction"])
	_check(far["parry"] <= D["parry_max"] + 0.001 and far["dodge"] <= D["dodge_max"] + 0.001, "xác suất parry/né có trần")
	var hard_far: Dictionary = G.bot_stats("elite", 500, "hard")
	_check(hard_far["parry"] <= D["chance_hard_cap"] + 0.001 and hard_far["dodge"] <= D["chance_hard_cap"] + 0.001, "mức Khó vẫn không vượt trần xác suất %.2f" % D["chance_hard_cap"])
	var e: Dictionary = G.bot_stats("swordsman", 5, "easy")
	var n: Dictionary = G.bot_stats("swordsman", 5, "normal")
	var h: Dictionary = G.bot_stats("swordsman", 5, "hard")
	_check(e["health"] < n["health"] and n["health"] < h["health"], "máu: Dễ < Thường < Khó (%.0f < %.0f < %.0f)" % [e["health"], n["health"], h["health"]])
	_check(e["reaction"] > n["reaction"] and n["reaction"] > h["reaction"], "phản ứng: Dễ chậm hơn Thường chậm hơn Khó")
	_check(e["parry"] < n["parry"] and n["parry"] < h["parry"], "parry: Dễ < Thường < Khó")
	_check(is_equal_approx(n["health"], Global.BOTS["swordsman"]["health"] * (1.0 + D["health_per_wave"] * 4.0)), "mức Thường = chỉ số gốc x đường cong (giữ nguyên bản cũ)")
	await _clear_world()
	var b0 = _bot("swordsman", Vector3.ZERO, 4)
	_check(is_equal_approx(b0.max_health, G.bot_stats("swordsman", 4)["health"]) and is_equal_approx(b0.reaction, G.bot_stats("swordsman", 4)["reaction"]), "Bot.setup dùng Global.bot_stats")
	b0.queue_free()

	print("[loại bot mới]")
	var R: Dictionary = Global.BOTS["rusher"]
	var S: Dictionary = Global.BOTS["swordsman"]
	_check(R["speed"] > S["speed"] * 1.3 and R["health"] < S["health"], "lao nhanh: nhanh hơn, mỏng hơn lính kiếm")
	_check(R["windup"] < S["windup"] and bool(R["flank"]), "lao nhanh: báo đòn ngắn, biết bọc sườn")
	var B: Dictionary = Global.BOTS["bomber"]
	_check(B["keep_range"] >= 14.0 and bool(B["bombs"]) and not bool(B["melee"]), "pháo thủ: đứng xa, ném đạn nổ, không cận chiến")
	for t in ["rusher", "bomber"]:
		_check(Global.RIG.has(t), "%s có trong Global.RIG" % t)
	var Gltf = load("res://scripts/mannequin_gltf.gd")
	_check(Gltf.has_asset("rusher") and Gltf.has_asset("bomber"), "2 loại mới dùng người que + vũ khí thật")
	var wm = load("res://scripts/wave_manager.gd").new()
	_check(wm.composition(1) == ["swordsman", "swordsman", "swordsman"], "wave 1 vẫn toàn lính kiếm")
	_check(wm.composition(2).has("rusher") and not wm.composition(2).has("bomber"), "wave 2: có lao nhanh, chưa có pháo thủ")
	_check(wm.composition(4).has("bomber") and wm.composition(4).has("elite"), "wave 4: có pháo thủ")
	_check(wm.composition(30).size() == 10, "vẫn chặn trần 10 bot/wave")
	wm.free()
	await _clear_world()
	for t in ["rusher", "bomber", "swordsman", "gunner", "elite"]:
		var bb = _bot(t, Vector3(0, 0.1, 0))
		await _frames(2)
		_check(is_instance_valid(bb) and bb.mannequin != null, "bot %s dựng được" % t)
		bb.queue_free()

	print("[navmesh trên 3 map]")
	var Maps = load("res://scripts/maps.gd")
	for id in Maps.IDS:
		await _clear_world()
		var arena: Node3D = load("res://scripts/arena.gd").new()
		arena.map_id = id
		world.add_child(arena)
		await _frames(15)
		var bad: int = 0
		for sp in arena.bot_spawns:
			var path: PackedVector3Array = arena.nav_path(sp, arena.spawn_point)
			if path.size() < 2 or path[path.size() - 1].distance_to(arena.spawn_point) > 1.5:
				bad += 1
		_check(bad == 0, "%s: mọi điểm sinh bot đều có đường tới người chơi" % id)
		await _player(arena.spawn_point)
		var bot = _bot("rusher", arena.bot_spawns[0])
		bot.melee.windup_override = 99.0 # không chém, chỉ đo đường đi
		var best: float = await _min_dist_run(bot, 900, 3.0)
		_check(best <= 3.5, "%s: bot đi từ điểm sinh tới sát người chơi (gần nhất %.1f m)" % [id, best])

	print("[hết kẹt khi có vật cản]")
	await _clear_world()
	_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))
	# Chữ U mở về phía -Z, bot nằm trong lòng chữ U, người chơi ở ngoài đáy chữ U
	_box(Vector3(14, 6, 1), Vector3(0, 3, 6))      # đáy
	_box(Vector3(1, 6, 14), Vector3(-7, 3, 0))     # cánh trái
	_box(Vector3(1, 6, 14), Vector3(7, 3, 0))      # cánh phải
	await _bake()
	await _player(Vector3(0, 0.1, 16))
	var trapped = _bot("rusher", Vector3(0, 0.1, 0))
	trapped.melee.windup_override = 99.0
	var best_u: float = await _min_dist_run(trapped, 900, 3.0)
	_check(best_u <= 3.5, "bot trong chữ U đi vòng ra tới người chơi (gần nhất %.1f m)" % best_u)
	# Bệ cao không có dốc: bot không leo được, đứng yên dưới chân bệ
	await _clear_world()
	_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))
	_box(Vector3(10, 5, 10), Vector3(0, 2.5, 0))
	await _bake()
	await _player(Vector3(0, 5.1, 0))
	var low = _bot("rusher", Vector3(0, 0.1, 20))
	low.melee.windup_override = 99.0
	var best_p: float = await _min_dist_run(low, 500, 1.0)
	_check(low.global_position.y < 0.6, "bệ cao 5 m không có dốc: bot (nhảy tối đa 3 m) không leo lên (y=%.2f)" % low.global_position.y)
	_check(best_p < 12.0, "nhưng vẫn tiến lại gần chân bệ (cách %.1f m)" % best_p)

	print("[giới hạn bot áp sát]")
	await _clear_world()
	_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))
	await _player(Vector3(0, 0.1, 0))
	var pack: Array = []
	for i in 6:
		var ang: float = TAU * float(i) / 6.0
		var bb = _bot("swordsman", Vector3(cos(ang) * 9.0, 0.1, sin(ang) * 9.0))
		bb.melee.windup_override = 0.5
		pack.append(bb)
	await _frames(240)
	var close: int = 0
	for bb in pack:
		if bb.global_position.distance_to(player.global_position) < 3.5:
			close += 1
	_check(close >= 1 and close <= int(D["max_melee_attackers"]), "6 bot vây quanh: chỉ %d (<= %d) áp sát cùng lúc" % [close, D["max_melee_attackers"]])
	var circling: int = 0
	for bb in pack:
		var dd: float = bb.global_position.distance_to(player.global_position)
		if dd > 3.5 and dd < 8.0:
			circling += 1
	_check(circling >= 2, "số còn lại đứng vòng ngoài (%d bot)" % circling)
	for bb in pack:
		bb.queue_free()
	await _frames(2)
	var solo = _bot("swordsman", Vector3(9, 0.1, 0))
	solo.melee.windup_override = 99.0
	var best_s: float = await _min_dist_run(solo, 300, 2.5)
	_check(best_s <= 2.6, "bot đơn độc vẫn áp sát bình thường (%.1f m)" % best_s)
	solo.queue_free()

	print("[người chơi mất thế]")
	await _clear_world()
	_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))
	await _player(Vector3(0, 0.1, 0))
	var winds: Array = []
	var b1 = _bot("swordsman", Vector3(0, 0.1, -1.5))
	b1.melee.swing_started.connect(func(w, _a, _r): winds.append(w))
	await _frames(150)
	_check(not b1._punish and winds.size() >= 1, "bình thường: bot tấn công, báo đòn %.2f s" % (winds[0] if winds.size() > 0 else -1.0))
	var w_normal: float = winds[0] if winds.size() > 0 else 0.0
	b1.queue_free()
	await _frames(2)
	player.instability.add(999.0)
	await _frames(2)
	_check(player.instability.destabilized, "người chơi vào trạng thái Destabilized")
	var winds2: Array = []
	var b2 = _bot("swordsman", Vector3(0, 0.1, -1.5))
	b2.melee.swing_started.connect(func(w, _a, _r): winds2.append(w))
	await _frames(60)
	_check(b2._punish, "bot nhận ra người chơi đang mất thế")
	_check(winds2.size() >= 1 and winds2[0] <= w_normal * 0.7, "bot báo đòn nhanh hơn (%.2f < %.2f)" % [winds2[0] if winds2.size() > 0 else -1.0, w_normal])
	b2.queue_free()
	var sh = _bot("gunner", Vector3(0, 0.1, -12))
	sh._shoot_cd = 5.0
	await _frames(2)
	_check(sh._shoot_cd <= D["punish_shoot_delay"] + 0.1, "xạ thủ bắn ngay khi người chơi mất thế (cd %.2f)" % sh._shoot_cd)
	sh.queue_free()

	print("[lùi sau khi bị parry]")
	await _clear_world()
	_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))
	await _player(Vector3(0, 0.1, 0))
	var rb = _bot("swordsman", Vector3(0, 0.1, -4.0))
	rb.melee.windup_override = 99.0
	await _frames(20)
	rb.melee.got_parried.emit()
	_check(rb._retreat_t > 0.0, "bị parry: bật lùi một nhịp")
	await _frames(16)   # có phanh/gia tốc (M23): cần ~0.25 s để đảo chiều
	var to_p: Vector3 = (player.global_position - rb.global_position)
	to_p.y = 0.0
	_check(Vector3(rb.velocity.x, 0, rb.velocity.z).dot(to_p.normalized()) < 0.0, "bot đang lùi ra xa người chơi")
	await _frames(60)
	_check(rb._retreat_t <= 0.0, "hết nhịp lùi thì quay lại tiến công")
	rb.queue_free()

	print("[pháo thủ]")
	await _clear_world()
	_box(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	await _player(Vector3(0, 0.1, 0))
	var ally = _bot("swordsman", Vector3(1.5, 0.1, 0))
	ally.melee.windup_override = 99.0
	var bomber = _bot("bomber", Vector3(0, 0.1, -16))
	var booms: Array = []
	bomber.exploded.connect(func(p, r): booms.append(p))
	var dmg0: float = player.hurtbox.health
	await _frames(600)
	_check(booms.size() >= 1, "pháo thủ ném đạn nổ (%d vụ)" % booms.size())
	var near: bool = false
	for p in booms:
		if (p as Vector3).distance_to(player.global_position) < 6.0:
			near = true
	_check(near, "đạn rơi gần người chơi (vòng cung có ngắm)")
	_check(player.hurtbox.health < dmg0, "người chơi bị thương bởi đạn nổ (%.0f)" % (dmg0 - player.hurtbox.health))
	_check(ally.hurtbox.health == ally.max_health, "đạn nổ không hại bot đồng đội")

	print("[mức độ khó: chọn + lưu]")
	var seen: Array = []
	G.difficulty_changed.connect(func(l): seen.append(l))
	_check(G.difficulty == "normal", "mặc định mức Thường")
	_check(G.submit_score(500) and G.high_score == 500, "Thường: kỷ lục 500")
	G.cycle_difficulty()
	_check(G.difficulty == "hard" and G.high_score == 0 and seen == ["hard"], "xoay vòng: Thường -> Khó, kỷ lục riêng = 0")
	_check(G.submit_score(300) and G.high_score == 300, "Khó: kỷ lục 300")
	G.cycle_difficulty()
	_check(G.difficulty == "easy" and G.high_score == 0, "Khó -> Dễ")
	G.cycle_difficulty()
	_check(G.difficulty == "normal" and G.high_score == 500, "Dễ -> Thường: kỷ lục 500 còn nguyên")
	G.set_difficulty("khong_co")
	_check(G.difficulty == "normal", "mức lạ bị bỏ qua")
	G.set_difficulty("hard")
	G.high_score = 0
	G.difficulty = "normal"
	G.load_save()
	_check(G.difficulty == "hard" and G.high_score == 300, "mức + kỷ lục từng mức được lưu và nạp lại")
	G.set_difficulty("normal")
	_check(G.high_score == 500, "kỷ lục mức Thường vẫn 500 sau khi nạp lại")
	G.set_difficulty("hard")
	await _clear_world()
	_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))
	var scored: Array = []
	var hb = _bot("swordsman", Vector3(0, 0.1, -30))
	hb.died.connect(func(_b, info): scored.append(info["score"]))
	await _frames(3)
	hb.hurtbox.take_hit({"damage": 9999.0, "kind": "melee", "source": null, "direction": Vector3.FORWARD})
	await _frames(2)
	_check(scored == [130], "Khó: điểm thưởng x1.3 (100 -> %s)" % str(scored))
	G.set_difficulty("normal")
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await _frames(2)
	_check(menu.difficulty_button.text.contains("Thường"), "menu: nút độ khó hiện mức hiện tại")
	menu.difficulty_button.pressed.emit()
	_check(G.difficulty == "hard" and menu.difficulty_button.text.contains("Khó") and menu.best_label.text.contains("300"), "bấm nút: đổi mức, chữ và điểm cao cập nhật")
	menu.queue_free()
	G.set_difficulty("normal")
	G.high_score = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_smart.cfg"))
	print("----", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
