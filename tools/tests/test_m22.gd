extends SceneTree
## M22: cảm giác grapple - tầm 90 m, hỗ trợ ngắm, đu con lắc, bám khi tới gần, bắn ra khi nhả lúc dây căng.
##   timeout 180 godot --headless --path . -s tools/tests/test_m22.gd

var failures: int = 0
var player
var world: Node3D


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _box(size: Vector3, pos: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = Global.L_WORLD
	b.position = pos
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	world.add_child(b)


func _reset(pos: Vector3) -> void:
	player.queue_free()
	await process_frame
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = pos
	await _frames(3)
	player.velocity = Vector3.ZERO


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(400, 1, 400), Vector3(0, -0.5, 0))
	_box(Vector3(30, 20, 1), Vector3(0, 10, 85))       # tường xa 85 m phía sau
	_box(Vector3(2, 20, 2), Vector3(0, 10, -30))       # cột mảnh 2 m
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = Vector3(0, 1.0, 0)
	await _frames(3)
	var P: Dictionary = Global.PLAYER

	print("[tầm + hỗ trợ ngắm]")
	_check(float(P["grapple_range"]) >= 90.0, "tầm móc >= 90 m")
	await _reset(Vector3(10, 1.0, 40))   # nhìn -z: cột ở x=0 lệch phải 10 m ở 70 m? -> tường xa 125 m ngoài tầm
	var h: Dictionary = player._find_grapple_point()
	_check(h.is_empty() or (h["position"] as Vector3).z > -90.0, "ra ngoài tầm: không có điểm (hoặc điểm trong tầm)")
	await _reset(Vector3(0, 1.0, 0))
	player.rotation.y = deg_to_rad(-3.0)   # lệch ~3° khỏi cột (cột rộng 1 m ở 30 m ~ +-1.9°)
	var hit: Dictionary = player._find_grapple_point()
	_check(not hit.is_empty() and absf((hit["position"] as Vector3).z + 29.0) < 1.5, "lệch tâm 3°: hỗ trợ ngắm bắt được cột")
	player.rotation.y = deg_to_rad(-12.0)
	_check(player._find_grapple_point().is_empty() or (player._find_grapple_point()["position"] as Vector3).z < -60.0, "lệch 12°: không bắt cột (ngoài nón)")
	player.rotation.y = 0.0

	print("[tín hiệu chấm báo]")
	var seen: Array = []
	player.grapple_target_changed.connect(func(v): seen.append(v))
	player.rotation.y = -PI * 0.5
	await _frames(15)
	_check(seen == [false], "quay đi: phát grapple_target_changed(false) (%s)" % [seen])
	player.rotation.y = 0.0
	await _frames(15)
	_check(seen == [false, true], "nhìn lại cột: phát true (%s)" % [seen])

	print("[đu con lắc]")
	await _reset(Vector3(0, 12.0, 0))
	player.head.rotation.x = deg_to_rad(5.0)
	player.want_grapple = true
	await _frames(2)
	var anchor: Vector3 = player._grapple_point
	var len0: float = player.head.global_position.distance_to(anchor)
	player.velocity = Vector3(12.0, 0.0, 0.0)   # lao ngang, ra xa đường dây
	var max_over: float = 0.0
	for i in 60:
		await _frames(1)
		var d: float = player.head.global_position.distance_to(anchor)
		max_over = maxf(max_over, d - len0)
	_check(max_over < 3.0, "dây căng: không bị văng xa hơn độ dài dây quá nhiều (vượt %.2f m)" % max_over)
	player.want_grapple = false

	print("[nhả lúc căng bắn ra thêm]")
	await _reset(Vector3(0, 12.0, 0))
	player.want_grapple = true
	await _frames(25)
	var taut: bool = player._grapple_taut
	player.velocity = player.velocity.normalized() * 20.0
	player._grapple_taut = true
	var look: Vector3 = -player.head.global_transform.basis.z
	player.want_grapple = false
	await _frames(1)
	_check(player.velocity.length() >= 20.0 + float(P["grapple_release_snap"]) - 1.0, "nhả khi căng: tốc độ tăng thêm snap (%.1f m/s)" % player.velocity.length())

	print("[giữ lâu được]")
	_check(float(P["grapple_max_time"]) >= 5.0, "thời gian bám tối đa >= 5 s")
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
