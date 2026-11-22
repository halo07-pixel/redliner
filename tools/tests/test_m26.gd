extends SceneTree
## M26: chuyển động mượt và đồng nhất - lò xo tắt dần, gia tốc người chơi/bot, camera, nhả móc, nghiêng theo gia tốc, bước chân Titan.
##   timeout 200 godot --headless --path . -s tools/tests/test_m26.gd

var failures: int = 0
var world: Node3D
var player
const Motion = preload("res://scripts/motion.gd")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _fresh_player(pos: Vector3 = Vector3(0, 0.1, 0)) -> void:
	if player != null and is_instance_valid(player):
		player.queue_free()
	await process_frame
	player = load("res://scenes/player.tscn").instantiate()
	player.use_input = false
	root.add_child(player)
	player.global_position = pos
	await _frames(4)
	player.velocity = Vector3.ZERO


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var G: Node = root.get_node("Global")
	world = Node3D.new()
	root.add_child(world)
	var fl := StaticBody3D.new()
	fl.collision_layer = G.L_WORLD
	var fc := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(600, 1, 600)
	fc.shape = fs
	fl.add_child(fc)
	fl.position = Vector3(0, -0.5, 0)
	world.add_child(fl)

	print("[lò xo tắt dần tới hạn]")
	var x: float = 0.0
	var v: float = 0.0
	var vmax_first: float = 0.0
	for i in 60:
		var r: Vector2 = Motion.damp(x, 1.0, v, 0.2, 1.0 / 60.0)
		x = r.x
		v = r.y
		if i == 0:
			vmax_first = v
	_check(absf(x - 1.0) < 0.02 and x <= 1.001, "tới đích (smooth_time 0.2) không vượt quá (x=%.3f)" % x)
	_check(vmax_first < 2.0, "khung đầu: vận tốc nhỏ, bắt đầu êm (%.3f) thay vì nhảy" % vmax_first)
	var lerp_first: float = 1.0 * minf(1.0, 6.0 / 60.0) * 60.0   # vận tốc khung đầu của lerp mũ cũ
	_check(vmax_first < lerp_first * 0.5, "êm hơn lerp mũ cũ khung đầu (%.2f so với %.2f /s)" % [vmax_first, lerp_first])
	var samples := PackedFloat32Array([0.0, 0.0, 0.0, 5.0, 5.0])
	_check(Motion.pops(samples, 1.0) >= 1, "pops() phát hiện cú giật")

	print("[gia tốc người chơi]")
	await _fresh_player()
	G.apply_motion_preset("smooth")
	player.move_input = Vector2(0, -1)
	var t90: float = -1.0
	for i in 90:
		await _frames(1)
		if t90 < 0.0 and player.horizontal_speed() >= 0.9 * float(G.PLAYER["walk_speed"]):
			t90 = float(i + 1) / 60.0
	_check(t90 > 0.12 and t90 < 0.4, "smooth: đạt 90%% tốc độ sau %.2f s (0.12..0.4)" % t90)
	player.move_input = Vector2.ZERO
	var stop_t: float = -1.0
	for i in 90:
		await _frames(1)
		if stop_t < 0.0 and player.horizontal_speed() < 0.5:
			stop_t = float(i + 1) / 60.0
	_check(stop_t > 0.15 and stop_t < 0.8, "smooth: dừng sau %.2f s (êm, không ngắt)" % stop_t)
	await _fresh_player()
	G.apply_motion_preset("fast")
	player.move_input = Vector2(0, -1)
	var t90f: float = -1.0
	for i in 60:
		await _frames(1)
		if t90f < 0.0 and player.horizontal_speed() >= 0.9 * float(G.PLAYER["walk_speed"]):
			t90f = float(i + 1) / 60.0
	_check(t90f > 0.0 and t90f < t90, "fast: nhanh hơn smooth (%.2f s < %.2f s)" % [t90f, t90])
	G.apply_motion_preset("smooth")

	print("[nhất quán người chơi / bot]")
	var player_a: float = float(G.PLAYER["ground_accel"])
	var bot_a: float = float(G.BOT_MOVE["accel"])
	_check(absf(player_a - bot_a) / player_a < 0.25, "gia tốc bot (%.0f) cùng cỡ người chơi (%.0f)" % [bot_a, player_a])

	print("[camera mượt]")
	await _fresh_player()
	player.move_input = Vector2(1, 0)
	var rolls := PackedFloat32Array()
	var fovs := PackedFloat32Array()
	for i in 120:
		await _frames(1)
		await process_frame
		rolls.append(player.head.rotation.z)
		fovs.append(player.camera.fov)
	_check(Motion.pops(rolls, 0.0035) == 0, "độ nghiêng camera khi chạy ngang: không có cú giật (%d)" % Motion.pops(rolls, 0.0035))
	player.move_input = Vector2.ZERO

	print("[nhả móc liền mạch]")
	await _fresh_player(Vector3(0, 1.0, 0))
	player.velocity = Vector3(0, 0, -25)
	player.head.rotation.x = deg_to_rad(20.0)
	player._grapple_taut = false
	var v_before: Vector3 = player.velocity
	player._release_redirect()
	var first_jump: float = player.velocity.distance_to(v_before)
	_check(first_jump < 1.0, "nhả móc: khung đầu không đổi vận tốc tức thì (%.2f m/s)" % first_jump)
	var v_target: Vector3 = player._redirect_target
	var max_step: float = 0.0
	var prev: Vector3 = player.velocity
	for i in 15:
		await _frames(1)
		max_step = maxf(max_step, player.velocity.distance_to(prev))
		prev = player.velocity
	_check(player._redirect_left <= 0.0 and player.velocity.distance_to(v_target) < 6.0, "sau 0.15 s: vận tốc đã về hướng mới (cách đích %.1f)" % player.velocity.distance_to(v_target))
	_check(max_step < 2.0, "mỗi khung đổi vận tốc nhẹ (tối đa %.2f m/s)" % max_step)
	G.set_live("p", "grapple_redirect_time", 0.0)
	await _fresh_player(Vector3(0, 1.0, 0))
	player.velocity = Vector3(0, 0, -25)
	player.head.rotation.x = deg_to_rad(20.0)
	var vb2: Vector3 = player.velocity
	player._release_redirect()
	_check(player.velocity.distance_to(vb2) > 1.0, "redirect_time = 0 (preset fast): đổi tức thì như cũ")
	G.apply_motion_preset("smooth")

	print("[nghiêng theo gia tốc]")
	var RigA: GDScript = load("res://scripts/rig_animator.gd")
	var mq = load("res://scripts/mannequin.gd").new()
	mq.kind = "swordsman"
	root.add_child(mq)
	await process_frame
	var spine_rest: float = 0.0
	for i in 30:
		mq.animate(1.0 / 60.0, 0.0, true, 0.0)
	spine_rest = (mq.get_joint("spine") as Node3D).rotation_degrees.x
	for i in 20:
		mq.animate(1.0 / 60.0, minf(float(i) * 0.6, 11.0), true, 0.0)   # tăng tốc ~36 m/s²
	var spine_acc: float = (mq.get_joint("spine") as Node3D).rotation_degrees.x
	_check(spine_acc < spine_rest - 1.0, "tăng tốc: thân cúi về trước (%.1f -> %.1f độ)" % [spine_rest, spine_acc])
	G.set_live("m", "accel_lean", 0.0)
	var mq2 = load("res://scripts/mannequin.gd").new()
	mq2.kind = "swordsman"
	root.add_child(mq2)
	await process_frame
	for i in 30:
		mq2.animate(1.0 / 60.0, 0.0, true, 0.0)
	for i in 20:
		mq2.animate(1.0 / 60.0, minf(float(i) * 0.6, 11.0), true, 0.0)
	var spine_off: float = (mq2.get_joint("spine") as Node3D).rotation_degrees.x
	_check(spine_off > spine_acc + 0.5, "accel_lean = 0: không cúi thêm (%.1f so với %.1f)" % [spine_off, spine_acc])
	G.apply_motion_preset("smooth")

	print("[bước chân Titan khớp hoạt ảnh]")
	var T: Dictionary = G.TITAN
	var anim_speed: float = 4.0 / float(T["scale"]) * float(T["anim_speed_mult"])
	var interval: float = PI / (anim_speed * float(G.ANIM["stride_rate"]))
	_check(interval > 0.6 and interval < 1.8, "một bước Titan %.2f s (nặng nhưng không lê thê)" % interval)
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d TEST FAIL" % failures)
	quit(1 if failures > 0 else 0)
