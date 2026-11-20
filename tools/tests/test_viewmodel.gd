extends SceneTree
## Test headless M7.4: tay + vũ khí góc nhìn thứ nhất (nhún, lắc chuột, trạng thái, giật súng, nạp đạn, kiếm).
##   timeout 120 godot --headless --path . -s tools/tests/test_viewmodel.gd

var failures: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _fresh() -> Node3D:
	var v: Node3D = load("res://scripts/viewmodel.gd").new()
	root.add_child(v)
	return v


func _bob_range(v: Node3D, speed: float) -> float:
	var lo: float = 1e9
	var hi: float = -1e9
	for i in 240:
		v.update(1.0 / 60.0, speed, true)
		lo = minf(lo, v.bob_offset.y)
		hi = maxf(hi, v.bob_offset.y)
	return hi - lo


func _run() -> void:
	await process_frame
	var V: Dictionary = Global.VIEWMODEL
	var v: Node3D = _fresh()
	await process_frame
	_check(v.sword_pivot != null and v.gun_pivot != null and v.muzzle_flash != null, "có kiếm, súng, chớp nòng")
	_check(v.sword_pivot.position.is_equal_approx(V["sword_pos"]) and v.gun_pivot.position.is_equal_approx(V["gun_pos"]), "vũ khí đúng vị trí tay")
	_check(v.sword_pivot.get_child_count() >= 3 and v.gun_pivot.get_child_count() >= 4, "mỗi vũ khí có bàn tay và cánh tay đi kèm")
	var all_off: bool = true
	for mi in v.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			all_off = false
	_check(all_off, "viewmodel không đổ bóng (thân người chơi đã có bóng)")
	_check(not v.muzzle_flash.visible, "chớp nòng tắt lúc đầu")

	# Nhún theo tốc độ
	var slow: float = _bob_range(_fresh(), 2.0)
	var fast: float = _bob_range(_fresh(), 10.0)
	var still: float = _bob_range(_fresh(), 0.0)
	_check(fast > slow * 2.0 and slow > still, "nhún tăng theo tốc độ (đứng %.4f, chậm %.4f, nhanh %.4f)" % [still, slow, fast])
	var air: Node3D = _fresh()
	var air_max: float = 0.0
	for i in 60:
		air.update(1.0 / 60.0, 10.0, false)
		air_max = maxf(air_max, absf(air.bob_offset.y))
	_check(air_max < 0.0001, "trên không không nhún")

	# Lắc theo chuột: lò xo hất lệch rồi kéo về có nảy nhẹ
	var s: Node3D = _fresh()
	s.update(1.0 / 60.0, 0.0, true)
	s.add_look(Vector2(200.0, 0.0))
	var peak: float = 0.0
	var crossed: bool = false
	for i in 90:
		s.update(1.0 / 60.0, 0.0, true)
		peak = maxf(peak, s.rotation_degrees.y)
		if peak > 1.0 and s.rotation_degrees.y < -0.05:
			crossed = true
	_check(peak > 1.0 and peak <= float(V["sway_max"]) + 0.5, "xoay chuột nhanh -> vũ khí lệch, có giới hạn (đỉnh %.2f độ)" % peak)
	_check(crossed, "lò xo hồi về có nảy nhẹ qua vị trí nghỉ")
	for i in 240:
		s.update(1.0 / 60.0, 0.0, true)
	_check(absf(s.rotation_degrees.y) < 0.1, "lắc hồi về 0")
	var big: Node3D = _fresh()
	big.update(1.0 / 60.0, 0.0, true)
	big.add_look(Vector2(5000.0, 5000.0))
	var bmax: float = 0.0
	for i in 60:
		big.update(1.0 / 60.0, 0.0, true)
		bmax = maxf(bmax, maxf(absf(big.rotation_degrees.x), absf(big.rotation_degrees.y)))
	_check(bmax <= float(V["sway_max"]) + 0.01, "xoay cực mạnh vẫn bị chặn ở sway_max")
	var slowf: Node3D = _fresh()
	slowf.update(1.0 / 60.0, 0.0, true)
	slowf.add_look(Vector2(200.0, 0.0))
	slowf.update(0.5, 0.0, true) # frame rất chậm: lò xo vẫn ổn định
	_check(is_finite(slowf.rotation_degrees.y) and absf(slowf.rotation_degrees.y) <= float(V["sway_max"]) + 0.01, "frame chậm 0.5s: lò xo không nổ")

	# Trạng thái
	var st: Node3D = _fresh()
	for i in 60:
		st.update(1.0 / 60.0, 8.0, true, "slide")
	_check(st.position.y < -0.05 and absf(st.rotation_degrees.z) > 8.0, "trượt: hạ và nghiêng vũ khí")
	var gr: Node3D = _fresh()
	for i in 60:
		gr.update(1.0 / 60.0, 8.0, false, "grapple")
	_check(gr.gun_pivot.position.y > float(V["gun_pos"].y) + 0.15, "đu móc: tay trái giơ lên")
	for i in 60:
		gr.update(1.0 / 60.0, 0.0, true, "")
	_check(gr.gun_pivot.position.is_equal_approx(V["gun_pos"]) or gr.gun_pivot.position.distance_to(V["gun_pos"]) < 0.01, "hết đu móc: tay trái về chỗ cũ")

	# Tiếp đất: xung xuống, nảy lại
	var ld: Node3D = _fresh()
	ld.update(1.0 / 60.0, 0.0, false)
	ld.update(1.0 / 60.0, 0.0, true)
	var lo: float = 0.0
	var hi_after: float = -1.0
	for i in 60:
		ld.update(1.0 / 60.0, 0.0, true)
		if ld.position.y < lo:
			lo = ld.position.y
		elif lo < -0.02:
			hi_after = maxf(hi_after, ld.position.y)
	_check(lo < -0.02, "tiếp đất: nảy xuống (%.3f)" % lo)
	_check(hi_after > 0.0003, "tiếp đất: lò xo nảy ngược lên một chút")
	for i in 240:
		ld.update(1.0 / 60.0, 0.0, true)
	_check(absf(ld.position.y) < 0.002, "nảy tiếp đất hồi về")

	# Súng giật
	var g: Node3D = _fresh()
	await process_frame
	var rest: Vector3 = g.gun_pivot.position
	g.kick()
	_check(g.gun_pivot.position.z > rest.z + 0.05 and g.gun_pivot.rotation_degrees.x > 5.0, "bắn: súng giật lùi và hất nòng")
	_check(g.muzzle_flash.visible, "bắn: chớp nòng bật")
	g.update(float(V["flash_time"]) + 0.01, 0.0, true)
	_check(not g.muzzle_flash.visible, "chớp nòng tắt sau flash_time")
	await create_timer(float(V["kick_time"]) + 0.2).timeout
	_check(g.gun_pivot.position.distance_to(rest) < 0.005 and g.gun_pivot.rotation_degrees.length() < 0.5, "súng hồi về chỗ cũ sau giật")

	# Nạp đạn: hạ rồi nâng đúng thời gian
	var r: Node3D = _fresh()
	await process_frame
	var rrest: Vector3 = r.gun_pivot.position
	r.set_reloading(true)
	await create_timer(float(V["reload_down_time"]) + 0.15).timeout
	_check(r.gun_pivot.position.y < rrest.y - 0.25, "nạp: súng hạ xuống")
	r.kick()
	_check(r.gun_pivot.position.y < rrest.y - 0.25, "nạp: bắn bị bỏ qua khi đang nạp")
	await create_timer(float(Global.COMBAT["gun_reload"]) - float(V["reload_down_time"]) - 0.1 + 0.3).timeout
	_check(r.gun_pivot.position.distance_to(rrest) < 0.01, "nạp xong: súng về đúng vị trí (sau %.2fs)" % float(Global.COMBAT["gun_reload"]))
	var r2: Node3D = _fresh()
	await process_frame
	r2.set_reloading(true)
	await create_timer(0.35).timeout
	r2.set_reloading(false)
	await create_timer(0.25).timeout
	_check(r2.gun_pivot.position.distance_to(r2._gun_rest_pos) < 0.01 and not r2.reloading, "hủy nạp (reloading=false): súng về ngay")

	# Kiếm: chém và parry theo thời lượng Signal
	var sw: Node3D = _fresh()
	await process_frame
	sw.play_swing(0.1, 0.1, 0.1)
	await create_timer(0.12).timeout
	_check(sw.sword_pivot.rotation_degrees.y > 15.0, "chém: sau windup kiếm giơ cao")
	await create_timer(0.35).timeout
	_check(sw.sword_pivot.rotation_degrees.distance_to(Vector3(72.0, 0.0, -6.0)) < 1.0, "chém: kiếm về tư thế nghỉ sau recovery")
	_check(sw.sword_pivot.rotation_degrees.x > 60.0 and sw.sword_pivot.rotation_degrees.x < 90.0, "kiếm cầm thẳng: lưỡi hướng lên khi nghỉ")
	sw.raise()
	await create_timer(0.1).timeout
	_check(sw.sword_pivot.rotation_degrees.x < 55.0, "parry: kiếm chắn")

	# Giật khi bị đánh: đẩy lùi theo hướng đòn rồi lò xo kéo về
	var fl: Node3D = _fresh()
	fl.flinch(Vector3(1.0, 0.0, 0.0))
	var fz: float = 0.0
	var fx: float = 0.0
	for i in 20:
		fl.update(1.0 / 60.0, 0.0, true)
		fz = maxf(fz, fl.position.z)
		fx = maxf(fx, fl.position.x)
	_check(fz > 0.02 and fx > 0.01, "bị đánh: viewmodel giật theo hướng đòn (z %.3f, x %.3f)" % [fz, fx])
	for i in 240:
		fl.update(1.0 / 60.0, 0.0, true)
	_check(fl.position.length() < 0.003, "giật hồi về")
	fl.reset()

	# Nối vào người chơi thật
	var p: Node3D = load("res://scenes/player.tscn").instantiate()
	root.add_child(p)
	await process_frame
	_check(p.viewmodel != null and p.viewmodel.get_parent() == p.head, "người chơi có ViewModel dưới Head")
	p.combat.shot_fired.emit(Vector3.ZERO, Vector3.ONE)
	_check(p.viewmodel.muzzle_flash.visible, "người chơi: shot_fired -> súng giật + chớp nòng")
	p.combat.reloading_changed.emit(true)
	_check(p.viewmodel.reloading, "người chơi: reloading_changed -> nạp đạn")
	p.melee.swing_started.emit(0.2, 0.1, 0.2)
	await create_timer(0.22).timeout
	_check(p.viewmodel.sword_pivot.rotation_degrees.y > 15.0, "người chơi: swing_started -> kiếm chém")
	p.respawn(Vector3.ZERO)
	_check(not p.viewmodel.reloading and not p.viewmodel.muzzle_flash.visible, "người chơi: hồi sinh -> viewmodel về nghỉ")
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
