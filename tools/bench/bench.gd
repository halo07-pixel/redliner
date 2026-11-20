extends SceneTree
## Đo hiệu năng script khi chạy wave thật (headless: chỉ đo chi phí logic, không đo GPU).
## Chạy: godot --headless --path . -s tools/bench/bench.gd -- [wave_mục_tiêu=4] [map,map,...]
## In ra: thời gian process/physics trung bình & tệ nhất (ms), số node/bot/hạt lớn nhất,
## và số node còn thừa sau khi dọn wave. Chỉ tối ưu chỗ nào số đo chỉ ra là nặng.

var G


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	G.save_path = "user://bench.cfg"
	var args := OS.get_cmdline_user_args()
	var target: int = int(args[0]) if args.size() > 0 else 4
	var maps: Array = String(args[1]).split(",") if args.size() > 1 else G.MAP_IDS
	print("map | wave | frames | proc avg/max ms | phys avg/max ms | node max | bot max | node thừa")
	for m in maps:
		await _bench(String(m), target)
	quit(0)


func _bench(map_id: String, target: int) -> void:
	G.selected_map = map_id
	G.difficulty = "hard"
	var base: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(20)
	var pl = main.player
	pl.use_input = false
	pl.hurtbox.max_health = 1e9
	pl.hurtbox.health = 1e9
	main.waves.break_time = 0.5
	main.waves.start()
	var n: int = 0
	var p_sum: float = 0.0
	var p_max: float = 0.0
	var f_sum: float = 0.0
	var f_max: float = 0.0
	var f_at: int = 0
	var node_max: int = 0
	var bot_max: int = 0
	var frames: int = 0
	var t_wave: float = 0.0
	while main.waves.wave <= target and frames < 60 * 240:
		await physics_frame
		frames += 1
		t_wave += 1.0 / 60.0
		var pm: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var fm: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		n += 1
		p_sum += pm
		f_sum += fm
		p_max = maxf(p_max, pm)
		if fm > f_max:
			f_max = fm
			f_at = frames
		node_max = maxi(node_max, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		var bots: Array = get_nodes_in_group("bots")
		bot_max = maxi(bot_max, bots.size())
		if pl.global_position.y < main.arena.void_y + 2.0:
			pl.global_position = main.arena.spawn_point
		# giả lập người chơi hạ bot: mỗi 3 s hạ một con (ép tiến wave)
		if frames % 180 == 0:
			for b in bots:
				if not b.dead:
					b.hurtbox.take_hit({"damage": 9999.0, "kind": "x", "source": null, "direction": Vector3.ZERO})
					break
	var end_wave: int = main.waves.wave
	main.queue_free()
	await _frames(10)
	print("  (phys tệ nhất ở khung %d)" % f_at)
	var left: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - base
	print("%s | %d | %d | %.2f/%.2f | %.2f/%.2f | %d | %d | %d" % [
		map_id, end_wave, frames, p_sum / maxf(n, 1.0), p_max, f_sum / maxf(n, 1.0), f_max, node_max, bot_max, left])
