extends SceneTree
## Test headless chiến đấu: kiếm, súng, đạn, parry, clash, chết.
##   timeout 200 godot --headless --path . -s tools/tests/test_combat.gd

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
	s.size = Vector3(100, 1, 100)
	c.shape = s
	b.add_child(c)
	b.position.y = -0.5
	world.add_child(b)


## Dựng lại người chơi (ở gốc, nhìn về -Z) và 1 dummy cách `dist` m phía trước, mặt hướng người chơi.
func _setup(dist: float = 2.0, dummy_hp: float = 1000.0) -> void:
	if player != null:
		player.queue_free()
		dummy.queue_free()
		await process_frame
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	dummy = load("res://scripts/enemy_dummy.gd").new()
	dummy.position = Vector3(0, 0, -dist)
	dummy.rotation.y = PI
	world.add_child(dummy)
	await _frames(5)
	dummy.hurtbox.setup(Global.TEAM_ENEMY, dummy_hp, dummy.parry)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	world = Node3D.new()
	root.add_child(world)
	_make_floor()
	var C: Dictionary = Global.COMBAT

	# ---------------- KIẾM
	print("[kiếm]")
	await _setup(2.0)
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	await _frames(40)
	_check(dummy.hurtbox.health == 1000.0 - C["sword_damage"], "kiếm trúng đúng 1 lần / đòn (máu %.0f)" % dummy.hurtbox.health)
	_check(player.melee.phase == player.melee.Phase.IDLE, "hồi xong về IDLE")
	# Giữ chuột: không đánh lại trong lúc hồi
	var hp0: float = dummy.hurtbox.health
	player.combat.want_attack = true
	await _frames(3)
	_check(player.melee.try_swing() == false, "đang trong đòn thì không vung chồng")
	player.combat.want_attack = false
	await _frames(40)
	# Ngoài tầm
	await _setup(6.0)
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	await _frames(40)
	_check(dummy.hurtbox.health == 1000.0, "ngoài tầm kiếm thì không trúng")

	# ---------------- CHẾT
	print("[chết]")
	await _setup(2.0, Global.COMBAT["dummy_health"])
	var died: Array = []
	dummy.hurtbox.died.connect(func(): died.append(1))
	for i in 2:
		player.combat.want_attack = true
		await _frames(1)
		player.combat.want_attack = false
		await _frames(40)
	_check(dummy.hurtbox.dead and died.size() == 1, "máu về 0 -> chết, phát signal died đúng 1 lần")
	_check(dummy.hurtbox.take_hit({"damage": 10.0, "kind": "hitscan"}) == false, "đã chết thì không nhận thêm sát thương")

	# ---------------- SÚNG
	print("[súng]")
	await _setup(10.0)
	var mag: int = C["gun_mag"]
	player.combat.want_shoot = true
	await _frames(1)
	player.combat.want_shoot = false
	_check(dummy.hurtbox.health == 1000.0 - C["gun_damage"], "súng trúng bia (máu %.0f)" % dummy.hurtbox.health)
	_check(player.combat.ammo == mag - 1, "tốn 1 viên (%d/%d)" % [player.combat.ammo, mag])
	player.combat.want_shoot = true
	await _frames(1)
	_check(player.combat.ammo == mag - 1, "bắn liền tay bị chặn bởi cooldown")
	await _frames(140) # bắn hết băng
	_check(player.combat.reloading or player.combat.ammo == mag, "hết đạn thì tự nạp")
	player.combat.want_shoot = false
	await _frames(100)
	_check(player.combat.ammo == mag and not player.combat.reloading, "nạp xong đầy băng (%d)" % player.combat.ammo)

	# ---------------- ĐẠN CỦA ĐỊCH (không parry)
	print("[đạn địch]")
	await _setup(5.0)
	dummy.shoot_at(player.global_position + Vector3(0, 1.2, 0))
	await _frames(30)
	_check(player.hurtbox.health == 100.0 - C["bullet_damage"], "đạn địch trúng người chơi (máu %.0f)" % player.hurtbox.health)

	# ---------------- PARRY ĐẠN
	print("[parry đạn]")
	await _setup(5.0)
	var reflected_events: Array = []
	player.parry.parried.connect(func(h): reflected_events.append(h))
	player.combat.want_parry = true
	await _frames(1)
	var b = dummy.shoot_at(player.global_position + Vector3(0, 1.2, 0))
	await _frames(9) # đạn đã chạm cửa sổ parry và đang bay ngược lại
	_check(is_instance_valid(b) and b.reflected and b.team == Global.TEAM_PLAYER, "đạn đổi chủ sang người chơi")
	_check(is_instance_valid(b) and b.velocity.z < 0.0 and b.velocity.length() > Global.COMBAT["bullet_speed"], "đạn bay ngược về người bắn, nhanh hơn (%.1f m/s)" % (b.velocity.length() if is_instance_valid(b) else 0.0))
	await _frames(40)
	_check(player.hurtbox.health == 100.0, "parry đúng lúc: người chơi không mất máu")
	_check(reflected_events.size() == 1, "phát signal parried")
	var expect: float = 1000.0 - float(C["bullet_damage"]) * float(C["reflect_damage_mult"])
	_check(absf(dummy.hurtbox.health - expect) < 0.01, "đạn phản bay về trúng người bắn, sát thương nhân %.1f (máu %.1f)" % [C["reflect_damage_mult"], dummy.hurtbox.health])

	# ---------------- PARRY HỤT
	print("[parry hụt]")
	await _setup(5.0)
	var missed: Array = []
	player.parry.parry_missed.connect(func(): missed.append(1))
	player.combat.want_parry = true
	await _frames(30) # > 0.18s
	_check(missed.size() == 1, "hết cửa sổ mà không đỡ -> parry_missed")
	_check(player.parry.press() == false, "bị phạt: chưa parry lại được")
	await _frames(60)
	_check(player.parry.can_press(), "hết phạt thì parry lại được")
	# Parry quá sớm so với đạn: bị trúng
	await _setup(30.0)
	player.combat.want_parry = true
	await _frames(1)
	dummy.shoot_at(player.global_position + Vector3(0, 1.2, 0)) # đạn tới sau ~0.7s, cửa sổ đã đóng
	await _frames(70)
	_check(player.hurtbox.health == 100.0 - C["bullet_damage"], "parry sớm quá -> vẫn bị trúng")

	# ---------------- PARRY KIẾM
	print("[parry kiếm]")
	await _setup(2.0)
	player.combat.want_parry = true
	await _frames(1)
	dummy.swing()
	await _frames(40)
	_check(player.hurtbox.health == 100.0, "parry đòn kiếm: không mất máu")
	_check(dummy.melee.is_staggered(), "kẻ tấn công bị choáng")
	_check(dummy.melee.try_swing() == false, "đang choáng thì không đánh được")
	# Không parry: mất máu
	await _setup(2.0)
	dummy.swing()
	await _frames(40)
	_check(player.hurtbox.health == 100.0 - C["sword_damage"], "không parry: ăn đòn kiếm (máu %.0f)" % player.hurtbox.health)

	# ---------------- CLASH
	print("[clash]")
	await _setup(2.0)
	var clashes: Array = []
	player.melee.clashed.connect(func(d): clashes.append(d))
	player.combat.want_attack = true
	dummy.swing()
	await _frames(1)
	player.combat.want_attack = false
	await _frames(25)
	_check(clashes.size() == 1, "hai kiếm cùng active -> CLASH")
	_check(player.hurtbox.health == 100.0 and dummy.hurtbox.health == 1000.0, "clash: không bên nào mất máu")
	_check(player.melee.is_staggered() and dummy.melee.is_staggered(), "cả hai bị choáng")
	_check(player.velocity.z > 1.0 or player.global_position.z > 0.1, "người chơi bị đẩy lùi (vz=%.1f, z=%.2f)" % [player.velocity.z, player.global_position.z])

	# ---------------- NGƯỜI CHƠI CHẾT + HỒI SINH
	print("[người chơi chết]")
	await _setup(5.0)
	var pdied: Array = []
	player.died.connect(func(): pdied.append(1))
	for i in 7:
		dummy.shoot_at(player.global_position + Vector3(0, 1.2, 0))
		await _frames(25)
	_check(player.dead and pdied.size() == 1, "máu về 0 -> player.dead, phát died")
	player.respawn(Vector3(0, 0.1, 0))
	await _frames(2)
	_check(not player.dead and player.hurtbox.health == Global.COMBAT["player_health"], "hồi sinh: đầy máu, hết dead")

	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
