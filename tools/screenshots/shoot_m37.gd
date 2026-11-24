extends SceneTree
## Chụp M37: Cửa hàng + nút súng khởi đầu:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot_m37.gd -- docs/screenshots/m37

var out_dir: String = "docs/screenshots/m37"


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
	G.save_path = "user://shoot_m37.cfg"
	G.gold = 320
	G.owned_guns = ["pistol", "shotgun"]
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	for i in 5:
		await process_frame
	menu.shop_button.pressed.emit()
	await _shot("shop")
	menu.shop_panel.visible = false
	await _shot("menu")
	G.set_mode("endless")
	menu._refresh_setup()
	menu.setup_panel.visible = true
	await _shot("menu_setup")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.save_path))
	quit()
