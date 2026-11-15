extends Node3D
## Tay + vũ khí góc nhìn thứ nhất (con của Head). Chỉ là hiển thị, không ảnh hưởng vật lý.
## Lớp nền (`update`): nhún khi chạy, lắc theo chuột, tư thế theo trạng thái, nảy khi tiếp đất.
## Lớp chiến đấu: kiếm (`play_swing`, `raise`), súng (`kick`, `set_reloading`), giật khi bị đánh (`flinch`).
## Chủ nhân (player) nối Signal của component tới các hàm này ("signal up").

var sword_pivot: Node3D
var gun_pivot: Node3D
var muzzle_flash: MeshInstance3D

var bob_offset: Vector3 = Vector3.ZERO   # nhún hiện tại (để test)
var state_name: String = ""
var reloading: bool = false

var _bob_phase: float = 0.0
var _sway: Vector2 = Vector2.ZERO        # độ (pitch, yaw) trễ theo chuột
var _state_pos: Vector3 = Vector3.ZERO
var _state_rot: Vector3 = Vector3.ZERO
var _land: float = 0.0
var _was_grounded: bool = true
var _flinch: Vector3 = Vector3.ZERO
var _sword_tween: Tween
var _gun_tween: Tween
var _sword_rest: Vector3 = Vector3(-15.0, 10.0, -25.0)
var _gun_rest_pos: Vector3
var _flash_t: float = 0.0


func _ready() -> void:
	var V: Dictionary = Global.VIEWMODEL
	var sleeve := _mat(V["sleeve"], 0.1, 0.8)
	var glove := _mat(V["glove"], 0.0, 0.9)
	var steel := _mat(Color(0.85, 0.9, 1.0), 0.7, 0.3)
	var dark := _mat(Color(0.15, 0.15, 0.18), 0.5, 0.5)

	sword_pivot = _node("SwordPivot", self, V["sword_pos"])
	sword_pivot.rotation_degrees = _sword_rest
	_mesh(sword_pivot, _box(Vector3(0.07, 0.07, 0.95)), Vector3(0.0, 0.0, -0.45), steel)
	_mesh(sword_pivot, _box(Vector3(0.1, 0.1, 0.1)), Vector3(0.0, 0.0, 0.1), glove)       # bàn tay cầm chuôi
	_arm(sword_pivot, Vector3(0.12, -0.14, 0.62), Vector3(0.0, 0.0, 0.08), sleeve)

	gun_pivot = _node("GunPivot", self, V["gun_pos"])
	_gun_rest_pos = gun_pivot.position
	_mesh(gun_pivot, _box(Vector3(0.12, 0.14, 0.4)), Vector3.ZERO, dark)
	_mesh(gun_pivot, _box(Vector3(0.1, 0.1, 0.1)), Vector3(0.0, -0.1, 0.1), glove)        # bàn tay cầm báng
	_arm(gun_pivot, Vector3(-0.1, -0.16, 0.62), Vector3(0.0, -0.1, 0.1), sleeve)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.85, 0.4)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.8, 0.3)
	fm.emission_energy_multiplier = 4.0
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	muzzle_flash = _mesh(gun_pivot, _box(Vector3(0.1, 0.1, 0.12)), Vector3(0.0, 0.0, -0.3), fm)
	muzzle_flash.visible = false


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


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # thân người chơi đã có bóng riêng
	parent.add_child(mi)
	return mi


## Cánh tay: hộp dài nối từ `from` (ngoài màn hình, phía sau) tới bàn tay `to`, đi theo vũ khí.
func _arm(parent: Node3D, from: Vector3, to: Vector3, mat: Material) -> void:
	var length: float = from.distance_to(to)
	var arm := MeshInstance3D.new()
	arm.mesh = _box(Vector3(0.09, 0.09, length))
	arm.material_override = mat
	arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(arm)
	arm.position = (from + to) * 0.5
	arm.look_at_from_position(arm.position, to, Vector3.UP)


# ------------------------------------------------------------------ lớp nền

## Chuột xoay: vũ khí trễ lại một chút rồi hồi về (relative = Vector2 pixel).
func add_look(relative: Vector2) -> void:
	var V: Dictionary = Global.VIEWMODEL
	var m: float = float(V["sway_max"])
	_sway.x = clampf(_sway.x + relative.y * float(V["sway_per_pixel"]), -m, m)
	_sway.y = clampf(_sway.y + relative.x * float(V["sway_per_pixel"]), -m, m)


## Gọi mỗi frame hiển thị. st: "" | "slide" | "dash" | "wallrun" | "grapple" (cùng quy ước hoạt ảnh thân).
func update(delta: float, speed: float, grounded: bool, st: String = "") -> void:
	var V: Dictionary = Global.VIEWMODEL
	state_name = st
	# Nhún theo bước chạy: biên độ tăng theo tốc độ, chỉ khi đứng đất.
	var amp: float = clampf(speed / float(V["bob_speed_ref"]), 0.0, 1.5) if grounded else 0.0
	_bob_phase = fmod(_bob_phase + speed * delta * float(V["bob_freq"]) * TAU, TAU * 100.0)
	bob_offset = Vector3(cos(_bob_phase * 0.5) * float(V["bob_side"]) * amp, absf(sin(_bob_phase * 0.5)) * float(V["bob_amp"]) * amp * -1.0, 0.0)
	# Tiếp đất: nảy xuống rồi hồi.
	if grounded and not _was_grounded:
		_land = float(V["land_dip"])
	_was_grounded = grounded
	_land = lerpf(_land, 0.0, minf(1.0, float(V["land_recover"]) * delta))
	# Trễ theo chuột hồi về 0.
	_sway = _sway.lerp(Vector2.ZERO, minf(1.0, float(V["sway_recover"]) * delta))
	_flinch = _flinch.lerp(Vector3.ZERO, minf(1.0, float(V["flinch_recover"]) * delta))
	# Tư thế theo trạng thái (pha trộn mượt).
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
		"grapple":
			tp = Vector3(0.0, 0.0, 0.0)
	var f: float = minf(1.0, float(V["state_blend"]) * delta)
	_state_pos = _state_pos.lerp(tp, f)
	_state_rot = _state_rot.lerp(tr, f)
	position = bob_offset + _state_pos + Vector3(0.0, -_land, 0.0) + _flinch
	rotation_degrees = Vector3(_sway.x, _sway.y, 0.0) + _state_rot
	# Đu móc: tay trái (súng) giơ lên trừ khi đang nạp đạn.
	if not reloading and (_gun_tween == null or not _gun_tween.is_valid()):
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
	_sword_tween.tween_property(sword_pivot, "rotation_degrees", Vector3(-70.0, 40.0, -25.0), windup)
	_sword_tween.tween_property(sword_pivot, "rotation_degrees", Vector3(20.0, -60.0, -25.0), active)
	_sword_tween.tween_property(sword_pivot, "rotation_degrees", _sword_rest, recovery)


func raise() -> void:
	_sword_restart()
	_sword_tween.tween_property(sword_pivot, "rotation_degrees", Vector3(-85.0, 0.0, 0.0), 0.05)
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
		var total: float = float(Global.COMBAT["gun_reload"])
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


## Bị đánh: cả viewmodel giật lùi theo hướng đòn (direction theo hệ tọa độ camera).
func flinch(direction: Vector3) -> void:
	var f: float = float(Global.VIEWMODEL["flinch_pos"])
	_flinch = Vector3(clampf(direction.x, -1.0, 1.0) * f, -f * 0.5, f)


## Hồi sinh: xóa mọi hiệu ứng đang chạy, về tư thế nghỉ.
func reset() -> void:
	for t in [_sword_tween, _gun_tween]:
		if t != null and t.is_valid():
			t.kill()
	reloading = false
	_flinch = Vector3.ZERO
	_land = 0.0
	sword_pivot.rotation_degrees = _sword_rest
	gun_pivot.position = _gun_rest_pos
	gun_pivot.rotation_degrees = Vector3.ZERO
	muzzle_flash.visible = false
