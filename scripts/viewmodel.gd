extends Node3D
## Tay + vũ khí góc nhìn thứ nhất (con của Head). Chỉ là hiển thị, không ảnh hưởng vật lý.
## Lớp nền (`update`): nhún khi chạy, lắc theo chuột, tư thế theo trạng thái, nảy khi tiếp đất; các
## chuyển động này đi qua LÒ XO nên có quán tính và nảy nhẹ khi hồi về.
## Lớp chiến đấu: kiếm (`play_swing`, `raise`), súng (`kick`, `set_reloading`), giật khi bị đánh (`flinch`).
## Chủ nhân (player) nối Signal của component tới các hàm này ("signal up").


## Lò xo 3 chiều: kéo `x` về `target`. Bước nhỏ cố định để ổn định khi frame chậm.
class Spring extends RefCounted:
	var x: Vector3 = Vector3.ZERO
	var v: Vector3 = Vector3.ZERO

	func step(dt: float, target: Vector3, k: float, c: float) -> void:
		var n: int = maxi(1, ceili(dt / (1.0 / 120.0)))
		var h: float = dt / float(n)
		for i in n:
			v += ((target - x) * k - v * c) * h
			x += v * h


var sword_pivot: Node3D
var gun_pivot: Node3D
var weapon_id: String = "pistol"
var _gun_models: Dictionary = {}
var _flash_z: Dictionary = {}
var muzzle_flash: MeshInstance3D

var bob_offset: Vector3 = Vector3.ZERO   # nhún hiện tại (để test)
var state_name: String = ""
var reloading: bool = false

var _bob_phase: float = 0.0
var _pos_spring := Spring.new()          # độ lệch vị trí (m): tư thế trạng thái + tiếp đất + giật
var _rot_spring := Spring.new()          # độ lệch xoay (độ: pitch, yaw, roll): lắc chuột + tư thế trạng thái
var _was_grounded: bool = true
var _sword_tween: Tween
var _gun_tween: Tween
var _sword_rest: Vector3 = Vector3(72.0, 0.0, -6.0)
var _gun_rest_pos: Vector3
var _flash_t: float = 0.0


func _ready() -> void:
	var V: Dictionary = Global.VIEWMODEL
	var sleeve := _mat(V["sleeve"], 0.1, 0.8)
	var glove := _mat(V["glove"], 0.0, 0.9)
	var steel := _mat(V["steel"], 0.8, 0.25)
	var steel_dark := _mat(Color(V["steel"]).darkened(0.35), 0.8, 0.3)
	var metal := _mat(V["gun_metal"], 0.6, 0.4)
	var metal_light := _mat(Color(V["gun_metal"]).lightened(0.18), 0.7, 0.35)
	var gold := _mat(Color(0.8, 0.65, 0.25), 0.8, 0.3)

	# ---- Kiếm (gốc = bàn tay cầm chuôi, lưỡi chỉ về -Z) ----
	sword_pivot = _node("SwordPivot", self, V["sword_pos"])
	sword_pivot.rotation_degrees = _sword_rest
	_part(sword_pivot, Vector3(0.036, 0.036, 0.2), Vector3(0.0, 0.0, 0.0), metal)             # chuôi
	_part(sword_pivot, Vector3(0.042, 0.042, 0.03), Vector3(0.0, 0.0, 0.1), gold)           # đầu chuôi
	_part(sword_pivot, Vector3(0.14, 0.03, 0.03), Vector3(0.0, 0.0, -0.115), gold)            # tsuba (chắn tay)
	_part(sword_pivot, Vector3(0.016, 0.058, 0.86), Vector3(0.0, 0.0, -0.57), steel)          # lưỡi
	_part(sword_pivot, Vector3(0.022, 0.014, 0.82), Vector3(0.0, 0.032, -0.56), steel_dark)   # sống lưỡi
	_part(sword_pivot, Vector3(0.016, 0.058, 0.06), Vector3(0.0, 0.0, -1.03), steel, Vector3(0.0, 0.0, 0.0)) # mũi
	_hand(sword_pivot, Vector3(0.0, 0.0, 0.0), glove, true)
	_arm(sword_pivot, Basis.from_euler(sword_pivot.rotation).inverse() * Vector3(0.22, -0.5, 0.45), Vector3(0.0, -0.02, 0.09), sleeve)

	# ---- Súng lục (gốc = bàn tay cầm báng, nòng chỉ về -Z) ----
	gun_pivot = _node("GunPivot", self, V["gun_pos"])
	_gun_rest_pos = gun_pivot.position
	var pistol := _node("Pistol", gun_pivot, Vector3.ZERO)
	_part(pistol, Vector3(0.05, 0.04, 0.2), Vector3(0.0, 0.0, -0.08), metal)               # khung
	_part(pistol, Vector3(0.056, 0.05, 0.27), Vector3(0.0, 0.045, -0.1), metal_light)      # thân trượt
	_part(pistol, Vector3(0.026, 0.026, 0.09), Vector3(0.0, 0.048, -0.275), metal)         # nòng
	_part(pistol, Vector3(0.018, 0.016, 0.02), Vector3(0.0, 0.078, -0.2), metal)           # đầu ruồi
	_part(pistol, Vector3(0.048, 0.11, 0.055), Vector3(0.0, -0.065, 0.02), metal, Vector3(12.0, 0.0, 0.0)) # báng
	_part(pistol, Vector3(0.016, 0.03, 0.07), Vector3(0.0, -0.035, -0.045), metal)         # bao cò
	_hand(gun_pivot, Vector3(0.0, -0.06, 0.02), glove, false)
	_arm(gun_pivot, Vector3(-0.1, -0.55, 0.38), Vector3(0.0, -0.1, 0.07), sleeve)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.85, 0.4)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.8, 0.3)
	fm.emission_energy_multiplier = 4.0
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	muzzle_flash = _part(gun_pivot, Vector3(0.09, 0.09, 0.1), Vector3(0.0, 0.048, -0.36), fm)
	muzzle_flash.visible = false

	# ---- Các súng khác (cùng gốc = bàn tay cầm; chỉ hiện súng đang chọn) ----
	_gun_models["pistol"] = pistol
	_flash_z["pistol"] = -0.36
	var wood := _mat(Color(0.32, 0.2, 0.1), 0.0, 0.8)
	var scope_mat := _mat(Color(0.08, 0.08, 0.1), 0.5, 0.3)
	var red := _mat(Color(0.7, 0.15, 0.1), 0.2, 0.6)
	var sg := _node("Shotgun", gun_pivot, Vector3.ZERO)
	_part(sg, Vector3(0.03, 0.03, 0.5), Vector3(-0.02, 0.05, -0.3), metal)                  # nòng trái
	_part(sg, Vector3(0.03, 0.03, 0.5), Vector3(0.02, 0.05, -0.3), metal)                   # nòng phải
	_part(sg, Vector3(0.09, 0.05, 0.12), Vector3(0.0, 0.02, -0.02), metal_light)            # thân
	_part(sg, Vector3(0.05, 0.035, 0.22), Vector3(0.0, 0.01, -0.2), wood)                   # ốp tay
	_part(sg, Vector3(0.05, 0.11, 0.06), Vector3(0.0, -0.065, 0.04), wood, Vector3(12.0, 0.0, 0.0)) # báng
	_gun_models["shotgun"] = sg
	_flash_z["shotgun"] = -0.6
	var ln := _node("Launcher", gun_pivot, Vector3.ZERO)
	_part(ln, Vector3(0.11, 0.11, 0.55), Vector3(0.0, 0.07, -0.22), metal_light)            # ống phóng
	_part(ln, Vector3(0.13, 0.13, 0.06), Vector3(0.0, 0.07, -0.5), red)                     # miệng ống
	_part(ln, Vector3(0.05, 0.1, 0.05), Vector3(0.0, -0.04, 0.02), metal, Vector3(12.0, 0.0, 0.0)) # báng
	_part(ln, Vector3(0.03, 0.04, 0.1), Vector3(0.0, 0.15, -0.1), metal)                    # ngắm
	_gun_models["launcher"] = ln
	_flash_z["launcher"] = -0.58
	var sn := _node("Sniper", gun_pivot, Vector3.ZERO)
	_part(sn, Vector3(0.03, 0.03, 0.75), Vector3(0.0, 0.05, -0.4), metal)                   # nòng dài
	_part(sn, Vector3(0.06, 0.06, 0.3), Vector3(0.0, 0.02, -0.02), metal_light)             # thân
	_part(sn, Vector3(0.05, 0.05, 0.22), Vector3(0.0, 0.11, -0.1), scope_mat)               # ống ngắm
	_part(sn, Vector3(0.03, 0.04, 0.03), Vector3(0.0, 0.075, -0.05), metal)                 # chân ngắm
	_part(sn, Vector3(0.05, 0.11, 0.06), Vector3(0.0, -0.065, 0.06), metal, Vector3(12.0, 0.0, 0.0)) # báng
	_gun_models["sniper"] = sn
	_flash_z["sniper"] = -0.82
	set_weapon("pistol", false)


## Chọn súng hiển thị + hoạt ảnh rút súng (hạ xuống rồi nâng lên).
func set_weapon(id: String, animate: bool = true) -> void:
	if not _gun_models.has(id):
		return
	for k in _gun_models:
		(_gun_models[k] as Node3D).visible = (k == id)
	muzzle_flash.position.z = float(_flash_z[id])
	weapon_id = id
	if animate and is_inside_tree():
		_gun_restart()
		var up: float = float(Global.WEAPONS[id]["draw"]) if Global.WEAPONS.has(id) else 0.3
		gun_pivot.position = _gun_rest_pos + Vector3(0.0, -0.3, 0.1)
		gun_pivot.rotation_degrees = Vector3(-35.0, 0.0, 0.0)
		_gun_tween.set_parallel(true)
		_gun_tween.tween_property(gun_pivot, "position", _gun_rest_pos, up)
		_gun_tween.tween_property(gun_pivot, "rotation_degrees", Vector3.ZERO, up)


func _node(node_name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	return n


func _mat(c: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = roughness
	return m


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## Một khối: không đổ bóng (thân người chơi đã có bóng riêng).
func _part(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box(size)
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Bàn tay bằng khối: lòng bàn tay + 4 ngón quấn quanh vật cầm + ngón cái.
func _hand(parent: Node3D, at: Vector3, mat: Material, grip_thick: bool) -> void:
	var w: float = 0.075 if grip_thick else 0.07
	_part(parent, Vector3(w, 0.085, 0.08), at + Vector3(0.0, 0.0, 0.025), mat)               # lòng bàn tay
	for i in 4:
		_part(parent, Vector3(w + 0.012, 0.02, 0.026), at + Vector3(0.0, 0.03 - 0.021 * i, -0.03), mat)  # ngón tay
	_part(parent, Vector3(0.026, 0.03, 0.06), at + Vector3(-0.045, 0.02, -0.01), mat, Vector3(0.0, 15.0, 0.0)) # ngón cái


## Cánh tay: hộp dài nối từ `from` (ngoài màn hình, phía sau) tới cổ tay `to`, đi theo vũ khí.
func _arm(parent: Node3D, from: Vector3, to: Vector3, mat: Material) -> void:
	var length: float = from.distance_to(to)
	var arm := MeshInstance3D.new()
	arm.mesh = _box(Vector3(0.085, 0.075, length))
	arm.material_override = mat
	arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(arm)
	arm.position = (from + to) * 0.5
	arm.look_at_from_position(arm.position, to, Vector3.UP)


# ------------------------------------------------------------------ lớp nền

## Chuột xoay: vũ khí bị "hất" lệch rồi lò xo kéo về (có nảy nhẹ). relative = Vector2 pixel.
func add_look(relative: Vector2) -> void:
	var V: Dictionary = Global.VIEWMODEL
	var imp: float = float(V["sway_impulse"])
	_rot_spring.v.x += relative.y * imp
	_rot_spring.v.y += relative.x * imp


## Gọi mỗi frame hiển thị. st: "" | "slide" | "dash" | "wallrun" | "grapple" (cùng quy ước hoạt ảnh thân).
func update(delta: float, speed: float, grounded: bool, st: String = "") -> void:
	var V: Dictionary = Global.VIEWMODEL
	state_name = st
	# Nhún theo bước chạy: biên độ tăng theo tốc độ, chỉ khi đứng đất.
	var amp: float = clampf(speed / float(V["bob_speed_ref"]), 0.0, 1.5) if grounded else 0.0
	_bob_phase = fmod(_bob_phase + speed * delta * float(V["bob_freq"]) * TAU, TAU * 100.0)
	bob_offset = Vector3(cos(_bob_phase * 0.5) * float(V["bob_side"]) * amp, absf(sin(_bob_phase * 0.5)) * float(V["bob_amp"]) * amp * -1.0, 0.0)
	# Tiếp đất: đẩy một xung xuống, lò xo nảy lại.
	if grounded and not _was_grounded:
		_pos_spring.v.y -= float(V["land_impulse"])
	_was_grounded = grounded
	# Tư thế đích theo trạng thái; lò xo tự làm mượt việc chuyển tư thế.
	var tp: Vector3 = Vector3.ZERO
	var tr: Vector3 = Vector3.ZERO
	match st:
		"slide":
			tp = Vector3(0.0, -0.09, 0.05)
			tr = Vector3(4.0, 0.0, 12.0)
		"dash":
			tp = Vector3(0.0, -0.03, 0.14)
			tr = Vector3(-6.0, 0.0, 0.0)
		"wallrun":
			tr = Vector3(0.0, 0.0, 8.0)
	_pos_spring.step(delta, tp, float(V["spring_k"]), float(V["spring_c"]))
	_rot_spring.step(delta, tr, float(V["rot_spring_k"]), float(V["rot_spring_c"]))
	var m: float = float(V["sway_max"])
	_rot_spring.x.x = clampf(_rot_spring.x.x, tr.x - m, tr.x + m)
	_rot_spring.x.y = clampf(_rot_spring.x.y, tr.y - m, tr.y + m)
	position = bob_offset + _pos_spring.x
	rotation_degrees = _rot_spring.x
	# Đu móc: tay trái (súng) giơ lên trừ khi đang nạp/bắn.
	if not reloading and (_gun_tween == null or not _gun_tween.is_valid()):
		var f: float = minf(1.0, float(V["state_blend"]) * delta)
		var up: Vector3 = _gun_rest_pos + (Vector3(0.05, 0.22, -0.08) if st == "grapple" else Vector3.ZERO)
		gun_pivot.position = gun_pivot.position.lerp(up, f)
	# Chớp nòng tắt sau flash_time.
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			muzzle_flash.visible = false


# ------------------------------------------------------------------ chiến đấu

func play_swing(windup: float, active: float, recovery: float) -> void:
	_sword_restart()
	_sword_tween.tween_property(sword_pivot, "rotation_degrees", Vector3(88.0, 35.0, -30.0), windup)
	_sword_tween.tween_property(sword_pivot, "rotation_degrees", Vector3(5.0, -45.0, -20.0), active)
	_sword_tween.tween_property(sword_pivot, "rotation_degrees", _sword_rest, recovery)


func raise() -> void:
	_sword_restart()
	_sword_tween.tween_property(sword_pivot, "rotation_degrees", Vector3(40.0, 0.0, 0.0), 0.05)
	_sword_tween.tween_interval(Global.COMBAT["parry_window"])
	_sword_tween.tween_property(sword_pivot, "rotation_degrees", _sword_rest, 0.15)


func _sword_restart() -> void:
	if _sword_tween != null and _sword_tween.is_valid():
		_sword_tween.kill()
	_sword_tween = create_tween()


## Súng giật lùi + hất nòng + chớp nòng rồi hồi về.
func kick() -> void:
	if reloading:
		return
	var V: Dictionary = Global.VIEWMODEL
	_gun_restart()
	gun_pivot.position = _gun_rest_pos + Vector3(0.0, 0.0, float(V["kick_back"]))
	gun_pivot.rotation_degrees = Vector3(float(V["kick_pitch"]), 0.0, 0.0)
	muzzle_flash.visible = true
	_flash_t = float(V["flash_time"])
	var t: float = float(V["kick_time"])
	_gun_tween.set_parallel(true)
	_gun_tween.tween_property(gun_pivot, "position", _gun_rest_pos, t)
	_gun_tween.tween_property(gun_pivot, "rotation_degrees", Vector3.ZERO, t)


## Nạp đạn: hạ súng, lắc khi thay băng, nâng lại đúng thời gian nạp. on=false (xong/hủy) đưa về ngay.
func set_reloading(on: bool) -> void:
	var V: Dictionary = Global.VIEWMODEL
	if on:
		reloading = true
		_gun_restart()
		var total: float = float(Global.WEAPONS[weapon_id]["reload"])
		var down: float = float(V["reload_down_time"])
		var up: float = float(V["reload_up_time"])
		var hold: float = maxf(total - down - up, 0.0)
		var low_pos: Vector3 = _gun_rest_pos + Vector3(0.0, -0.35, 0.1)
		_gun_tween.tween_property(gun_pivot, "position", low_pos, down)
		_gun_tween.parallel().tween_property(gun_pivot, "rotation_degrees", Vector3(-40.0, 0.0, 25.0), down)
		_gun_tween.tween_property(gun_pivot, "rotation_degrees", Vector3(-40.0, 0.0, 10.0), hold * 0.5)
		_gun_tween.tween_property(gun_pivot, "rotation_degrees", Vector3(-40.0, 0.0, 25.0), hold * 0.5)
		_gun_tween.tween_property(gun_pivot, "position", _gun_rest_pos, up)
		_gun_tween.parallel().tween_property(gun_pivot, "rotation_degrees", Vector3.ZERO, up)
	else:
		reloading = false
		_gun_restart()
		_gun_tween.set_parallel(true)
		_gun_tween.tween_property(gun_pivot, "position", _gun_rest_pos, 0.1)
		_gun_tween.tween_property(gun_pivot, "rotation_degrees", Vector3.ZERO, 0.1)


func _gun_restart() -> void:
	if _gun_tween != null and _gun_tween.is_valid():
		_gun_tween.kill()
	_gun_tween = create_tween()


## Bị đánh: cả viewmodel bị đẩy lùi theo hướng đòn (direction theo hệ tọa độ camera), lò xo kéo về.
func flinch(direction: Vector3) -> void:
	var f: float = float(Global.VIEWMODEL["flinch_impulse"])
	_pos_spring.v += Vector3(clampf(direction.x, -1.0, 1.0) * f * 0.7, -f * 0.35, f)


## Hồi sinh: xóa mọi hiệu ứng đang chạy, về tư thế nghỉ.
func reset() -> void:
	for t in [_sword_tween, _gun_tween]:
		if t != null and t.is_valid():
			t.kill()
	reloading = false
	_pos_spring = Spring.new()
	_rot_spring = Spring.new()
	sword_pivot.rotation_degrees = _sword_rest
	gun_pivot.position = _gun_rest_pos
	gun_pivot.rotation_degrees = Vector3.ZERO
	muzzle_flash.visible = false
