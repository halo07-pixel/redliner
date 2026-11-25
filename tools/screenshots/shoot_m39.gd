extends SceneTree
## Chụp M39: màn chọn thẻ với kho thẻ kiếm:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot_m39.gd -- docs/screenshots/m39

var out_dir: String = "docs/screenshots/m39"


func _initialize() -> void:
	_run()


func _shot(n: String) -> void:
	for i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var Up = load("res://scripts/upgrades.gd")
	var ui = load("res://scripts/level_up_ui.gd").new()
	root.add_child(ui)
	await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for gun in ["sword"]:
		var cards: Array = []
		var pool: Dictionary = Global.UPGRADES[gun]
		var ids: Array = pool.keys()
		for i in 3:
			var c: Dictionary = (pool[ids[i]] as Dictionary).duplicate()
			c["id"] = ids[i]
			c["pool"] = gun
			c["tier"] = 1
			cards.append(c)
		ui.open(5, cards)
		await _shot("cards_" + gun)
	quit()
