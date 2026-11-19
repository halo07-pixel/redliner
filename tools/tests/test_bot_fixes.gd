extends SceneTree
## Test headless: sửa lỗi bot (spawn đè nhau bị văng, rơi/ngoài biên, leo bậc thấp, vật cản thấp, nguồn sát thương đã bị giải phóng).
##   timeout 300 godot --headless --path . -s tools/tests/test_bot_fixes.gd

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


func _drive(b, vel: Vector3, frames: int) -> void:
	for i in frames:
		await physics_frame
		var vy: float = -1.0 if b.is_on_floor() else b.velocity.y - 24.0 / 60.0
		b.velocity = Vector3(vel.x, vy, vel.z)
		b._try_step_up()
		b.move_and_slide()


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://test_botfix.cfg"
	G.load_save()

	print("[sinh bot không đè nhau]")
	await _clear_world()
	_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))
	await _player(Vector3(0, 0.1, 30))
	var WM = load("res://scripts/wave_manager.gd").new()
	root.add_child(WM)
	var one_spot: Array = [Vector3(0, 0.1, -20)]
	WM.setup(world, one_spot)
	WM.wave = 8
	var made: Array = []
	var at_spawn: Array = []
	WM.bot_spawned.connect(func(b):
		made.append(b)
		at_spawn.append(b.global_position))
	WM._next_wave()
	await _frames(30)
	_check(made.size() == 10, "wave 8 sinh đủ 10 bot (%d)" % made.size())
	var min_gap: float = 1e9
	var max_y: float = 0.0
	for i in made.size():
		max_y = maxf(max_y, made[i].global_position.y)
		for j in range(i + 1, made.size()):
			var a: Vector3 = at_spawn[i]
			var c: Vector3 = at_spawn[j]
			min_gap = minf(min_gap, Vector2(a.x - c.x, a.z - c.z).length())
	_check(min_gap >= 1.25, "10 bot cùng một điểm sinh được xếp cách nhau >= 1.25 m lúc sinh (gần nhất %.2f)" % min_gap)
	_check(max_y < 0.5, "không bot nào bị đẩy văng lên cao (y lớn nhất %.2f)" % max_y)
	for b in made:
		b.queue_free()
	await _frames(2)

	print("[điểm sinh sát tường]")
	await _clear_world()
	_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))
	_box(Vector3(4, 4, 4), Vector3(0, 2, -20)) # khối đặc ngay điểm sinh
	var WM2 = load("res://scripts/wave_manager.gd").new()
	root.add_child(WM2)
	WM2.setup(world, [Vector3(0, 0.1, -20)])
	var spot: Vector3 = WM2._free_spot(Vector3(0, 0.1, -20))
	_check(absf(spot.x) >= 2.3 or absf(spot.z + 20.0) >= 2.3, "điểm sinh nằm trong khối đặc được dời ra ngoài (%s)" % spot)
	WM2.queue_free()

	print("[rơi / ngoài biên được đưa về]")
	await _clear_world()
	_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.bake_nav = false
	root.add_child(arena)
	await _frames(3)
	await _player(arena.spawn_point)
	var WM3 = load("res://scripts/wave_manager.gd").new()
	root.add_child(WM3)
	WM3.setup(arena, arena.bot_spawns)
	var relocated: Array = []
	WM3.bot_relocated.connect(func(b): relocated.append(b))
	var rb = load("res://scripts/bot.gd").new()
	rb.setup("swordsman", 1)
	rb.position = arena.bot_spawns[0]
	arena.add_child(rb)
	await _frames(5)
	rb.global_position = Vector3(0, arena.void_y - 10.0, 0)
	await _frames(3)
	_check(relocated.size() == 1, "bot rơi dưới void_y được đưa về (signal bot_relocated)")
	_check(rb.global_position.y > arena.void_y and absf(rb.global_position.x) < arena.half.x and absf(rb.global_position.z) < arena.half.y, "vị trí mới nằm trong map (%s)" % rb.global_position)
	rb.global_position = Vector3(arena.half.x + 6.0, 0.1, 0.0)
	await _frames(3)
	_check(relocated.size() == 2 and absf(rb.global_position.x) < arena.half.x, "bot văng ra ngoài biên được đưa về")
	var dead_bot = load("res://scripts/bot.gd").new()
	dead_bot.setup("swordsman", 1)
	dead_bot.position = Vector3(0, 0.1, 0)
	arena.add_child(dead_bot)
	await _frames(3)
	dead_bot.dead = true
	dead_bot.global_position = Vector3(0, arena.void_y - 10.0, 0)
	await _frames(3)
	_check(relocated.size() == 2, "bot đã chết không bị kéo về")
	rb.queue_free()
	dead_bot.queue_free()
	WM3.queue_free()
	arena.queue_free()
	await _frames(2)

	print("[leo bậc thấp]")
	for h in [0.4, 0.7]:
		await _clear_world()
		_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))
		_box(Vector3(40, h, 1.0), Vector3(0, h * 0.5, -5.0)) # bậc rộng, không đi vòng được
		await _player(Vector3(0, 0.1, 30))
		var sb = _bot("swordsman", Vector3(0, 0.05, 0))
		sb.set_physics_process(false)
		await _frames(5)
		await _drive(sb, Vector3(0, 0, -6), 90)
		_check(sb.global_position.z < -7.0, "bậc cao %.1f m: bot leo qua (z=%.2f)" % [h, sb.global_position.z])
		_check(absf(sb.global_position.y) < 0.3, "qua bậc xong đứng lại trên sàn (y=%.2f)" % sb.global_position.y)
	await _clear_world()
	_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))
	_box(Vector3(40, 1.4, 1.0), Vector3(0, 0.7, -5.0)) # tường cao
	await _player(Vector3(0, 0.1, 30))
	var wb = _bot("swordsman", Vector3(0, 0.05, 0))
	wb.set_physics_process(false)
	await _frames(5)
	await _drive(wb, Vector3(0, 0, -6), 90)
	_check(wb.global_position.z > -4.6, "tường cao 1.4 m: bot không leo (z=%.2f)" % wb.global_position.z)
	await _clear_world()
	_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))
	await _player(Vector3(0, 0.1, 30))
	var low = _bot("swordsman", Vector3(0, 0.05, 0))
	var front = _bot("swordsman", Vector3(0, 0.05, -1.0))
	low.set_physics_process(false)
	front.set_physics_process(false)
	await _frames(5)
	await _drive(low, Vector3(0, 0, -6), 40)
	_check(low.global_position.y < 0.3, "không leo lên đầu bot khác (y=%.2f)" % low.global_position.y)

	print("[vật cản thấp (thùng)]")
	for crate_top in [0.5, 0.7]:
		await _clear_world()
		_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))
		var crate := _box(Vector3(6, crate_top + 0.5, 1.0), Vector3(0, (crate_top - 0.5) * 0.5, -6.0)) # cao crate_top trên sàn
		await _player(Vector3(0, 0.1, -20))
		var cb = _bot("swordsman", Vector3(0, 0.05, 0))
		var closest: float = await _min_dist_run(cb, 60 * 12, 2.5)
		_check(closest <= 2.5, "thùng thấp %.1f m chắn đường: bot vẫn tới sát người chơi (%.1f m)" % [crate_top, closest])

	print("[kẹt thì ép đi navmesh]")
	await _clear_world()
	_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))
	_box(Vector3(1, 6, 14), Vector3(-7, 3, 0))
	_box(Vector3(1, 6, 14), Vector3(7, 3, 0))
	_box(Vector3(14, 6, 1), Vector3(0, 3, 6))
	await _bake()
	await _player(Vector3(0, 0.1, 16))
	var ub = _bot("swordsman", Vector3(0, 0.1, 0))
	ub.melee.windup_override = 99.0
	var best: float = await _min_dist_run(ub, 60 * 25, 3.0)
	_check(best <= 3.0, "bot trong chữ U (không dùng ray) vẫn đi vòng ra tới người chơi (%.1f m)" % best)

	print("[nguồn sát thương đã bị giải phóng]")
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(5)
	main.player.use_input = false
	var ghost := Node3D.new()
	root.add_child(ghost)
	ghost.free() # nguồn đã bị giải phóng ngay (như bot chết rồi mà đạn mới trúng)
	var hp0: float = main.player.hurtbox.health
	main.player.hurtbox.take_hit({"damage": 5.0, "kind": "bullet", "source": ghost, "direction": Vector3.FORWARD})
	await _frames(2)
	_check(main.player.hurtbox.health < hp0, "nhận đạn từ nguồn đã giải phóng: vẫn trừ máu, không lỗi")
	main.queue_free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_botfix.cfg"))
	print("----", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
