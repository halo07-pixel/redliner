extends SceneTree
## Test headless M12: vệt kiếm, vật nhặt, thùng nổ (dây chuyền), thùng gỗ, giảm hiệu ứng.
##   timeout 200 godot --headless --path . -s tools/tests/test_effects.gd

var failures: int = 0
var world: Node3D
var player


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run()


func _floor() -> void:
	var b := StaticBody3D.new()
	b.collision_layer = Global.L_WORLD
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(200, 1, 200)
	c.shape = s
	b.add_child(c)
	b.position.y = -0.5
	world.add_child(b)


func _new_player() -> void:
	if player != null:
		player.queue_free()
		await process_frame
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	await _frames(5)


func _prop(kind: String, pos: Vector3):
	var b = load("res://scripts/breakable.gd").new()
	b.kind = kind
	b.position = pos
	world.add_child(b)
	return b


func _run() -> void:
	await process_frame
	var G = root.get_node("Global")
	G.save_path = "user://test_fx.cfg"
	G.load_save()
	world = Node3D.new()
	root.add_child(world)
	_floor()
	var Pickup = load("res://scripts/pickup.gd")

	print("[vệt kiếm]")
	await _new_player()
	var trail = null
	for ch in player.melee.get_children():
		if ch.get_script() != null and str(ch.get_script().resource_path).ends_with("sword_trail.gd"):
			trail = ch
	_check(trail != null, "melee của người chơi có SwordTrail")
	_check(not trail.is_drawing(), "chưa chém: không có vệt")
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	var peak: int = 0
	for i in 40:
		await process_frame
		peak = maxi(peak, trail.point_count())
	_check(peak >= 3, "chém thường tạo vệt (đỉnh %d điểm)" % peak)
	await _frames(60)
	for i in 5:
		await process_frame
	_check(trail.point_count() == 0 and not trail.is_drawing(), "vệt tự xoá sau khi mờ")
	# chém rộng: vệt rộng hơn (mũi kiếm tách xa hơn)
	player.combat.want_heavy = true
	await _frames(1)
	var widest: float = 0.0
	for i in 70:
		await process_frame
		if trail.point_count() >= 2:
			var a: Vector3 = trail._points[0]["tip"]
			var b: Vector3 = trail._points[trail._points.size() - 1]["tip"]
			widest = maxf(widest, a.distance_to(b))
	_check(widest > 1.2, "chém rộng có vệt quét rộng (%.2f m)" % widest)
	await _frames(80)
	G.set_reduced_fx(true)
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	peak = 0
	for i in 40:
		await process_frame
		peak = maxi(peak, trail.point_count())
	_check(peak == 0, "giảm hiệu ứng: không vẽ vệt kiếm")
	var Fx = load("res://scripts/fx.gd")
	_check(Fx.ring(world, Vector3.ZERO, Color.WHITE) == null, "giảm hiệu ứng: không có sóng parry")
	G.set_reduced_fx(false)
	var ring = Fx.ring(world, Vector3(0, 1, 0), Color.WHITE)
	_check(ring != null, "bình thường: có sóng parry")
	await create_timer(0.5).timeout
	_check(not is_instance_valid(ring), "sóng parry tự biến mất")

	print("[hạt + rung khi giảm hiệu ứng]")
	var n_before: int = world.get_child_count()
	Fx.sparks(world, Vector3.ZERO, Color.WHITE)
	var full: int = (world.get_child(world.get_child_count() - 1) as CPUParticles3D).amount
	G.set_reduced_fx(true)
	Fx.sparks(world, Vector3.ZERO, Color.WHITE)
	var reduced: int = (world.get_child(world.get_child_count() - 1) as CPUParticles3D).amount
	_check(reduced < full and reduced >= 4, "hạt giảm còn %d (từ %d)" % [reduced, full])
	player._shake = 0.0
	player.shake(0.1)
	_check(is_equal_approx(player._shake, 0.1 * float(Global.FX["reduced_shake"])), "rung camera yếu đi khi giảm hiệu ứng")
	G.set_reduced_fx(false)
	player._shake = 0.0
	player.shake(0.1)
	_check(is_equal_approx(player._shake, 0.1), "tắt giảm hiệu ứng: rung đầy đủ")
	G.selected_map = "yard"
	G.set_reduced_fx(true)
	G.reduced_fx = false
	G.load_save()
	_check(G.reduced_fx, "công tắc giảm hiệu ứng được lưu và tải lại")
	G.set_reduced_fx(false)

	print("[vật nhặt]")
	var kinds: Dictionary = Global.PICKUPS["kinds"]
	_check(Pickup.pick_kind(0.0) in kinds and Pickup.pick_kind(0.999) in kinds, "pick_kind trả loại hợp lệ")
	var count: Dictionary = {}
	for i in 1000:
		var k: String = Pickup.pick_kind(float(i) / 1000.0)
		count[k] = count.get(k, 0) + 1
	_check(count.size() == 3 and count["health"] > count["stamina"], "phân bố theo trọng số (health nhiều hơn stamina)")
	await _new_player()
	var got: Array = []
	var pk = Pickup.spawn(world, Vector3(0, 0.1, 0), "health")
	pk.collected.connect(func(k): got.append(k))
	await _frames(4)
	_check(got == ["health"], "chạm vào thì phát collected(health)")
	await process_frame
	_check(not is_instance_valid(pk), "vật nhặt biến mất sau khi nhặt")
	# hồi máu
	player.hurtbox.health = 40.0
	var healed: float = player.hurtbox.heal(30.0)
	_check(is_equal_approx(player.hurtbox.health, 70.0) and is_equal_approx(healed, 30.0), "heal +30 (40 -> 70)")
	player.hurtbox.heal(500.0)
	_check(player.hurtbox.health == player.hurtbox.max_health, "heal không vượt máu tối đa")
	# người khác chạm: không nhặt
	var far = Pickup.spawn(world, Vector3(50, 0.1, 50), "ammo")
	var far_got: Array = []
	far.collected.connect(func(k): far_got.append(k))
	await _frames(5)
	_check(far_got.is_empty() and is_instance_valid(far), "ở xa thì không bị nhặt")
	# hết hạn
	far.age = float(Global.PICKUPS["lifetime"]) - 0.05
	await create_timer(0.3).timeout
	_check(not is_instance_valid(far), "vật nhặt biến mất khi hết hạn")

	print("[thùng nổ]")
	await _new_player()
	player.global_position = Vector3(30, 0.1, 30) # xa vùng nổ
	var barrel = _prop("barrel", Vector3(0, 0, -10))
	var barrel2 = _prop("barrel", Vector3(0, 0, -13)) # trong tầm nổ của barrel 1 (3 m < 5 m)
	var crate = _prop("crate", Vector3(0, 0, -11.5))
	var far_barrel = _prop("barrel", Vector3(-30, 0, -10))
	var boom: Array = []
	barrel.exploded.connect(func(p, r): boom.append(p))
	barrel2.exploded.connect(func(p, r): boom.append(p))
	await _frames(3)
	_check(barrel.hurtbox.health == float(Global.BREAKABLES["barrel"]["health"]), "thùng nổ đủ máu ban đầu")
	# bắn trúng thùng nổ
	var hit := {"damage": 25.0, "kind": "hitscan", "source": player, "direction": Vector3.FORWARD}
	barrel.hurtbox.take_hit(hit)
	await _frames(5)
	_check(boom.size() >= 1, "thùng nổ phát exploded")
	await _frames(10)
	_check(not is_instance_valid(barrel), "thùng nổ biến mất sau khi nổ")
	_check(boom.size() == 2, "nổ dây chuyền: thùng thứ hai cũng nổ (%d vụ nổ)" % boom.size())
	await _frames(10)
	_check(not is_instance_valid(crate), "thùng gỗ trong vùng nổ bị phá")
	_check(is_instance_valid(far_barrel), "thùng ở xa không bị nổ")
	# sát thương lên bot trong tầm nổ
	var bot = load("res://scripts/bot.gd").new()
	bot.setup("swordsman", 1)
	bot.position = Vector3(0, 0.1, -48)
	world.add_child(bot)
	var b3 = _prop("barrel", Vector3(0, 0, -50))
	await _frames(5)
	bot.hurtbox.setup(Global.TEAM_ENEMY, 1000.0, bot.parry)
	b3.hurtbox.take_hit(hit)
	await _frames(8)
	_check(bot.hurtbox.health < 1000.0, "bot gần thùng nổ bị sát thương (%.0f)" % (1000.0 - bot.hurtbox.health))
	# người chơi cũng bị
	await _new_player()
	player.global_position = Vector3(40, 0.1, 40)
	var b4 = _prop("barrel", Vector3(42, 0, 40))
	await _frames(5)
	var hp: float = player.hurtbox.health
	b4.hurtbox.take_hit(hit)
	await _frames(8)
	_check(player.hurtbox.health < hp, "người chơi đứng gần thùng nổ cũng bị thương (%.0f)" % (hp - player.hurtbox.health))
	# kiếm chém trúng thùng
	await _new_player()
	player.global_position = Vector3(-60, 0.1, 0)
	var b5 = _prop("crate", Vector3(-60, 0, -2.0))
	await _frames(3)
	player.combat.want_attack = true
	await _frames(1)
	player.combat.want_attack = false
	await _frames(60)
	_check(not is_instance_valid(b5) or b5.hurtbox.health < 10.0, "chém kiếm trúng thùng gỗ")

	print("[thùng gỗ + rơi đồ]")
	var brk: Array = []
	var cr = _prop("crate", Vector3(-80, 0, 0))
	cr.broken.connect(func(p, k): brk.append(k))
	await _frames(3)
	cr.hurtbox.take_hit({"damage": 50.0, "kind": "melee", "source": player, "direction": Vector3.FORWARD})
	await _frames(3)
	_check(brk == ["crate"], "thùng gỗ vỡ phát broken(crate), không nổ")

	print("[map có vật phá được]")
	var Maps = load("res://scripts/maps.gd")
	for id in Maps.IDS:
		var d: Dictionary = Maps.get_map(id)
		_check(d["barrels"].size() >= 2 and d["crates"].size() >= 2, "%s có thùng nổ và thùng gỗ" % id)
		var arena: Node3D = load("res://scripts/arena.gd").new()
		arena.map_id = id
		var ex: Array = []
		arena.explosion.connect(func(p, r): ex.append(p))
		root.add_child(arena)
		await _frames(3)
		_check(arena.props.size() == d["barrels"].size() + d["crates"].size(), "%s: arena dựng đủ vật phá được" % id)
		var near: float = 1e9
		for p in arena.props:
			for sp in arena.bot_spawns + [arena.spawn_point]:
				near = minf(near, Vector2(p.position.x - sp.x, p.position.z - sp.z).length())
		_check(near > 2.5, "%s: vật phá được không đè lên điểm xuất phát/sinh bot (gần nhất %.1f m)" % [id, near])
		for p in arena.props:
			if p.kind == "barrel":
				p.hurtbox.take_hit({"damage": 99.0, "kind": "hitscan", "source": null, "direction": Vector3.FORWARD})
				break
		await _frames(4)
		_check(ex.size() == 1, "%s: arena chuyển tiếp tín hiệu nổ" % id)
		arena.queue_free()
		await process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_fx.cfg"))
	print("----", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
