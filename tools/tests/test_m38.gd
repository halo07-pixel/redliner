extends SceneTree
## M38: kho thẻ riêng của shotgun / bắn tỉa / pháo (12 thẻ đổi cách chơi), kiểm bằng số đo thật.
##   timeout 290 godot --headless --path . -s tools/tests/test_m38.gd

var failures: int = 0
var G
var arena: Node3D
var pl: Node3D
var cb


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


func _dummy(pos: Vector3) -> Node:
	var d: Node = load("res://scripts/enemy_dummy.gd").new()
	d.position = pos
	d.rotation.y = PI
	arena.add_child(d)
	return d


func _arm(d: Node, hp: float = 100000.0) -> void:
	d.hurtbox.setup(G.TEAM_ENEMY, hp, d.parry)


func _bot(pos: Vector3, hp: float = 1.0) -> Node:
	var b = load("res://scripts/bot.gd").new()
	b.setup("swordsman", 1)
	b.position = pos
	arena.add_child(b)
	b.hurtbox.health = hp
	return b


func _world(y: float = 0.2) -> void:
	arena = load("res://scripts/arena.gd").new()
	arena.map_id = "yard"
	arena.bake_nav = false
	root.add_child(arena)
	pl = load("res://scenes/player.tscn").instantiate()
	pl.use_input = false
	root.add_child(pl)
	pl.global_position = Vector3(0.0, y, 20.0)
	await _frames(15)
	cb = pl.combat
	cb.locked = false
	cb.weapon_mods = {}
	cb.flaws.enabled = false


func _clear() -> void:
	pl.queue_free()
	arena.queue_free()
	await _frames(3)


func _total(ds: Array) -> Array:
	return ds.map(func(d): return 100000.0 - d.hurtbox.health)


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://test_m38.cfg"
	G.load_save()
	var Up = load("res://scripts/upgrades.gd")
	var Lvl = load("res://scripts/level_up_ui.gd")

	print("[dữ liệu thẻ]")
	var ids: Array = []
	for pool in ["gun:shotgun", "gun:sniper", "gun:launcher"]:
		_check(G.UPGRADES[pool].size() == 4, "%s có 4 thẻ" % pool)
		for id in G.UPGRADES[pool]:
			ids.append(id)
			var c: Dictionary = G.UPGRADES[pool][id]
			_check(String(c["stat"]).begins_with(pool.substr(4) + "_") and c.has("effect") and c["cat"] == "gun", "thẻ %s: stat có tiền tố súng, có chữ hiệu ứng" % id)
	_check(ids.size() == 12 and ids.filter(func(i): return ids.count(i) == 1).size() == 12, "12 id thẻ riêng, không trùng")
	_check(Lvl.effect_text(G.UPGRADES["gun:launcher"]["launcher_cluster"], 1) == "3 tên lửa", "thẻ cờ hiện chữ hiệu ứng riêng")
	_check(Lvl.effect_text(G.UPGRADES["gun:pistol"]["pistol_heavy"], 1) == "+20%", "thẻ cộng % vẫn hiện số")
	var rp = load("res://scripts/run_progress.gd").new()
	rp.set_weapon_pool("sniper")
	var av: Array = Up.available(rp.pools, {}).map(func(c): return c["id"])
	_check("sniper_mark" in av and "shotgun_airkick" not in av and "launcher_chain" not in av and "pistol_heavy" not in av, "cầm bắn tỉa: chỉ kho chung + kho bắn tỉa")
	rp.set_weapon_pool("launcher")
	av = Up.available(rp.pools, {}).map(func(c): return c["id"])
	_check("launcher_sticky" in av and "sniper_mark" not in av, "cầm pháo: kho pháo")
	_check(is_equal_approx(rp.stat("shotgun_airkick"), 0.0), "chưa lấy thẻ: stat 0")
	rp.taken = {"shotgun_airkick": 2, "sniper_slide": 2}
	_check(is_equal_approx(rp.stat("shotgun_airkick"), 0.5) and is_equal_approx(rp.stat("sniper_slide"), 0.3), "stat cộng theo bậc: 0.5 / 0.3")

	print("[Shotgun: Cú đá đôi]")
	await _world(5.2)   # bay lơ lửng giữa không trung
	cb.switch_to("shotgun")
	cb.refill()
	var d1 := _dummy(Vector3(0.0, 5.0, 17.0))
	await _frames(4)
	_arm(d1)
	for i in 2:
		pl.velocity = Vector3.ZERO
		await _frames(1)
	_check(cb._airborne(), "đang trên không")
	cb._shot_cd = 0.0
	seed(4242)
	cb._shoot()
	await _frames(1)
	var base: float = 100000.0 - d1.hurtbox.health
	_check(base > 10.0, "không thẻ: bắn bia 3 m gây %.0f" % base)
	d1.hurtbox.health = 100000.0
	cb.weapon_mods = {"shotgun_airkick": 0.5}
	pl.velocity = Vector3.ZERO
	cb.refill()
	cb._shot_cd = 0.0
	seed(4242)
	cb._shoot()
	await _frames(1)
	var boosted: float = 100000.0 - d1.hurtbox.health
	_check(absf(boosted / base - 1.5) < 0.05, "Cú đá đôi bậc 2 khi bay: x1.5 (%.2f)" % (boosted / base))
	# Nạp bằng cú nhảy
	cb.weapon_mods = {}
	cb._ammo["shotgun"] = 0
	pl.global_position = Vector3(0.0, 60.0, 20.0)
	for i in 130:
		pl.velocity = Vector3.ZERO
		await _frames(1)
	_check(int(cb._ammo["shotgun"]) == 0, "không thẻ: bay 2 s không tự nạp")
	cb.weapon_mods = {"shotgun_airreload": 1.0}
	for i in 130:
		pl.velocity = Vector3.ZERO
		await _frames(1)
	_check(int(cb._ammo["shotgun"]) == 1, "Nạp bằng cú nhảy: bay ~2 s được +1 viên (%d)" % int(cb._ammo["shotgun"]))
	for i in 260:
		pl.velocity = Vector3.ZERO
		await _frames(1)
	_check(int(cb._ammo["shotgun"]) == 2, "bay tiếp 4 s: đầy băng 2 viên, không vượt (%d)" % int(cb._ammo["shotgun"]))
	await _clear()

	print("[Shotgun: Sóng xung kích + Đạn dội]")
	await _world()
	cb.switch_to("shotgun")
	cb.refill()
	var bf := _bot(Vector3(0.0, 0.0, 17.0), 100000.0)
	var bb := _bot(Vector3(0.0, 0.0, 23.0), 100000.0)
	bf.set_physics_process(false)
	bb.set_physics_process(false)
	await _frames(4)
	cb._shot_cd = 0.0
	cb._shoot()
	_check(bf._kb.length() < 0.1 and bf._lift == 0.0, "không thẻ: bot trước mặt không bị hất")
	cb.weapon_mods = {"shotgun_shockwave": 1.0}
	cb.refill()
	cb._shot_cd = 0.0
	cb._shoot()
	_check(bf._kb.length() > 8.0 and bf._lift > 0.0, "Sóng xung kích: bot trước mặt bị hất (%.1f m/s)" % bf._kb.length())
	_check(bb._kb.length() < 0.1, "bot ở sau lưng không bị hất")
	bf.queue_free()
	bb.queue_free()
	# Đạn dội: tường nghiêng 45 độ hắt đạn sang phải tới bia
	var wall := StaticBody3D.new()
	wall.collision_layer = G.L_WORLD
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(8.0, 6.0, 0.5)
	cs.shape = bx
	wall.add_child(cs)
	wall.position = Vector3(0.0, 3.0, 10.0)
	wall.rotation.y = deg_to_rad(45.0)
	arena.add_child(wall)
	var side := _dummy(Vector3(6.0, 0.0, 10.0))
	await _frames(4)
	_arm(side)
	cb.weapon_mods = {}
	cb.refill()
	cb._shot_cd = 0.0
	cb._shoot()
	await _frames(1)
	_check(side.hurtbox.health == 100000.0, "không thẻ: đạn trúng tường rồi mất, bia bên cạnh không sao")
	cb.weapon_mods = {"shotgun_ricochet": 1.0}
	for k in 6:   # đạn tản ngẫu nhiên: thử vài phát, chỉ cần ít nhất một mảnh nảy trúng
		cb.refill()
		cb._shot_cd = 0.0
		cb._shoot()
		await _frames(1)
		if side.hurtbox.health < 100000.0:
			break
	_check(side.hurtbox.health < 100000.0, "Đạn dội: mảnh nảy khỏi tường trúng bia bên cạnh (-%.0f)" % (100000.0 - side.hurtbox.health))
	await _clear()

	print("[Bắn tỉa: Nạp thêm / Săn liên hoàn / Tia đánh dấu / Nạp trượt]")
	await _world()
	cb.switch_to("sniper")
	cb.flaws.enabled = true
	var line: Array = [_dummy(Vector3(0.0, 0.0, 10.0)), _dummy(Vector3(0.0, 0.0, 4.0)), _dummy(Vector3(0.0, 0.0, -2.0))]
	await _frames(4)
	for d in line:
		_arm(d)
	var shots: Array = []
	cb.shot_fired.connect(func(_a, _b): shots.append(1))
	cb.refill()
	cb._shot_cd = 0.0
	cb.want_shoot = true
	await _frames(54)   # ~0.9 s > 0.8 s
	cb.want_shoot = false
	await _frames(2)
	var n: Array = _total(line)
	_check(shots.size() == 1 and n[0] > 10.0 and n[1] > 10.0 and n[2] == 0.0, "không thẻ: nạp 0.8 s nổ 1 phát, xuyên 2 mục tiêu, bia thứ 3 an toàn")
	var normal_dmg: float = n[0]
	for d in line:
		d.hurtbox.health = 100000.0
	cb.weapon_mods = {"sniper_overcharge": 1.0}
	cb.refill()
	cb._shot_cd = 0.0
	shots.clear()
	cb.want_shoot = true
	await _frames(54)
	_check(shots.is_empty(), "Nạp thêm: giữ 0.9 s vẫn chưa nổ (đang nạp tiếp)")
	cb.want_shoot = false
	await _frames(2)
	n = _total(line)
	_check(shots.size() == 1 and absf(n[0] - normal_dmg) < 1.0 and n[2] == 0.0, "thả sau khi đủ nạp: nổ phát thường (%.0f)" % n[0])
	for d in line:
		d.hurtbox.health = 100000.0
	cb.refill()
	cb._shot_cd = 0.0
	shots.clear()
	cb.want_shoot = true
	await _frames(95)   # ~1.58 s > 1.4 s
	cb.want_shoot = false
	await _frames(2)
	n = _total(line)
	_check(shots.size() == 1 and absf(n[0] / normal_dmg - 2.0) < 0.05, "giữ đủ 1.4 s: siêu đạn x2 sát thương (%.2f)" % (n[0] / normal_dmg))
	_check(n[2] > 1.0, "siêu đạn xuyên cả bia thứ 3")
	# Tia đánh dấu
	cb.weapon_mods = {"sniper_mark": 1.0}
	for d in line:
		d.hurtbox.health = 100000.0
	cb.refill()
	cb._shot_cd = 0.0
	cb.want_shoot = true
	await _frames(15)
	cb.want_shoot = false
	await _frames(2)
	_check(is_equal_approx(line[0].hurtbox.damage_taken_mult, 1.4), "Tia đánh dấu: bia bị tia quét có +40% sát thương nhận")
	_check(line[1].hurtbox.damage_taken_mult == 1.0, "bia khuất sau bia đầu không bị đánh dấu")
	var before: float = line[0].hurtbox.health
	line[0].hurtbox.take_hit({"damage": 10.0, "kind": "melee", "source": null, "direction": Vector3.FORWARD})
	_check(is_equal_approx(before - line[0].hurtbox.health, 14.0), "nguồn sát thương bất kỳ nhận x1.4 (14)")
	cb._tick_perks(5.1)
	_check(line[0].hurtbox.damage_taken_mult == 1.0, "hết 5 s: đánh dấu mất")
	# Săn liên hoàn
	cb.weapon_mods = {"sniper_chain": 1.0}
	line[0].hurtbox.setup(G.TEAM_ENEMY, 20.0, line[0].parry)
	cb.refill()
	cb._shot_cd = 0.0
	shots.clear()
	cb.want_shoot = true
	await _frames(54)
	cb.want_shoot = false
	await _frames(2)
	_check(line[0].hurtbox.dead and cb._chain_t > 2.5, "hạ gục bằng bắn tỉa: mở cửa sổ săn liên hoàn (%.1f s)" % cb._chain_t)
	_check(cb._charge_need() == 0.0, "trong cửa sổ: không cần nạp ngắm")
	cb._shot_cd = 0.0
	shots.clear()
	cb.want_shoot = true
	await _frames(2)
	cb.want_shoot = false
	_check(shots.size() == 1, "bấm chuột 2 khung hình: nổ ngay")
	cb._tick_perks(3.1)
	_check(cb._charge_need() > 0.7, "hết 3 s: lại phải nạp ngắm")
	# Nạp trượt
	cb.weapon_mods = {}
	_check(is_equal_approx(cb._charge_need(), 0.8), "đứng: nạp 0.8 s")
	pl.state = pl.State.SLIDE
	_check(is_equal_approx(cb._charge_need(), 0.8), "trượt nhưng không có thẻ: vẫn 0.8 s")
	cb.refill()
	cb._shot_cd = 0.0
	cb.want_shoot = true
	cb._handle_shoot(0.016, false)
	_check(cb.move_mult == 0.5, "trượt không thẻ: vẫn chậm 50%")
	cb.want_shoot = false
	cb._handle_shoot(0.016, false)
	cb.weapon_mods = {"sniper_slide": 0.3}
	_check(is_equal_approx(cb._charge_need(), 0.56), "Nạp trượt bậc 2: nạp còn 0.56 s khi trượt")
	cb._shot_cd = 0.0
	cb.want_shoot = true
	cb._handle_shoot(0.016, false)
	_check(cb.move_mult == 1.0, "trượt có thẻ: không bị chậm lúc nạp")
	cb.want_shoot = false
	cb._handle_shoot(0.016, false)
	pl.state = pl.State.NORMAL
	_check(is_equal_approx(cb._charge_need(), 0.8), "không trượt: nạp 0.8 s như cũ")
	await _clear()

	print("[Pháo: Chùm ba / Nhảy nổ / Mìn dính]")
	await _world()
	cb.switch_to("launcher")
	var rk: Array = []
	var catch_rocket := func(n: Node):
		if n.get_script() != null and String(n.get_script().resource_path).ends_with("rocket.gd"):
			rk.append(n)
	root.child_entered_tree.connect(catch_rocket)
	cb.refill()
	cb._shot_cd = 0.0
	cb._shoot()
	await _frames(1)
	_check(rk.size() == 1 and rk[0].cfg.get("self_push_mult", 1.0) == 1.0 and not rk[0].cfg.has("sticky") and not rk[0].cfg.has("chain"), "không thẻ: 1 tên lửa thường")
	rk[0].queue_free()
	rk.clear()
	cb.weapon_mods = {"launcher_cluster": 1.0, "launcher_jump": 1.0, "launcher_sticky": 1.0, "launcher_chain": 1.0}
	cb.refill()
	cb._shot_cd = 0.0
	cb._shoot()
	await _frames(1)
	_check(rk.size() == 3, "Chùm ba: bắn 3 tên lửa (%d)" % rk.size())
	var c0: Dictionary = rk[0].cfg
	_check(is_equal_approx(float(c0["damage"]), 27.0) and is_equal_approx(float(c0["blast_radius"]), 3.15), "mỗi quả 45%% sát thương (27), 70%% bán kính (3.15)")
	_check(rk[0].velocity.normalized().distance_to(rk[1].velocity.normalized()) > 0.05, "3 hướng bay khác nhau")
	_check(is_equal_approx(float(c0["self_push_mult"]), 1.8) and is_equal_approx(float(c0["sticky"]), 1.0) and bool(c0["chain"]), "mang cờ Nhảy nổ 1.8 / Mìn dính 1 s / Nổ dây chuyền")
	_check(G.WEAPONS["launcher"]["blast_radius"] == 4.5 and G.WEAPONS["launcher"]["damage"] == 60.0, "dữ liệu súng gốc không bị sửa")
	for r in rk:
		r.queue_free()
	rk.clear()
	await _frames(2)
	# Nhảy nổ: đo xung đẩy người bắn
	var cfg0: Dictionary = G.WEAPONS["launcher"].duplicate()
	cfg0["self_damage_mult"] = 0.15
	pl.velocity = Vector3.ZERO
	load("res://scripts/rocket.gd").explode(pl.get_world_3d(), pl.global_position + Vector3(0.0, -0.5, 0.0), cfg0, pl)
	var v1: float = pl.velocity.length()
	var cfg1: Dictionary = cfg0.duplicate()
	cfg1["self_push_mult"] = 1.8
	pl.velocity = Vector3.ZERO
	load("res://scripts/rocket.gd").explode(pl.get_world_3d(), pl.global_position + Vector3(0.0, -0.5, 0.0), cfg1, pl)
	_check(v1 > 1.0 and absf(pl.velocity.length() / v1 - 1.8) < 0.01, "Nhảy nổ: xung hất bản thân x1.8 (%.1f -> %.1f)" % [v1, pl.velocity.length()])
	# Mìn dính
	var tgt := _dummy(Vector3(0.0, 0.0, 12.0))
	await _frames(4)
	_arm(tgt)
	cb.weapon_mods = {"launcher_sticky": 1.0}
	pl.global_position = Vector3(0.0, 0.2, 20.0)
	pl.velocity = Vector3.ZERO
	await _frames(3)
	cb.refill()
	cb._shot_cd = 0.0
	cb._shoot()
	await _frames(25)
	_check(rk.size() == 1 and is_instance_valid(rk[0]) and rk[0]._stuck == tgt and tgt.hurtbox.health == 100000.0, "Mìn dính: tên lửa dính vào bia, chưa nổ")
	await _frames(70)
	_check(tgt.hurtbox.health < 100000.0, "sau ~1 s: nổ, bia mất máu (-%.0f)" % (100000.0 - tgt.hurtbox.health))
	root.child_entered_tree.disconnect(catch_rocket)
	await _clear()

	print("[Pháo: Nổ dây chuyền]")
	await _world()
	var Rk = load("res://scripts/rocket.gd")
	var impact := Vector3(0.0, 0.2, 0.0)
	var bots: Array = [_bot(Vector3(3.5, 0.0, 0.0)), _bot(Vector3(5.5, 0.0, 0.0))]
	for b in bots:
		b.set_physics_process(false)
	await _frames(4)
	var cfgc: Dictionary = G.WEAPONS["launcher"].duplicate()
	cfgc["self_damage_mult"] = 0.15
	var out: Array = Rk.explode(pl.get_world_3d(), impact, cfgc, pl)
	_check(bots[0].hurtbox.dead and not bots[1].hurtbox.dead and out.is_empty(), "không thẻ: chỉ bot trong bán kính chết, bot xa 5.5 m sống")
	bots[0].hurtbox.revive()
	bots[0].hurtbox.health = 1.0
	cfgc["chain"] = true
	await _frames(2)
	out = Rk.explode(pl.get_world_3d(), impact, cfgc, pl)
	_check(bots[0].hurtbox.dead and bots[1].hurtbox.dead and out.size() >= 1, "Nổ dây chuyền: bot chết nổ tiếp, hạ cả bot ở xa (%d vụ nổ thêm)" % out.size())
	_check(is_equal_approx(float(out[0][1]), 2.25), "vụ nổ thêm bán kính 50%% (2.25)")
	var capped: Dictionary = cfgc.duplicate()
	capped["chain_depth"] = 3
	_check(Rk.explode(pl.get_world_3d(), impact, capped, pl).is_empty(), "đã đủ 3 lần liên tiếp: dừng, không nổ thêm")
	# Nổ dây chuyền không hại người bắn
	var hp0: float = pl.hurtbox.health
	var near := _bot(pl.global_position + Vector3(0.0, 0.0, 6.0))
	near.set_physics_process(false)
	await _frames(4)
	var cc: Dictionary = cfgc.duplicate()
	cc["chain_depth"] = 1
	cc["no_self"] = true
	cc["blast_radius"] = 8.0
	Rk.explode(pl.get_world_3d(), pl.global_position + Vector3(0.0, 0.0, 2.0), cc, pl)
	_check(is_equal_approx(pl.hurtbox.health, hp0), "vụ nổ dây chuyền không gây sát thương lên người bắn")
	await _clear()

	print("[Tích hợp main]")
	G.set_mode("endless")
	G.start_wave = 1
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(15)
	main._start_mode()
	await _frames(3)
	main.progress.taken = {"shotgun_airkick": 2, "sniper_mark": 1, "launcher_chain": 1, "pistol_heavy": 1}
	main._apply_upgrades()
	var wm: Dictionary = main.player.combat.weapon_mods
	_check(is_equal_approx(float(wm["shotgun_airkick"]), 0.5) and float(wm["sniper_mark"]) == 1.0 and float(wm["launcher_chain"]) == 1.0 and float(wm["sniper_chain"]) == 0.0, "main chép stat thẻ riêng vào weapon_mods")
	_check(is_equal_approx(float(wm["pistol_damage_mult"]), 1.2), "thẻ súng lục vẫn áp")
	main.queue_free()
	await _frames(10)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.save_path))

	print("---")
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
