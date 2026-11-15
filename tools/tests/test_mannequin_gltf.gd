extends SceneTree
## Test headless M7.6: nhân vật glTF (KayKit) — kích thước, vũ khí, hoạt ảnh, nháy/mờ, fallback.
##   timeout 120 godot --headless --path . -s tools/tests/test_mannequin_gltf.gd

var failures: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _make(kind: String) -> Node3D:
	var m: Node3D = load("res://scripts/mannequin_gltf.gd").new()
	m.kind = kind
	root.add_child(m)
	return m


func _visible_weapons(m: Node3D) -> Array:
	var out: Array = []
	var sk: Skeleton3D = m.model.find_children("*", "Skeleton3D", true, false)[0]
	for c in sk.get_children():
		if c is BoneAttachment3D and c.name == &"handslot_r":
			for w in c.get_children():
				if (w as Node3D).visible:
					out.append(String(w.name))
	return out


func _run() -> void:
	await process_frame
	var G = load("res://scripts/mannequin_gltf.gd")
	_check(G.has_asset("swordsman") and G.has_asset("elite") and G.has_asset("gunner"), "có asset cho 3 loại bot")
	_check(not G.has_asset("dummy"), "dummy không có asset (dùng hình nhân khối)")

	var expect: Dictionary = {"swordsman": "1H_Sword", "elite": "1H_Axe", "gunner": "1H_Crossbow"}
	for k in expect:
		var m: Node3D = _make(k)
		await process_frame
		_check(_visible_weapons(m) == [expect[k]], "%s chỉ cầm %s" % [k, expect[k]])
		_check(m.weapon != null and m.weapon.visible, "%s: weapon được gán" % k)
		var top: float = -1e9
		for mi in m.model.find_children("*", "MeshInstance3D", true, false):
			if mi.get_parent() is Skeleton3D and mi.visible:
				var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
				top = maxf(top, a.end.y)
		_check(absf(top - 1.8) < 0.15, "%s cao ~1.8m (%.2f)" % [k, top])
		_check(m.player.get_animation("Idle").loop_mode == Animation.LOOP_LINEAR, "%s: Idle lặp" % k)
		m.queue_free()

	var m: Node3D = _make("swordsman")
	await process_frame
	m.animate(0.016, 0.0, true, 0.0)
	_check(m.player.current_animation == "Idle", "đứng yên -> Idle")
	m.animate(0.016, 6.0, true, 0.0)
	_check(m.player.current_animation == "Running_A", "chạy -> Running_A")
	m.animate(0.016, 6.0, false, -3.0)
	_check(m.player.current_animation == "Jump_Idle", "trên không -> Jump_Idle")

	m.play("swing", 0.5)
	_check(m.player.current_animation == "1H_Melee_Attack_Slice_Diagonal", "swing -> clip chém")
	_check(is_equal_approx(m.player.get_playing_speed(), 2.0), "swing 0.5s -> tốc độ x2")
	m.animate(0.3, 6.0, true, 0.0)
	_check(m.player.current_animation == "1H_Melee_Attack_Slice_Diagonal", "đang overlay: không bị locomotion ghi đè")
	m.animate(0.3, 6.0, true, 0.0)
	_check(m.player.current_animation == "Running_A", "hết overlay -> quay lại chạy")

	m.play("hurt", 0.3)
	_check(m.player.current_animation == "Hit_A", "hurt -> Hit_A")
	m.play("die", 0.45)
	m.animate(1.0, 0.0, true, 0.0)
	_check(m.player.current_animation == "Death_A", "chết: giữ clip chết")
	m.play("swing", 0.5)
	_check(m.player.current_animation == "Death_A", "đã chết: bỏ qua overlay mới")
	m.clear_overlay()
	_check(m.player.current_animation == "Idle", "clear_overlay -> hồi sinh về Idle")

	# nháy và mờ
	m.flash()
	var mat: StandardMaterial3D = m._mats[0]
	_check(mat.emission_energy_multiplier > 0.5, "flash bật phát sáng")
	var other: Node3D = _make("swordsman")
	await process_frame
	_check(other._mats[0].emission_energy_multiplier == 0.0, "flash không lan sang nhân vật khác")
	m.fade_out(0.1)
	await create_timer(0.3).timeout
	_check(mat.albedo_color.a < 0.05, "fade_out làm mờ hẳn")

	m.set_render_layers(2)
	var all2: bool = true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		all2 = all2 and (mi as MeshInstance3D).layers == 2
	_check(all2, "set_render_layers áp cho mọi mesh")

	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
