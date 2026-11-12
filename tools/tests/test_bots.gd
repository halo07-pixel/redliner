extends SceneTree
## Test headless: bot AI, wave, điểm.
##   timeout 240 godot --headless --path . -s tools/tests/test_bots.gd

var failures: int = 0
var world: Node3D
var player
var bots: Array = []


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _make_floor() -> void:
	var b := StaticBody3D.new()
	b.collision_layer = Global.L_WORLD
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(200, 1, 200)
	c.shape = s
	b.add_child(c)
	b.position.y = -0.5
	world.add_child(b)


func _clear() -> void:
	for b in bots:
		if is_instance_valid(b):
			b.queue_free()
	bots.clear()
	for n in root.get_tree().get_nodes_in_group("bullets"):
		n.queue_free()
	if player != null:
		player.queue_free()
	await process_frame
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	await _frames(3)


func _bot(type_name: String, pos: Vector3, difficulty: int = 1):
	var b = load("res://scripts/bot.gd").new()
	b.setup(type_name, difficulty)
	b.position = pos
	world.add_child(b)
	bots.append(b)
	return b


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	world = Node3D.new()
	root.add_child(world)
	_make_floor()
	var C: Dictionary = Global.COMBAT

	# ---------------- ĐUỔI + CHÉM
	print("[lính kiếm]")
	await _clear()
	var s = _bot("swordsman", Vector3(0, 0, -15))
	s.dodge_chance = 0.0
	s.parry_chance = 0.0
	await _frames(100)
	var d: float = s.global_position.distance_to(player.global_position)
	_check(d < 3.0, "lính kiếm đuổi tới sát người chơi (cách %.1f m)" % d)
	var facing: float = (-s.global_transform.basis.z).dot((player.global_position - s.global_position).normalized())
	_check(facing > 0.9, "quay mặt về phía người chơi (%.2f)" % facing)
	await _frames(120)
	_check(player.hurtbox.health < 100.0, "vào tầm thì chém trúng người chơi (máu %.0f)" % player.hurtbox.health)

	# ---------------- BÁO ĐÒN: người chơi parry đòn kiếm của bot
	print("[parry bot]")
	await _clear()
	s = _bot("swordsman", Vector3(0, 0, -2.2))
	s.dodge_chance = 0.0
	s.parry_chance = 0.0
	var guard: int = 0
	while s.melee.phase != s.melee.Phase.WINDUP and guard < 200:
		await physics_frame
		guard += 1
	# bấm parry khi sắp hết báo đòn
	guard = 0
	while s.melee._t > 0.08 and guard < 100:
		await physics_frame
		guard += 1
	player.combat.want_parry = true
	await _frames(40)
	_check(player.hurtbox.health == 100.0, "parry đúng lúc đòn báo của bot: không mất máu")
	_check(s.melee.is_staggered() or s.melee.phase == s.melee.Phase.IDLE and s.melee._stagger_t > 0.0 or s.melee.is_staggered(), "bot bị choáng sau khi bị parry")

	# ---------------- XẠ THỦ
	print("[xạ thủ]")
	await _clear()
	var g = _bot("gunner", Vector3(0, 0, -5))
	await _frames(120)
	var dg: float = g.global_position.distance_to(player.global_position)
	_check(dg > 8.0, "xạ thủ lùi giữ khoảng cách (từ 5 m ra %.1f m)" % dg)
	var shots: Array = []
	g.sound.connect(func(n): if n == "shot": shots.append(1))
	g._shoot_cd = 0.0
	await _frames(120)
	_check(shots.size() >= 1, "xạ thủ bắn đạn (%d phát)" % shots.size())
	await _clear()
	g = _bot("gunner", Vector3(0, 0, -14))
	g.dodge_chance = 0.0
	g._shoot_cd = 0.0
	await _frames(150)
	_check(player.hurtbox.health < 100.0, "đạn của xạ thủ trúng người chơi (máu %.0f)" % player.hurtbox.health)

	# ---------------- BOT PARRY
	print("[bot parry / né]")
	await _clear()
	var e = _bot("elite", Vector3(0, 0, -2.0))
	e.parry_chance = 1.0
	e.dodge_chance = 0.0
	e.reaction = 0.0
	e._atk_cd = 99.0 # chỉ đứng đỡ, không chủ động đánh
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	await _frames(40)
	_check(e.hurtbox.health == e.max_health, "elite parry kịp đòn kiếm: không mất máu")
	_check(player.melee.is_staggered(), "người chơi bị choáng vì bị parry")
	await _clear()
	var sw = _bot("swordsman", Vector3(0, 0, -2.0))
	sw.parry_chance = 0.0
	sw.dodge_chance = 1.0
	sw.reaction = 0.0
	sw._atk_cd = 99.0
	var x0: float = sw.global_position.x
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	await _frames(40)
	_check(sw.hurtbox.health == sw.max_health, "bot né được đòn kiếm")
	_check(absf(sw.global_position.x - x0) > 1.0, "bot né sang ngang (%.1f m)" % absf(sw.global_position.x - x0))
	# Phản ứng chậm thì ăn đòn
	await _clear()
	sw = _bot("swordsman", Vector3(0, 0, -2.0))
	sw.parry_chance = 1.0
	sw.dodge_chance = 0.0
	sw.reaction = 0.5 # chậm hơn thời gian đòn tới
	sw._atk_cd = 99.0
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	await _frames(40)
	_check(sw.hurtbox.health < sw.max_health, "phản ứng chậm hơn đòn -> ăn đòn")

	# ---------------- CHẾT
	print("[bot chết]")
	await _clear()
	sw = _bot("swordsman", Vector3(0, 0, -30))
	var infos: Array = []
	sw.died.connect(func(_b, info): infos.append(info))
	sw.hurtbox.take_hit({"damage": 9999.0, "kind": "hitscan"})
	_check(infos.size() == 1 and infos[0]["type"] == "swordsman" and infos[0]["score"] == 100, "bot chết phát died kèm thông tin (%s)" % str(infos[0]) if infos.size() > 0 else "không phát died")
	await _frames(40)
	_check(not is_instance_valid(sw), "bot chết bị xoá khỏi cảnh")

	# ---------------- WAVE
	print("[wave]")
	await _clear()
	var wm = load("res://scripts/wave_manager.gd").new()
	wm.break_time = 0.3
	root.add_child(wm)
	var spawns: Array = [Vector3(-25, 0.1, -25), Vector3(25, 0.1, -25), Vector3(0, 0.1, -27)]
	wm.setup(world, spawns)
	_check(wm.composition(1) == ["swordsman", "swordsman", "swordsman"], "wave 1: 3 lính kiếm")
	_check(wm.composition(2).has("gunner") and not wm.composition(2).has("elite"), "wave 2: có xạ thủ, chưa có tinh nhuệ")
	_check(wm.composition(3).has("elite"), "wave 3: có tinh nhuệ")
	_check(wm.composition(20).size() == 10, "số bot mỗi wave bị chặn trần 10")
	var started: Array = []
	var cleared: Array = []
	wm.wave_started.connect(func(n, c): started.append([n, c]))
	wm.wave_cleared.connect(func(n): cleared.append(n))
	wm.start()
	await _frames(2)
	_check(started.size() == 1 and started[0] == [1, 3], "wave 1 bắt đầu với 3 bot")
	var alive: Array = root.get_tree().get_nodes_in_group("bots")
	_check(alive.size() == 3, "đã sinh 3 bot trong cảnh (%d)" % alive.size())
	for b in alive:
		b.hurtbox.take_hit({"damage": 9999.0, "kind": "hitscan"})
	await _frames(2)
	_check(cleared == [1], "hạ hết bot -> wave_cleared(1)")
	await _frames(40) # > break_time
	_check(started.size() == 2 and started[1] == [2, 4], "nghỉ rồi sang wave 2 với 4 bot (%s)" % str(started))
	wm.stop()
	for b in root.get_tree().get_nodes_in_group("bots"):
		b.queue_free()
	wm.queue_free()
	await _frames(2)

	# ---------------- ĐIỂM
	print("[điểm]")
	var sc = load("res://scripts/score_manager.gd").new()
	root.add_child(sc)
	var g1: int = sc.register_kill(100, {})
	_check(g1 == 100 and sc.score == 100 and sc.combo == 1, "hạ bot đầu: +100, combo 1")
	var g2: int = sc.register_kill(100, {})
	_check(g2 == 110 and sc.combo == 2, "combo 2: +110 (x1.1)")
	var g3: int = sc.register_kill(100, {"reflected": true})
	_check(g3 == 240, "phản đạn x2 cộng combo 3: +240 (%d)" % g3)
	var g4: int = sc.register_kill(100, {"staggered": true})
	_check(g4 == 195, "hạ bot đang choáng x1.5 combo 4: +195 (%d)" % g4)
	_check(sc.score == 100 + 110 + 240 + 195 and sc.best == sc.score, "tổng điểm và điểm cao nhất đúng (%d)" % sc.score)
	await _frames(260) # > 4 giây
	_check(sc.combo == 0, "hết cửa sổ thì combo về 0")
	sc.reset()
	_check(sc.score == 0 and sc.best > 0, "reset: điểm về 0, giữ điểm cao nhất")

	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
