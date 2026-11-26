extends SceneTree
## M39: lỗi kiếm "Phá thế đỡ" + kho thẻ kiếm (Mũi nhọn xuyên giáp, Nhịp phản đòn, Lưỡi kiếm lao, Vòng chém).
##   timeout 290 godot --headless --path . -s tools/tests/test_m39.gd

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


func _arm(d: Node) -> void:
	d.hurtbox.setup(G.TEAM_ENEMY, 100000.0, d.parry)


func _bot(pos: Vector3) -> Node:
	var b = load("res://scripts/bot.gd").new()
	b.setup("swordsman", 1)
	b.position = pos
	arena.add_child(b)
	b.hurtbox.health = 100000.0
	b.hurtbox.max_health = 100000.0
	b.set_physics_process(false)
	return b


func _world() -> void:
	arena = load("res://tools/tests/fixtures/flat_arena.gd").new()
	arena.bake_nav = false
	root.add_child(arena)
	pl = load("res://scenes/player.tscn").instantiate()
	pl.use_input = false
	root.add_child(pl)
	pl.global_position = Vector3(0.0, 0.2, 20.0)
	await _frames(15)
	cb = pl.combat
	cb.locked = false
	cb.weapon_mods = {}
	cb.flaws.enabled = false


func _clear() -> void:
	pl.queue_free()
	arena.queue_free()
	await _frames(3)


## Chém một nhát và chờ tới khi đòn kết thúc (đủ để quét và hồi).
func _swing_and_wait(frames: int = 40) -> void:
	cb.want_attack = true
	await _frames(1)
	cb.want_attack = false
	await _frames(frames)


func _hp(d: Node) -> float:
	return 100000.0 - d.hurtbox.health


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://test_m39.cfg"
	G.load_save()
	var Up = load("res://scripts/upgrades.gd")
	var Lvl = load("res://scripts/level_up_ui.gd")

	print("[dữ liệu]")
	var pool: Dictionary = G.UPGRADES["sword"]
	_check(pool.size() == 4 and pool.has("sword_pierce") and pool.has("sword_riposte") and pool.has("sword_lunge") and pool.has("sword_whirl"), "kho kiếm có 4 thẻ")
	for id in pool:
		_check(pool[id]["cat"] == "sword" and String(pool[id]["stat"]).begins_with("sword_") and pool[id].has("effect"), "thẻ %s: nhóm kiếm, stat có tiền tố, có chữ hiệu ứng" % id)
	_check(G.FLAWS["guard_rebound"]["name"] == "Phá thế đỡ" and is_equal_approx(float(G.FLAWS["guard_rebound"]["extra_stagger"]), 0.4), "lỗi kiếm: Phá thế đỡ, khựng thêm 0.4 s")
	var rp = load("res://scripts/run_progress.gd").new()
	_check("sword" in rp.pools, "lượt mới có sẵn kho kiếm")
	rp.set_weapon_pool("sniper")
	_check("sword" in rp.pools, "đổi súng không làm mất kho kiếm")
	var av: Array = Up.available(rp.pools, {}).map(func(c): return c["id"])
	_check("sword_whirl" in av and "sniper_mark" in av and "shotgun_airkick" not in av, "bộ thẻ gồm kho chung + kiếm + súng đang cầm")
	_check(Lvl.effect_text(pool["sword_lunge"], 1) == "Lao tới 6 m", "thẻ kiếm hiện chữ hiệu ứng riêng")

	print("[Phá thế đỡ + Mũi nhọn xuyên giáp]")
	await _world()
	var d := _dummy(Vector3(0.0, 0.0, 18.5))
	await _frames(4)
	_arm(d)
	var kicks: Array = []
	cb.self_impulse.connect(func(v): kicks.append(v))
	var rebs: Array = []
	cb.sword_rebounded.connect(func(): rebs.append(1))
	# không đỡ: chém trúng bình thường
	await _swing_and_wait()
	_check(is_equal_approx(_hp(d), 30.0) and kicks.is_empty(), "bot không đỡ: trúng 30 sát thương, không dội")
	# đỡ, lỗi tắt (ngoài Vô Tận): chỉ bị parry như cũ
	d.hurtbox.health = 100000.0
	d.parry.active_t = 5.0
	d.parry.cooldown_t = 0.0
	cb.want_attack = true
	await _frames(1)
	cb.want_attack = false
	var guard: bool = false
	for i in 40:
		await _frames(1)
		if pl.melee.is_staggered():
			guard = true
			break
	_check(guard and absf(pl.melee._stagger_t - 1.0) < 0.15 and kicks.is_empty() and rebs.is_empty(), "lỗi tắt: bị parry khựng 1.0 s như cũ, không bị đẩy (%.2f)" % pl.melee._stagger_t)
	await _frames(90)
	# lỗi bật
	cb.flaws.enabled = true
	await _frames(2)
	_check(is_equal_approx(pl.melee.guard_rebound, 0.4), "lỗi bật: melee nhận guard_rebound 0.4")
	pl.instability.reset()
	d.hurtbox.health = 100000.0
	d.parry.active_t = 5.0
	d.parry.cooldown_t = 0.0
	cb.want_attack = true
	await _frames(1)
	cb.want_attack = false
	guard = false
	for i in 40:
		await _frames(1)
		if pl.melee.is_staggered():
			guard = true
			break
	_check(guard and absf(pl.melee._stagger_t - 1.4) < 0.15, "Phá thế đỡ: khựng 1.4 s (%.2f)" % pl.melee._stagger_t)
	_check(kicks.size() == 1 and is_equal_approx(kicks[0].z, 6.0) and rebs.size() == 1, "bị đẩy lùi 6 m/s ra sau (%s), phát sword_rebounded" % [kicks])
	_check(is_equal_approx(_hp(d), 0.0), "bot đỡ được: không mất máu")
	await _frames(120)
	# Mũi nhọn xuyên giáp
	for tier in [1, 2]:
		cb.weapon_mods = {"sword_pierce": 0.5 * tier}
		await _frames(2)
		pl.instability.reset()   # nhiều lần bị parry sẽ gây Destabilized, tách khỏi phép đo
		d.hurtbox.health = 100000.0
		d.parry.active_t = 5.0
		d.parry.cooldown_t = 0.0
		kicks.clear()
		cb.want_attack = true
		await _frames(1)
		cb.want_attack = false
		await _frames(30)
		_check(is_equal_approx(_hp(d), 15.0 * tier), "Mũi nhọn xuyên giáp bậc %d: bot đang đỡ vẫn nhận %.0f" % [tier, 15.0 * tier])
		_check(kicks.size() == 1, "bậc %d: lỗi dội lại vẫn xảy ra" % tier)
		await _frames(120)
	await _clear()

	print("[Nhịp phản đòn]")
	await _world()
	cb.flaws.enabled = true
	d = _dummy(Vector3(0.0, 0.0, 18.5))
	await _frames(4)
	_arm(d)
	cb.weapon_mods = {"sword_riposte": 1.0}
	await _frames(2)
	pl.parry.parried.emit({"kind": "melee"})
	_check(is_equal_approx(pl.melee.riposte_t, 2.0), "parry thành công: mở cửa sổ phản đòn 2 s")
	await _swing_and_wait()
	_check(is_equal_approx(_hp(d), 54.0), "cú chém kế: +80%% sát thương (%.0f)" % _hp(d))
	_check(pl.melee.riposte_t == 0.0, "dùng xong thì hết")
	d.hurtbox.health = 100000.0
	await _swing_and_wait()
	_check(is_equal_approx(_hp(d), 30.0), "cú sau lại bình thường")
	pl.parry.parried.emit({"kind": "bullet"})
	pl.melee._physics_process(2.1)
	_check(pl.melee.riposte_t == 0.0, "quá 2 s: mất phản đòn")
	# phản đòn không bị dội
	var kk: Array = []
	cb.self_impulse.connect(func(v): kk.append(v))
	pl.parry.parried.emit({"kind": "melee"})
	d.hurtbox.health = 100000.0
	d.parry.active_t = 5.0
	d.parry.cooldown_t = 0.0
	cb.want_attack = true
	await _frames(1)
	cb.want_attack = false
	var st: bool = false
	for i in 40:
		await _frames(1)
		if pl.melee.is_staggered():
			st = true
			break
	_check(st and absf(pl.melee._stagger_t - 1.0) < 0.15 and kk.is_empty(), "chém phản đòn vào bot đang đỡ: không bị dội thêm (%.2f)" % pl.melee._stagger_t)
	await _clear()
	# không có thẻ: parry không mở cửa sổ
	await _world()
	pl.parry.parried.emit({"kind": "melee"})
	_check(pl.melee.riposte_t == 0.0, "không có thẻ: parry không mở cửa sổ")
	await _clear()

	print("[Lưỡi kiếm lao]")
	await _world()
	var far := _bot(Vector3(0.0, 0.0, 15.0))
	await _frames(4)
	var imp: Array = []
	cb.self_impulse.connect(func(v): imp.append(v))
	_check(not cb._try_lunge() and imp.is_empty(), "không có thẻ: không lao")
	cb.weapon_mods = {"sword_lunge": 1.0}
	_check(cb._try_lunge() and imp.size() == 1, "có thẻ: bot ở 5 m phía trước -> lao")
	var want_speed: float = (5.0 - 1.6) * 7.0
	_check(absf(imp[0].length() - want_speed) < 0.5 and imp[0].z < 0.0, "xung hướng về bot (%.1f m/s)" % imp[0].length())
	_check(is_equal_approx(cb._lunge_cd, 3.0), "hồi 3 s")
	_check(not cb._try_lunge(), "đang hồi: không lao lại")
	cb._lunge_cd = 0.0
	cb._lunge_pending = false
	# vị trí bot: gần, xa, sau lưng
	far.position = Vector3(0.0, 0.0, 18.5)
	await _frames(3)
	_check(not cb._try_lunge(), "bot ở 1.5 m (trong tầm chém): chém thường, không lao")
	far.position = Vector3(0.0, 0.0, 12.0)
	await _frames(3)
	_check(not cb._try_lunge(), "bot ở 8 m: ngoài tầm lao")
	far.position = Vector3(0.0, 0.0, 25.0)
	await _frames(3)
	_check(not cb._try_lunge(), "bot sau lưng: không lao")
	# lao thật: đo quãng đường và độ hở
	far.position = Vector3(0.0, 0.0, 15.0)
	await _frames(3)
	imp.clear()
	pl.velocity = Vector3.ZERO
	var stag: Array = []
	pl.melee.staggered.connect(func(dur): stag.append(dur))
	cb.want_attack = true
	await _frames(1)
	cb.want_attack = false
	await _frames(60)
	var gap: float = Vector2(pl.global_position.x - far.global_position.x, pl.global_position.z - far.global_position.z).length()
	_check(imp.size() == 1 and gap < 2.6 and gap > 0.8, "lao thật: từ 5 m còn cách bot %.2f m (trong tầm kiếm 2.4)" % gap)
	_check(_hp(far) > 0.0, "cú chém ngay sau khi lao trúng bot (-%.0f)" % _hp(far))
	_check(stag.size() == 1 and is_equal_approx(stag[0], 0.3), "lao xong hở 0.3 s (khựng %s)" % [stag])
	await _clear()

	print("[Vòng chém]")
	await _world()
	var bf := _bot(Vector3(0.0, 0.0, 18.0))
	var bb := _bot(Vector3(0.0, 0.0, 22.0))
	var bl := _bot(Vector3(-2.0, 0.0, 20.0))
	await _frames(4)
	cb.weapon_mods = {}
	await _swing_and_wait()
	_check(is_equal_approx(_hp(bf), 30.0) and _hp(bb) == 0.0 and _hp(bl) == 0.0, "không thẻ: chém chỉ trúng bot phía trước")
	bf.hurtbox.health = 100000.0
	cb.weapon_mods = {"sword_whirl": 1.0}
	await _frames(100)   # hết combo
	await _swing_and_wait()
	await _swing_and_wait()
	_check(cb._combo == 2, "đã chém 2 lần liên tiếp (combo 2)")
	_check(_hp(bb) == 0.0 and _hp(bl) == 0.0, "2 cú đầu: bot sau lưng / bên trái chưa bị trúng")
	bf.hurtbox.health = 100000.0
	bf._kb = Vector3.ZERO
	bb._kb = Vector3.ZERO
	cb.want_attack = true
	await _frames(1)
	cb.want_attack = false
	_check(pl.melee.whirl_next == false and pl.melee._whirl, "cú thứ 3 là vòng chém")
	await _frames(40)
	_check(is_equal_approx(_hp(bf), 18.0) and is_equal_approx(_hp(bb), 18.0) and is_equal_approx(_hp(bl), 18.0), "vòng chém: cả 3 bot quanh người nhận 60%% (18) (%.0f / %.0f / %.0f)" % [_hp(bf), _hp(bb), _hp(bl)])
	_check(bb._kb.length() > 6.0 and bb._kb.z > 0.0, "bot sau lưng bị hất ra xa (%.1f m/s)" % bb._kb.length())
	_check(cb._combo == 0, "sau vòng chém: combo về 0")
	await _frames(100)
	for b in [bf, bb, bl]:
		b.hurtbox.health = 100000.0
	await _swing_and_wait()
	_check(is_equal_approx(_hp(bf), 30.0) and _hp(bb) == 0.0, "cú kế tiếp lại là chém thường")
	# quá 1.5 s nghỉ: combo reset
	await _swing_and_wait()
	await _frames(100)
	_check(cb._combo == 0, "nghỉ quá 1.5 s: combo reset")
	await _clear()

	print("[Tích hợp main]")
	G.set_mode("endless")
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(15)
	main._start_mode()
	await _frames(3)
	var mc = main.player.combat
	_check(mc.flaws.enabled and is_equal_approx(main.player.melee.guard_rebound, 0.4) if (await _after(2)) else false, "Vô Tận: lỗi kiếm bật")
	_check(main.hud._flaw_label.text.contains("Phá thế đỡ") and main.hud._flaw_label.text.contains("LỖI:"), "HUD hiện cả lỗi súng và lỗi kiếm")
	main.progress.taken = {"sword_pierce": 2, "sword_whirl": 1, "shotgun_airkick": 1}
	main._apply_upgrades()
	var wm: Dictionary = mc.weapon_mods
	_check(is_equal_approx(float(wm["sword_pierce"]), 1.0) and float(wm["sword_whirl"]) == 1.0 and float(wm["sword_lunge"]) == 0.0, "main chép stat thẻ kiếm vào weapon_mods")
	mc.sword_rebounded.emit()   # main nối vào âm thanh + HUD: không được lỗi
	main.queue_free()
	await _frames(10)
	G.set_mode("training")
	var main2 = load("res://scenes/main.tscn").instantiate()
	main2.autostart_waves = false
	root.add_child(main2)
	await _frames(15)
	await _frames(2)
	_check(not main2.player.combat.flaws.enabled and main2.player.melee.guard_rebound == 0.0, "Sinh tồn: lỗi kiếm tắt")
	main2.queue_free()
	await _frames(10)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.save_path))

	print("---")
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)


func _after(n: int) -> bool:
	await _frames(n)
	return true
