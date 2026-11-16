extends SceneTree
## Test headless M10: 4 súng, đổi súng, đạn riêng, shotgun tản/giảm theo xa, pháo nổ (lan, đẩy, tự đẩy),
## bắn tỉa (headshot, xuyên), chém rộng.
##   timeout 200 godot --headless --path . -s tools/tests/test_weapons.gd

var failures: int = 0
var world: Node3D
var player
var dummy


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


func _setup(dist: float, use_bot: bool = false) -> void:
	if player != null:
		player.queue_free()
		dummy.queue_free()
		await process_frame
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	if use_bot:
		dummy = load("res://scripts/bot.gd").new()
		dummy.setup("swordsman", 1)
		dummy.position = Vector3(0, 0.1, -dist)
	else:
		dummy = load("res://scripts/enemy_dummy.gd").new()
		dummy.position = Vector3(0, 0, -dist)
		dummy.rotation.y = PI
	world.add_child(dummy)
	await _frames(5)
	dummy.hurtbox.setup(Global.TEAM_ENEMY, 1000.0, dummy.parry)
	player.combat.refill()


func _fire(id: String) -> void:
	player.combat.switch_to(id)
	player.combat._shot_cd = 0.0
	player.combat.want_shoot = true
	await _frames(1)
	player.combat.want_shoot = false
	await _frames(1)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	world = Node3D.new()
	root.add_child(world)
	_make_floor()
	var W: Dictionary = Global.WEAPONS

	print("[đổi súng + đạn riêng]")
	await _setup(10.0)
	var c = player.combat
	_check(c.weapon == "pistol", "mặc định súng lục")
	var seen: Array = []
	c.weapon_changed.connect(func(id, _n): seen.append(id))
	c.want_weapon = 1
	await _frames(2)
	_check(c.weapon == "shotgun" and seen == ["shotgun"], "phím 2 -> shotgun, phát weapon_changed")
	c.want_cycle = 1
	await _frames(2)
	_check(c.weapon == "launcher", "cuộn chuột -> súng kế (pháo nổ)")
	c.want_cycle = -1
	await _frames(2)
	_check(c.weapon == "shotgun", "cuộn ngược -> shotgun")
	c.switch_to("pistol")
	await _frames(2)
	_check(c.ammo == int(W["pistol"]["mag"]), "mỗi súng giữ băng đạn riêng")
	await _fire("pistol")
	_check(c.ammo == int(W["pistol"]["mag"]) - 1, "bắn súng lục trừ 1 đạn")
	c.switch_to("shotgun")
	_check(c.ammo == int(W["shotgun"]["mag"]), "shotgun còn đầy băng (không dính đạn súng lục)")
	c.switch_to("pistol")
	_check(c.ammo == int(W["pistol"]["mag"]) - 1, "quay lại súng lục: đạn còn nguyên số cũ")
	c.want_reload = true
	await _frames(2)
	_check(c.reloading, "đang nạp súng lục")
	c.switch_to("sniper")
	_check(not c.reloading, "đổi súng huỷ nạp đạn")
	_check(c._shot_cd >= float(W["sniper"]["draw"]) - 0.05, "đổi súng có thời gian rút súng")
	c.refill()
	_check(c.ammo == int(W["sniper"]["mag"]), "refill: nạp đầy cả 4 súng")
	c.switch_to("pistol")
	_check(c.ammo == int(W["pistol"]["mag"]), "refill: súng lục cũng đầy")

	print("[súng lục]")
	await _setup(10.0)
	await _fire("pistol")
	_check(is_equal_approx(dummy.hurtbox.health, 1000.0 - float(W["pistol"]["damage"])), "súng lục gây %.0f sát thương" % W["pistol"]["damage"])

	print("[shotgun]")
	await _setup(4.0)
	await _fire("shotgun")
	var near_dmg: float = 1000.0 - dummy.hurtbox.health
	_check(near_dmg > float(W["shotgun"]["damage"]) * 3.0, "shotgun cận chiến trúng nhiều viên (%.0f)" % near_dmg)
	_check(near_dmg <= float(W["shotgun"]["damage"]) * int(W["shotgun"]["pellets"]) + 0.01, "không vượt tổng sát thương các viên")
	await _setup(30.0)
	await _fire("shotgun")
	var far_dmg: float = 1000.0 - dummy.hurtbox.health
	_check(far_dmg < near_dmg, "shotgun xa yếu hơn gần (%.0f < %.0f)" % [far_dmg, near_dmg])
	_check(player.combat.ammo == int(W["shotgun"]["mag"]) - 1, "shotgun trừ 1 đạn / phát (nhiều viên)")
	# Trên không: đẩy lùi mạnh hơn súng lục
	await _setup(10.0)
	player.global_position = Vector3(0, 8, 0)
	player.velocity = Vector3.ZERO
	await _frames(2)
	var v0: Vector3 = player.velocity
	await _fire("shotgun")
	var v_sg: float = (player.velocity - v0).length()
	await _setup(10.0)
	player.global_position = Vector3(0, 8, 0)
	player.velocity = Vector3.ZERO
	await _frames(2)
	v0 = player.velocity
	await _fire("pistol")
	var v_pi: float = (player.velocity - v0).length()
	_check(v_sg > v_pi * 2.0, "recoil trên không: shotgun (%.1f) >> súng lục (%.1f)" % [v_sg, v_pi])

	print("[pháo nổ]")
	await _setup(12.0, true)
	var bot = dummy
	var boom: Array = []
	player.combat.exploded.connect(func(p, r): boom.append([p, r]))
	await _fire("launcher")
	await _frames(60)
	_check(boom.size() == 1, "đạn pháo nổ đúng 1 lần")
	_check(bot.hurtbox.health < 1000.0, "vụ nổ trúng gây sát thương (%.0f)" % (1000.0 - bot.hurtbox.health))
	# Nổ tại chỗ để kiểm tra đẩy lùi + falloff + tự đẩy
	await _setup(10.0, true)
	bot = dummy
	bot.hurtbox.setup(Global.TEAM_ENEMY, 1000.0, bot.parry)
	var cfgL: Dictionary = W["launcher"]
	var RocketS = load("res://scripts/rocket.gd")
	var z0: float = bot.global_position.z
	RocketS.explode(world.get_world_3d(), bot.global_position + Vector3(0, 0.95, 1.0), cfgL, player)
	var d_close: float = 1000.0 - bot.hurtbox.health
	_check(d_close > 0.0 and d_close <= float(cfgL["damage"]) + 0.01, "nổ sát: sát thương trong (0, %.0f] (%.1f)" % [cfgL["damage"], d_close])
	_check(bot.melee.is_staggered(), "kẻ địch trong vùng nổ bị choáng")
	await _frames(30)
	_check(bot.global_position.z < z0 - 0.5, "kẻ địch bị đẩy lùi khỏi tâm nổ (%.2fm)" % (z0 - bot.global_position.z))
	await _setup(10.0, true)
	bot = dummy
	bot.hurtbox.setup(Global.TEAM_ENEMY, 1000.0, bot.parry)
	RocketS.explode(world.get_world_3d(), bot.global_position + Vector3(0, 0.95, float(cfgL["blast_radius"]) * 0.9), cfgL, player)
	var d_edge: float = 1000.0 - bot.hurtbox.health
	_check(d_edge > 0.0 and d_edge < d_close, "mép vùng nổ yếu hơn sát tâm (%.1f < %.1f)" % [d_edge, d_close])
	await _setup(30.0, true)
	bot = dummy
	bot.hurtbox.setup(Global.TEAM_ENEMY, 1000.0, bot.parry)
	RocketS.explode(world.get_world_3d(), Vector3(0, 0.95, 5.0), cfgL, player)
	_check(bot.hurtbox.health == 1000.0, "ngoài bán kính: không sát thương")
	# Tự đẩy (rocket-jump)
	await _setup(30.0, true)
	var hp_p: float = player.hurtbox.health
	player.velocity = Vector3.ZERO
	RocketS.explode(world.get_world_3d(), player.global_position + Vector3(0, 0.0, 0.5), cfgL, player)
	_check(player.velocity.length() > 5.0, "rocket-jump: nổ gần chân đẩy người chơi (%.1f m/s)" % player.velocity.length())
	var self_dmg: float = hp_p - player.hurtbox.health
	_check(self_dmg > 0.0 and self_dmg < float(cfgL["damage"]) * 0.3, "tự gây sát thương nhỏ (%.1f)" % self_dmg)

	print("[bắn tỉa]")
	await _setup(40.0)
	var sn: Dictionary = W["sniper"]
	# Dummy cao ~1.8m, hurtbox gốc ở chân. Nhắm thân (giữa) vs đầu.
	player.global_position = Vector3(0, 0.1, 0)
	await _fire("sniper") # ngắm ngang tầm mắt (1.6m) ≈ đầu
	var head_dmg: float = 1000.0 - dummy.hurtbox.health
	_check(is_equal_approx(head_dmg, float(sn["damage"]) * float(sn["headshot_mult"])), "headshot nhân %.0f (%.0f)" % [sn["headshot_mult"], head_dmg])
	await _setup(40.0)
	player.head.rotation.x = -0.014 # nhắm hơi xuống: trúng thân
	await _fire("sniper")
	var body_dmg: float = 1000.0 - dummy.hurtbox.health
	_check(is_equal_approx(body_dmg, float(sn["damage"])), "bắn thân: %.0f sát thương cơ bản (%.0f)" % [sn["damage"], body_dmg])
	# Xuyên: hai dummy thẳng hàng
	await _setup(20.0)
	var d2 = load("res://scripts/enemy_dummy.gd").new()
	d2.position = Vector3(0, 0, -35.0)
	d2.rotation.y = PI
	world.add_child(d2)
	await _frames(5)
	d2.hurtbox.setup(Global.TEAM_ENEMY, 1000.0, d2.parry)
	player.head.rotation.x = -0.02
	await _fire("sniper")
	var first: float = 1000.0 - dummy.hurtbox.health
	var second: float = 1000.0 - d2.hurtbox.health
	_check(first > 0.0 and second > 0.0, "đạn xuyên: trúng cả hai mục tiêu (%.0f, %.0f)" % [first, second])
	_check(second < first, "mục tiêu thứ hai nhận ít hơn (%.0f < %.0f)" % [second, first])
	d2.queue_free()
	player.head.rotation.x = 0.0
	# Zoom
	player.combat.switch_to("sniper")
	player.combat.want_zoom = true
	_check(player.combat.zoom_fov() == float(sn["zoom_fov"]), "ngắm bắn tỉa: FOV thu hẹp")
	player.combat.switch_to("pistol")
	_check(player.combat.zoom_fov() == 0.0, "súng khác không zoom")
	player.combat.want_zoom = false
	# Tường chặn đạn xuyên
	var wall := StaticBody3D.new()
	wall.collision_layer = Global.L_WORLD
	var wc := CollisionShape3D.new()
	var ws := BoxShape3D.new()
	ws.size = Vector3(6, 6, 0.4)
	wc.shape = ws
	wall.add_child(wc)
	wall.position = Vector3(0, 2, -20)
	world.add_child(wall)
	await _setup(40.0)
	await _fire("sniper")
	_check(dummy.hurtbox.health == 1000.0, "tường chặn tia bắn tỉa")
	wall.queue_free()

	print("[chém rộng]")
	await _setup(2.0)
	var m = player.melee
	var normal_wind: Array = [0.0]
	m.swing_started.connect(func(w, _a, _r): normal_wind[0] = w)
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	await _frames(60)
	var normal_dmg: float = 1000.0 - dummy.hurtbox.health
	var wind1: float = normal_wind[0]
	await _setup(2.0)
	m = player.melee
	m.swing_started.connect(func(w, _a, _r): normal_wind[0] = w)
	player.combat.want_heavy = true
	await _frames(1)
	var wind2: float = normal_wind[0]
	_check(m.heavy, "Q kích hoạt chém rộng")
	await _frames(90)
	var heavy_dmg: float = 1000.0 - dummy.hurtbox.health
	_check(wind2 > wind1 * 1.4, "chém rộng báo đòn lâu hơn (%.2f > %.2f)" % [wind2, wind1])
	_check(heavy_dmg > normal_dmg, "chém rộng đau hơn (%.0f > %.0f)" % [heavy_dmg, normal_dmg])
	# Quét rộng: mục tiêu lệch ngang 1.4m chỉ trúng chém rộng
	await _setup(2.0)
	dummy.position.x = 1.35
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	await _frames(60)
	_check(dummy.hurtbox.health == 1000.0, "chém thường không với tới mục tiêu lệch 1.35m")
	await _setup(2.0)
	dummy.position.x = 1.35
	player.combat.want_heavy = true
	await _frames(1)
	await _frames(90)
	_check(dummy.hurtbox.health < 1000.0, "chém rộng quét trúng mục tiêu lệch 1.35m")

	print("----", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
