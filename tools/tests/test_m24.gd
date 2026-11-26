extends SceneTree
## M24: Titan - cỡ, vùng sát thương (thân/gáy/gối), quỵ, chết, giậm/quét báo trước, parry, móc lên thân, wave, navmesh.
##   timeout 280 godot --headless --path . -s tools/tests/test_m24.gd

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


func _clear() -> void:
	for n in get_nodes_in_group("bots"):
		n.queue_free()
	if world != null:
		world.queue_free()
	if player != null and is_instance_valid(player):
		player.queue_free()
	await process_frame
	world = Node3D.new()
	root.add_child(world)
	var f := StaticBody3D.new()
	f.collision_layer = Global.L_WORLD
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(400, 1, 400)
	c.shape = s
	f.add_child(c)
	f.position = Vector3(0, -0.5, 0)
	world.add_child(f)


func _player(pos: Vector3) -> void:
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = pos
	await _frames(3)


func _titan(pos: Vector3, wave: int = 1):
	var t = load("res://scripts/titan.gd").new()
	t.setup("titan", wave)
	t.position = pos
	world.add_child(t)
	return t


func _zone(t, zone: String) -> Area3D:
	for z in t._zones:
		if z.get_meta("zone") == zone:
			return z
	return null


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var T: Dictionary = root.get_node("Global").TITAN

	print("[cỡ + vùng]")
	await _clear()
	await _player(Vector3(0, 0.1, 60))
	var t = _titan(Vector3(0, 0.1, 0))
	await _frames(3)
	_check(float(T["body_height"]) >= 10.0, "Titan cao >= 10 m")
	_check(t.health == t.max_health and t.max_health >= 500.0, "máu lớn (%d)" % int(t.max_health))
	var h0: float = t.health
	_zone(t, "body").take_hit({"damage": 30.0, "kind": "melee", "source": player, "direction": Vector3.FORWARD, "on_parried": func(): pass})
	_check(absf((h0 - t.health) - 30.0 * float(T["body_mult"])) < 0.01, "đánh thân: chỉ trầy (%.1f)" % (h0 - t.health))
	var h1: float = t.health
	var weak: Array = []
	t.weak_point_hit.connect(func(z): weak.append(z))
	_zone(t, "nape").take_hit({"damage": 30.0, "kind": "melee", "source": player, "direction": Vector3.FORWARD, "on_parried": func(): pass})
	_check(absf((h1 - t.health) - 30.0 * float(T["nape_mult"])) < 0.01, "đánh gáy: sát thương nhân lớn (%.1f)" % (h1 - t.health))
	_check(weak == ["nape"], "phát weak_point_hit(nape)")
	var nape_y: float = _zone(t, "nape").position.y

	print("[quỵ khi đánh gối]")
	var knee: Area3D = null
	for k in t._knees:
		knee = k
	var need: int = int(ceil(float(T["knee_threshold"]) / 30.0))
	for i in need:
		knee.take_hit({"damage": 30.0, "kind": "melee", "source": player, "direction": Vector3.FORWARD, "on_parried": func(): pass})
	_check(t.state == t.S.KNEEL, "đánh gối đủ nhiều: Titan quỵ")
	_check(_zone(t, "nape").position.y < nape_y - 1.0, "quỵ: gáy hạ thấp xuống (y %.1f -> %.1f)" % [nape_y, _zone(t, "nape").position.y])
	await _frames(int(float(T["kneel_time"]) * 60.0) + 20)
	_check(t.state != t.S.KNEEL and is_equal_approx(t.mannequin.scale.y, float(T["scale"])), "hết thời gian quỵ: đứng dậy")

	print("[chết]")
	var died_info: Array = []
	t.died.connect(func(_b, info): died_info.append(info))
	var guard: int = 0
	while not t.dead and guard < 200:
		_zone(t, "nape").take_hit({"damage": 80.0, "kind": "hitscan", "source": player, "direction": Vector3.FORWARD})
		guard += 1
	_check(t.dead and died_info.size() == 1 and int(died_info[0]["score"]) >= 1000, "hết máu: chết, phát died với điểm >= 1000")
	_check(_zone(t, "nape").collision_layer == 0, "chết: tắt vùng nhận sát thương")

	print("[giậm]")
	await _clear()
	await _player(Vector3(0, 0.1, 10))
	t = _titan(Vector3(0, 0.1, 0))
	var landed: Array = []
	t.stomp_landed.connect(func(p, r): landed.append([p, r]))
	t._swipe_cd = 99.0
	t._stomp_cd = 0.0
	var hp0: float = player.hurtbox.health
	await _frames(5)
	_check(t.state == t.S.STOMP_WIND, "trong tầm: bắt đầu giậm (báo trước)")
	_check(t._marker != null and t._marker.visible, "vòng đỏ báo đòn hiện")
	await _frames(int(float(T["stomp_windup"]) * 60.0) + 10)
	_check(landed.size() == 1, "giậm xong phát stomp_landed")
	_check(player.hurtbox.health < hp0, "đứng yên trong vòng: trúng giậm (%.0f -> %.0f)" % [hp0, player.hurtbox.health])
	await _clear()
	await _player(Vector3(0, 0.1, 12))
	t = _titan(Vector3(0, 0.1, 0))
	t._swipe_cd = 99.0
	t._stomp_cd = 0.0
	hp0 = player.hurtbox.health
	await _frames(5)
	player.global_position = Vector3(40, 0.1, 12)   # chạy ra khỏi vòng trong lúc báo đòn
	await _frames(int(float(T["stomp_windup"]) * 60.0) + 10)
	_check(player.hurtbox.health == hp0, "chạy khỏi vòng: không trúng")

	print("[quét + parry]")
	await _clear()
	await _player(Vector3(0, 0.1, -9))   # Titan quay mặt -Z: người chơi ở trước mặt
	t = _titan(Vector3(0, 0.1, 0))
	t._stomp_cd = 99.0
	t._swipe_cd = 0.0
	t.rotation.y = 0.0
	hp0 = player.hurtbox.health
	await _frames(int(float(T["swipe_windup"]) * 60.0) + 40)
	_check(player.hurtbox.health < hp0, "đứng trước Titan: trúng quét (%.0f -> %.0f)" % [hp0, player.hurtbox.health])
	t._on_parried()
	_check(t.state == t.S.STAGGER, "bị parry: Titan choáng")

	print("[móc lên thân]")
	await _clear()
	await _player(Vector3(0, 1.0, 40))
	t = _titan(Vector3(0, 0.1, 0))
	t._stomp_cd = 99.0
	t._swipe_cd = 99.0
	await _frames(3)
	player.rotation.y = 0.0
	player.head.rotation.x = deg_to_rad(8.0)
	var hit: Dictionary = player._find_grapple_point()
	_check(not hit.is_empty() and hit["collider"] is Area3D and (hit["collider"].collision_layer & Global.L_TITAN) != 0, "tia grapple trúng bề mặt Titan")
	player.want_grapple = true
	await _frames(4)
	_check(player._grapple_node == t, "móc bám vào Titan")
	t.global_position += Vector3(5, 0, 0)
	await _frames(2)
	var anchor_local: Vector3 = t.to_local(player._grapple_point)
	_check(anchor_local.distance_to(player._grapple_local) < 0.5, "điểm móc đi theo thân khi Titan di chuyển")
	player.want_grapple = false
	await _frames(2)

	print("[wave + HUD]")
	var W: GDScript = load("res://scripts/wave_manager.gd")
	var w: Node = W.new()
	root.add_child(w)
	_check(not ("titan" in w.composition(5)), "mặc định (map thường): không có Titan")
	_check(w.composition(30).size() <= 10, "map thường giữ cơ cấu cũ")
	var hud = load("res://scripts/hud.gd").new()
	root.add_child(hud)
	await _frames(1)
	hud.set_boss(true, 0.5)
	_check(hud._boss_bar.visible and absf(hud._boss_bar.value - 0.5) < 0.01, "thanh máu Titan hiện")
	hud.set_boss(false, 0.0)
	_check(not hud._boss_bar.visible, "thanh máu ẩn khi hết Titan")

	print("[navmesh Titan trên Khu phố]")
	await _clear()
	var arena: Node3D = load("res://scripts/arena.gd").new()
	world.add_child(arena)
	await _frames(15)
	_check(arena.titans and arena.titan_nav_map.is_valid(), "Khu phố có navmesh Titan riêng")
	var np: PackedVector3Array = NavigationServer3D.map_get_path(arena.titan_nav_map, arena.spawn_point, Vector3(0, 0.1, 30), true)
	for i in 200:
		if np.size() > 0:
			break
		await _frames(1)
		np = NavigationServer3D.map_get_path(arena.titan_nav_map, arena.spawn_point, Vector3(0, 0.1, 30), true)
	_check(np.size() >= 2, "Titan tìm được đường từ điểm xuất phát tới quảng trường (%d điểm)" % np.size())
	await _player(arena.spawn_point)
	var wm = W.new()
	root.add_child(wm)
	wm.setup(arena, arena.bot_spawns, arena.spawn_band)
	var spawned: Array = []
	wm.bot_spawned.connect(func(b): spawned.append(b))
	wm._spawn("titan")
	await _frames(3)
	_check(spawned.size() == 1 and spawned[0].nav_map.is_valid(), "wave_manager sinh Titan với navmesh Titan")
	var d0: float = spawned[0].global_position.distance_to(player.global_position)
	await _frames(300)
	var d1: float = spawned[0].global_position.distance_to(player.global_position)
	_check(d1 < d0 - 5.0 and spawned[0].global_position.y > -2.0, "Titan tiến về phía người chơi (%.0f -> %.0f m)" % [d0, d1])
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
