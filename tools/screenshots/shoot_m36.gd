extends SceneTree
## Chụp M36: vòng độ lệch (lỗi súng lục) khi bắn dồn, và màn lên cấp có thẻ súng lục:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot_m36.gd -- docs/screenshots/m36

var out_dir: String = "docs/screenshots/m36"


func _initialize() -> void:
	_run()


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var G = root.get_node("Global")
	G.save_path = "user://shoot_m36.cfg"
	G.set_mode("endless")
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	for i in 15:
		await physics_frame
	main._start_mode()
	main.player.use_input = false
	var cb = main.player.combat
	cb.flaws._spread["pistol"] = 4.5   # như vừa bắn dồn ~8 phát liên tiếp
	cb._last_spread = -1.0
	cb._emit_flaw()
	await _shot("spread_ring")
	main.progress.pools = ["gun:pistol"]
	main.progress.add_xp(10)
	for i in 5:
		await physics_frame
	await _shot("level_up_pistol")
	quit()
