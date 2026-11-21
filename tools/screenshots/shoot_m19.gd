extends SceneTree
## Chụp CHUỖI khung của từng hoạt ảnh viewmodel M19 (chém, đỡ, parry hụt, nạp đạn, đổi trạng thái) theo thời gian giả lập cố định:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot_m19.gd -- docs/screenshots/m19
## Mỗi chuỗi lưu <tên>_<mốc ms>.png; ghép thành tấm contact sheet bằng tools/screenshots/contact_sheet.py (nếu có PIL).

const DT: float = 1.0 / 60.0
var out_dir: String = "docs/screenshots/m19"


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])


## Chạy clip: `marks` là các mốc thời gian (giây); tại mỗi mốc chụp một ảnh. update() cố định 1/60 s nên lặp lại được.
func _sequence(vm: Node3D, seq_name: String, marks: Array, speed: float = 0.0, st: String = "") -> void:
	var t: float = 0.0
	for m in marks:
		while t < float(m) - 0.0001:
			vm.update(DT, speed, true, st)
			t += DT
		await _shot("%s_%03d" % [seq_name, int(round(float(m) * 1000.0))])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(5)
	var player = main.player
	player.use_input = false
	player.global_position = Vector3(0.0, 0.1, 8.0)
	await _frames(10)
	player.set_process(false)
	var vm: Node3D = player.viewmodel
	vm.set_process(false)
	vm.reset()
	for i in 90:
		vm.update(DT, 0.0, true)
	vm.play_swing(0.12, 0.1, 0.28)
	await _sequence(vm, "chem", [0.0, 0.05, 0.1, 0.12, 0.17, 0.22, 0.27, 0.35, 0.5])
	for i in 120:
		vm.update(DT, 0.0, true)
	vm.raise()
	await _sequence(vm, "do", [0.0, 0.03, 0.06, 0.15, 0.3, 0.5])
	for i in 120:
		vm.update(DT, 0.0, true)
	vm.parry_fail()
	await _sequence(vm, "parry_hut", [0.0, 0.04, 0.08, 0.15, 0.25, 0.4, 0.6])
	for i in 120:
		vm.update(DT, 0.0, true)
	vm.set_reloading(true)
	await _sequence(vm, "nap", [0.0, 0.1, 0.25, 0.5, 0.9, 1.3, 1.6])
	vm.set_reloading(false)
	for i in 120:
		vm.update(DT, 0.0, true)
	await _sequence(vm, "luot", [0.0, 0.05, 0.1, 0.2, 0.4], 12.0, "slide")
	vm.reset()
	await _sequence(vm, "grapple", [0.0, 0.05, 0.1, 0.2, 0.4], 14.0, "grapple")
	print("saved sequences in ", out_dir)
	quit()
