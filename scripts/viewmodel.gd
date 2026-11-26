extends Node3D
## Tay + vũ khí góc nhìn thứ nhất (con của Head). Chỉ là hiển thị, không ảnh hưởng vật lý.
## Hệ hoạt ảnh (M19), mọi thứ đi qua LÒ XO nên không bao giờ "nhảy" tư thế:
##  - Lớp nền (`update`): nhún khi chạy, lắc theo chuột, tư thế theo trạng thái. Mỗi trạng thái có TRỌNG SỐ
##    (`_w`) trượt mượt 0..1 nên đổi trạng thái là cross-fade, không đổi tức thì.
##  - Lớp chiến đấu: CLIP keyframe (`Layer`) cho kiếm và súng. Clip mới bắt đầu từ tư thế HIỆN TẠI (không từ tư thế nghỉ)
##    và kết thúc bằng khoá "base" = tư thế nền đang sống, nên chen ngang/nối đòn luôn liền mạch.
##  - Cửa sổ hủy + hàng đợi: lệnh đến khi clip chưa tới `cancel_from` được xếp hàng, chạy ngay khi hết đoạn không-hủy-được.
##  - Anticipation -> action -> follow-through: easing riêng từng đoạn; vị trí và góc cổ tay là hai lò xo lệch pha (overlap).
##  - Cánh tay hai khớp (vai-khuỷu-cổ tay, IK): bàn tay dính chuôi/báng, cẳng tay tự xoay theo.
## Public API giữ nguyên: update, play_swing, raise, parry_hit, parry_fail, kick, set_reloading, flinch, reset, set_weapon.
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


## Easing có tên (xem Layer.ease_u).
static func ease_u(kind: String, u: float) -> float:
	return Layer.ease_u(kind, u)


## Một lớp hoạt ảnh cho một vật cầm (kiếm hoặc súng): vị trí + góc, mỗi thứ một lò xo; clip keyframe đặt ĐÍCH cho lò xo.
## Khoá clip: {d: thời lượng, pos, rot (null = giữ), ease, k (độ cứng), base (true = đích là tư thế nền sống)}.
class Layer extends RefCounted:
	var pos := Spring.new()
	var rot := Spring.new()
	var base_k: float = 80.0
	var zeta: float = 0.85
	var rot_lag: float = 0.65        # lò xo góc mềm hơn lò xo vị trí: cổ tay trễ nhịp so với tay (overlap)
	var keys: Array = []
	var t: float = 0.0
	var clip_name: String = ""
	var cancel_from: float = 0.0     # từ mốc này lệnh mới được ngắt clip
	var from_pos: Vector3 = Vector3.ZERO
	var from_rot: Vector3 = Vector3.ZERO
	var phase_name: String = "base"
	var phase_u: float = 0.0
	var queued: Callable = Callable()
	var cur_k: float = 80.0
	var settle_k: float = 80.0       # độ cứng còn lại sau khi clip kết thúc: giảm dần về base_k (không tụt độ cứng đột ngột)

	## Easing có tên (u 0..1). "elastic" và "back" cố ý vượt quá 1 rồi về.
	static func ease_u(kind: String, u: float) -> float:
		u = clampf(u, 0.0, 1.0)
		match kind:
			"in":
				return u * u * u
			"out":
				return 1.0 - pow(1.0 - u, 3.0)
			"io":
				return u * u * (3.0 - 2.0 * u)
			"elastic":
				if u >= 1.0:
					return 1.0
				return pow(2.0, -10.0 * u) * sin((u * 10.0 - 0.75) * TAU / 3.0) + 1.0
			"back":
				var c1: float = 1.70158
				var c3: float = c1 + 1.0
				return 1.0 + c3 * pow(u - 1.0, 3.0) + c1 * pow(u - 1.0, 2.0)
		return u

	func active() -> bool:
		return not keys.is_empty()

	func start(p_name: String, p_keys: Array, p_cancel_from: float) -> void:
		clip_name = p_name
		keys = p_keys
		t = 0.0
		cancel_from = p_cancel_from
		from_pos = pos.x
		from_rot = rot.x
		queued = Callable()
		phase_name = "%s#0" % p_name
		phase_u = 0.0

	func clear() -> void:
		keys = []
		clip_name = ""
		queued = Callable()
		phase_name = "base"
		phase_u = 0.0

	## Đích hiện tại của lò xo (pos, rot) tại thời điểm t.
	func target(base_pos: Vector3, base_rot: Vector3) -> Array:
		cur_k = maxf(base_k, settle_k)
		if keys.is_empty():
			return [base_pos, base_rot]
		var t0: float = 0.0
		var p0: Vector3 = from_pos
		var r0: Vector3 = from_rot
		for i in keys.size():
			var key: Dictionary = keys[i]
			var d: float = maxf(float(key["d"]), 0.0001)
			var is_base: bool = bool(key.get("base", false))
			var p1: Vector3 = base_pos if is_base else Vector3(key.get("pos", p0))
			var r1: Vector3 = base_rot if is_base else Vector3(key.get("rot", r0))
			if t < t0 + d or i == keys.size() - 1:
				var u: float = clampf((t - t0) / d, 0.0, 1.0)
				var e: float = ease_u(String(key.get("ease", "io")), u)
				cur_k = float(key.get("k", base_k))
				phase_name = "%s#%d" % [clip_name, i]
				phase_u = u
				return [p0.lerp(p1, e), r0.lerp(r1, e)]
			t0 += d
			p0 = Vector3(key.get("pos", p0)) if not is_base else base_pos
			r0 = Vector3(key.get("rot", r0)) if not is_base else base_rot
		return [base_pos, base_rot]

	func total() -> float:
		var s: float = 0.0
		for key in keys:
			s += float(key["d"])
		return s

	## Một bước: tiến thời gian clip, kéo lò xo về đích. Trả về true nếu clip vừa kết thúc.
	func step(dt: float, base_pos: Vector3, base_rot: Vector3) -> bool:
		var finished: bool = false
		if not keys.is_empty():
			t += dt
			if t >= total():
				finished = true
		var tg: Array = target(base_pos, base_rot)
		var k: float = cur_k
		var c: float = 2.0 * sqrt(k) * zeta
		var kr: float = k * rot_lag
		pos.step(dt, tg[0], k, c)
		rot.step(dt, tg[1], kr, 2.0 * sqrt(kr) * zeta)
		if finished:
			settle_k = cur_k
			clear()
		elif keys.is_empty():
			settle_k = lerpf(settle_k, base_k, 1.0 - exp(-dt * 5.0))
		return finished


var sword_pivot: Node3D
var gun_pivot: Node3D
var weapon_id: String = "pistol"
var _gun_models: Dictionary = {}
var _flash_z: Dictionary = {}
## Tên phần cử động trong .glb của từng súng (M43).
const _LOWPOLY_ANIM: Dictionary = {"pistol": "Mag", "shotgun": "Pump", "launcher": "Cap", "sniper": "Bolt"}
var muzzle_flash: MeshInstance3D

var bob_offset: Vector3 = Vector3.ZERO   # nhún hiện tại (để test)
var state_name: String = ""
var reloading: bool = false

var _bob_phase: float = 0.0
var _pos_spring := Spring.new()          # độ lệch vị trí (m) của cả viewmodel: tư thế trạng thái + tiếp đất + giật
var _rot_spring := Spring.new()          # độ lệch xoay (độ: pitch, yaw, roll): lắc chuột + tư thế trạng thái
var _was_grounded: bool = true
var _sw := Layer.new()                   # lớp kiếm
var _gn := Layer.new()                   # lớp súng (nền + nạp + rút)
var _kick_spring := Spring.new()         # giật súng, cộng thêm: x = góc hất nòng (độ), z = lùi (m)
var _sword_rest: Vector3 = Vector3(72.0, 0.0, -6.0)
var _sword_rest_pos: Vector3
var _t: float = 0.0
var _flash_light: OmniLight3D
var _blade_light: OmniLight3D
var _blade_tween: Tween
var _gun_rest_pos: Vector3
var _flash_t: float = 0.0
var _w: Dictionary = {"slide": 0.0, "dash": 0.0, "wallrun": 0.0, "grapple": 0.0}  # trọng số trạng thái, trượt mượt
var _step_side: float = 1.0
var _driven: bool = false                # update() đã được chủ nhân gọi trong frame này
var _la: Array = [0.0, true, "", 0.0]    # tham số update() lần cuối (để tự chạy khi đứng một mình)
var _sword_arm: Dictionary = {}
var _sword_fingers: Array = []
var _gun_fingers: Array = []
var _sword_curl: float = 0.0             # bóp tay kiếm (mượt)
var _gun_curl: float = 0.0
var _anim_parts: Dictionary = {}         # id súng -> {node, pos, rot}: bộ phận chuyển động khi nạp (băng, ống trượt, khoá nòng, nắp)
var _fall_speed: float = 0.0
var _gun_arm: Dictionary = {}
## Hàng đợi đòn: lệnh chờ tới cửa sổ hủy của clip đang chạy. Kiểm bằng `pending_command` trong test/debug.
var pending_command: String = ""
var debug_enabled: bool = false


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
	_sword_rest_pos = sword_pivot.position
	if not _add_lowpoly_sword(sword_pivot):
		_part(sword_pivot, Vector3(0.036, 0.036, 0.2), Vector3(0.0, 0.0, 0.0), metal)             # chuôi
		_part(sword_pivot, Vector3(0.042, 0.042, 0.03), Vector3(0.0, 0.0, 0.1), gold)           # đầu chuôi
		_part(sword_pivot, Vector3(0.14, 0.03, 0.03), Vector3(0.0, 0.0, -0.115), gold)            # tsuba (chắn tay)
		_part(sword_pivot, Vector3(0.016, 0.058, 0.86), Vector3(0.0, 0.0, -0.57), steel)          # lưỡi
		_part(sword_pivot, Vector3(0.022, 0.014, 0.82), Vector3(0.0, 0.032, -0.56), steel_dark)   # sống lưỡi
		_part(sword_pivot, Vector3(0.016, 0.058, 0.06), Vector3(0.0, 0.0, -1.03), steel, Vector3(0.0, 0.0, 0.0)) # mũi
	_sword_fingers = _hand(sword_pivot, Vector3(0.0, 0.0, 0.0), glove, true)
	_sword_arm = _make_arm(sword_pivot, Vector3(0.0, -0.02, 0.09), Vector3(V["sword_shoulder"]), Vector3(0.6, -1.0, 0.25), sleeve)

	# ---- Súng lục (gốc = bàn tay cầm báng, nòng chỉ về -Z) ----
	gun_pivot = _node("GunPivot", self, V["gun_pos"])
	_gun_rest_pos = gun_pivot.position
	var pistol := _node("Pistol", gun_pivot, Vector3.ZERO)
	if not _add_lowpoly_gun("pistol", pistol):
		_part(pistol, Vector3(0.05, 0.04, 0.2), Vector3(0.0, 0.0, -0.08), metal)               # khung
		_part(pistol, Vector3(0.056, 0.05, 0.27), Vector3(0.0, 0.045, -0.1), metal_light)      # thân trượt
		_part(pistol, Vector3(0.026, 0.026, 0.09), Vector3(0.0, 0.048, -0.275), metal)         # nòng
		_part(pistol, Vector3(0.018, 0.016, 0.02), Vector3(0.0, 0.078, -0.2), metal)           # đầu ruồi
		_part(pistol, Vector3(0.048, 0.11, 0.055), Vector3(0.0, -0.065, 0.02), metal, Vector3(12.0, 0.0, 0.0)) # báng
		_part(pistol, Vector3(0.016, 0.03, 0.07), Vector3(0.0, -0.035, -0.045), metal)         # bao cò
		_part(pistol, Vector3(0.058, 0.012, 0.2), Vector3(0.0, 0.074, -0.1), steel_dark)       # M29: rãnh trượt
		_part(pistol, Vector3(0.012, 0.014, 0.05), Vector3(0.0, 0.076, 0.0), metal)            # khe ngắm sau
		_part(pistol, Vector3(0.052, 0.02, 0.05), Vector3(0.0, -0.01, -0.17), gold)            # vòng khoá nòng
		var pmag := _node("Mag", pistol, Vector3.ZERO)
		_part(pmag, Vector3(0.04, 0.05, 0.045), Vector3(0.0, -0.135, 0.03), steel_dark, Vector3(12.0, 0.0, 0.0))  # băng đạn thò dưới báng
		_anim_parts["pistol"] = {"node": pmag, "pos": pmag.position, "rot": pmag.rotation_degrees}
	_gun_fingers = _hand(gun_pivot, Vector3(0.0, -0.06, 0.02), glove, false)
	_gun_arm = _make_arm(gun_pivot, Vector3(0.0, -0.1, 0.07), Vector3(V["gun_shoulder"]), Vector3(-0.6, -1.0, 0.25), sleeve)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.85, 0.4)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.8, 0.3)
	fm.emission_energy_multiplier = 4.0
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	muzzle_flash = _part(gun_pivot, Vector3(0.09, 0.09, 0.1), Vector3(0.0, 0.048, -0.36), fm)
	muzzle_flash.visible = false
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.8, 0.4)
	_flash_light.omni_range = 6.0
	_flash_light.shadow_enabled = false
	_flash_light.visible = false
	muzzle_flash.add_child(_flash_light)
	# Đèn chớp lưỡi kiếm (M28): dựng sẵn, ẩn; chỉ bật khi parry (không tạo node giữa trận)
	_blade_light = OmniLight3D.new()
	_blade_light.light_color = Color(0.6, 0.9, 1.0)
	_blade_light.omni_range = 2.5
	_blade_light.shadow_enabled = false
	_blade_light.visible = false
	_blade_light.position = Vector3(0.0, 0.0, -0.3)
	sword_pivot.add_child(_blade_light)

	# ---- Các súng khác (cùng gốc = bàn tay cầm; chỉ hiện súng đang chọn) ----
	_gun_models["pistol"] = pistol
	_flash_z["pistol"] = _flash_z.get("pistol", -0.36)
	var wood := _mat(Color(0.32, 0.2, 0.1), 0.0, 0.8)
	var scope_mat := _mat(Color(0.08, 0.08, 0.1), 0.5, 0.3)
	var red := _mat(Color(0.7, 0.15, 0.1), 0.2, 0.6)
	var sg := _node("Shotgun", gun_pivot, Vector3.ZERO)
	if not _add_lowpoly_gun("shotgun", sg):
		_part(sg, Vector3(0.03, 0.03, 0.5), Vector3(-0.02, 0.05, -0.3), metal)                  # nòng trái
		_part(sg, Vector3(0.03, 0.03, 0.5), Vector3(0.02, 0.05, -0.3), metal)                   # nòng phải
		_part(sg, Vector3(0.09, 0.05, 0.12), Vector3(0.0, 0.02, -0.02), metal_light)            # thân
		var pump := _node("Pump", sg, Vector3.ZERO)
		_part(pump, Vector3(0.05, 0.035, 0.22), Vector3(0.0, 0.01, -0.2), wood)                 # ốp tay (ống trượt)
		_part(pump, Vector3(0.056, 0.012, 0.03), Vector3(0.0, 0.01, -0.1), steel_dark)          # M29: vòng ốp tay
		_part(sg, Vector3(0.012, 0.012, 0.46), Vector3(0.0, 0.074, -0.3), metal_light)          # thanh ngắm giữa 2 nòng
		_part(sg, Vector3(0.016, 0.016, 0.016), Vector3(0.0, 0.086, -0.52), gold)               # đầu ruồi
		_anim_parts["shotgun"] = {"node": pump, "pos": pump.position, "rot": pump.rotation_degrees}
		_part(sg, Vector3(0.05, 0.11, 0.06), Vector3(0.0, -0.065, 0.04), wood, Vector3(12.0, 0.0, 0.0)) # báng
	_gun_models["shotgun"] = sg
	_flash_z["shotgun"] = _flash_z.get("shotgun", -0.6)
	var ln := _node("Launcher", gun_pivot, Vector3.ZERO)
	if not _add_lowpoly_gun("launcher", ln):
		_part(ln, Vector3(0.11, 0.11, 0.55), Vector3(0.0, 0.07, -0.22), metal_light)            # ống phóng
		var lcap := _node("Cap", ln, Vector3(0.0, 0.07, -0.5))
		_part(lcap, Vector3(0.13, 0.13, 0.06), Vector3.ZERO, red)                               # miệng ống (nắp mở khi nạp)
		_part(ln, Vector3(0.12, 0.016, 0.1), Vector3(0.0, 0.134, -0.3), steel_dark)             # M29: băng đạn / giá đỡ
		_part(ln, Vector3(0.016, 0.1, 0.016), Vector3(0.0, 0.02, -0.12), metal)                 # tay cầm trước
		_anim_parts["launcher"] = {"node": lcap, "pos": lcap.position, "rot": lcap.rotation_degrees}
		_part(ln, Vector3(0.05, 0.1, 0.05), Vector3(0.0, -0.04, 0.02), metal, Vector3(12.0, 0.0, 0.0)) # báng
		_part(ln, Vector3(0.03, 0.04, 0.1), Vector3(0.0, 0.15, -0.1), metal)                    # ngắm
	_gun_models["launcher"] = ln
	_flash_z["launcher"] = _flash_z.get("launcher", -0.58)
	var sn := _node("Sniper", gun_pivot, Vector3.ZERO)
	if not _add_lowpoly_gun("sniper", sn):
		_part(sn, Vector3(0.03, 0.03, 0.75), Vector3(0.0, 0.05, -0.4), metal)                   # nòng dài
		_part(sn, Vector3(0.06, 0.06, 0.3), Vector3(0.0, 0.02, -0.02), metal_light)             # thân
		_part(sn, Vector3(0.05, 0.05, 0.22), Vector3(0.0, 0.11, -0.1), scope_mat)               # ống ngắm
		_part(sn, Vector3(0.03, 0.04, 0.03), Vector3(0.0, 0.075, -0.05), metal)                 # chân ngắm
		var bolt := _node("Bolt", sn, Vector3(0.04, 0.035, 0.0))
		_part(bolt, Vector3(0.012, 0.012, 0.05), Vector3.ZERO, gold)                            # M29: khoá nòng
		_part(bolt, Vector3(0.03, 0.012, 0.012), Vector3(0.015, 0.0, 0.02), gold)               # tay kéo
		_part(sn, Vector3(0.04, 0.012, 0.18), Vector3(0.0, 0.052, -0.1), metal_light)           # thanh ray
		_part(sn, Vector3(0.012, 0.012, 0.1), Vector3(0.0, 0.0, -0.78), steel_dark)             # chân hãm nòng
		_anim_parts["sniper"] = {"node": bolt, "pos": bolt.position, "rot": bolt.rotation_degrees}
		_part(sn, Vector3(0.05, 0.11, 0.06), Vector3(0.0, -0.065, 0.06), metal, Vector3(12.0, 0.0, 0.0)) # báng
	_gun_models["sniper"] = sn
	_flash_z["sniper"] = _flash_z.get("sniper", -0.82)
	set_weapon("pistol", false)
	_sw.pos.x = sword_pivot.position
	_sw.rot.x = sword_pivot.rotation_degrees
	_gn.pos.x = gun_pivot.position
	_gn.rot.x = gun_pivot.rotation_degrees
	_sw.base_k = pow(float(V["sword_pose_blend"]), 2.0)
	_gn.base_k = pow(float(V["state_blend"]), 2.0)
	_apply()


## Chọn súng hiển thị + hoạt ảnh rút súng (hạ xuống rồi nâng lên, ease-out + lò xo nảy nhẹ).
func set_weapon(id: String, animate: bool = true) -> void:
	if not _gun_models.has(id):
		return
	for k in _gun_models:
		(_gun_models[k] as Node3D).visible = (k == id)
	muzzle_flash.position.z = float(_flash_z[id])
	weapon_id = id
	if animate and is_inside_tree():
		var up: float = float(Global.WEAPONS[id]["draw"]) if Global.WEAPONS.has(id) else 0.3
		var dr: Dictionary = Global.VIEWMODEL["weapon_draw"].get(id, Global.VIEWMODEL["weapon_draw"]["pistol"])
		_gn.pos.x = _gun_rest_pos + Vector3(dr["pos"])
		_gn.rot.x = Vector3(dr["rot"])
		_gn.pos.v = Vector3.ZERO
		_gn.rot.v = Vector3.ZERO
		var dk: float = float(Global.tv("draw_k"))
		# Lên tới, vượt nhẹ ("over") rồi về nền; tổng thời gian = thời gian rút của súng.
		_gn.start("draw", [
			{"d": up * 0.7, "pos": _gun_rest_pos + Vector3(dr["over"]), "rot": Vector3.ZERO, "ease": "out", "k": dk},
			{"d": up * 0.3, "base": true, "ease": "io", "k": dk},
		], 0.0)
		_apply()


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
## M42: kiếm low poly từ Blender (.glb): gốc ở giữa chuôi, lưỡi về -Z. Trả về false (-> dùng khối cũ) khi tắt hoặc thiếu file.
func _add_lowpoly_sword(parent: Node3D) -> bool:
	if not bool(Global.LOWPOLY["enabled"]) or not ResourceLoader.exists(String(Global.LOWPOLY["sword"])):
		return false
	var scene := load(String(Global.LOWPOLY["sword"])) as PackedScene
	if scene == null:
		return false
	var blade: Node3D = scene.instantiate()
	blade.name = "LowPolySword"
	parent.add_child(blade)
	for mi in blade.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return true


## M43: súng low poly (.glb) đặt dưới `parent`. Phần cử động (Mag/Pump/Cap/Bolt) tìm theo tên, `muzzle` cho z chớp lửa.
## Trả về false (-> dùng khối cũ) khi tắt hoặc thiếu file.
func _add_lowpoly_gun(id: String, parent: Node3D) -> bool:
	if not bool(Global.LOWPOLY["enabled"]) or not Global.LOWPOLY["guns"].has(id):
		return false
	var path: String = String(Global.LOWPOLY["guns"][id])
	if not ResourceLoader.exists(path):
		return false
	var scene := load(path) as PackedScene
	if scene == null:
		return false
	var model: Node3D = scene.instantiate()
	model.name = "LowPoly"
	parent.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mz: Node3D = model.get_node_or_null("muzzle")
	if mz != null:
		_flash_z[id] = mz.position.z
	var anim_name: String = String(_LOWPOLY_ANIM[id])
	var node: Node3D = model.get_node_or_null(anim_name)
	if node != null:
		_anim_parts[id] = {"node": node, "pos": node.position, "rot": node.rotation_degrees}
	return true


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
## Trả về các ngón (4 ngón + ngón cái) để đổi dáng theo vật cầm / hành động (xem `_update_fingers`).
func _hand(parent: Node3D, at: Vector3, mat: Material, grip_thick: bool) -> Array:
	var w: float = 0.075 if grip_thick else 0.07
	var fingers: Array = []
	_part(parent, Vector3(w, 0.085, 0.08), at + Vector3(0.0, 0.0, 0.025), mat)               # lòng bàn tay
	for i in 4:
		fingers.append(_part(parent, Vector3(w + 0.012, 0.02, 0.026), at + Vector3(0.0, 0.03 - 0.021 * i, -0.03), mat))  # ngón tay
	fingers.append(_part(parent, Vector3(0.026, 0.03, 0.06), at + Vector3(-0.045, 0.02, -0.01), mat, Vector3(0.0, 15.0, 0.0))) # ngón cái
	for f in fingers:
		(f as MeshInstance3D).set_meta("rest_rot", (f as MeshInstance3D).rotation_degrees)
		(f as MeshInstance3D).set_meta("rest_pos", (f as MeshInstance3D).position)
	return fingers


## Bóp tay: curl 0 = nắm hờ, 1 = siết. Ngón trỏ tay súng duỗi sẵn (chạm cò) rồi bóp khi bắn; các ngón khác siết dần.
func _update_fingers(fingers: Array, curl: float, trigger: bool) -> void:
	var deg: float = float(Global.tv("grip_curl_deg"))
	for i in fingers.size():
		var f := fingers[i] as MeshInstance3D
		var base: Vector3 = f.get_meta("rest_rot", Vector3.ZERO)
		var shift: Vector3 = f.get_meta("rest_pos", Vector3.ZERO)
		if i == 0 and trigger:
			f.rotation_degrees = base + Vector3(-14.0 + (14.0 + deg) * curl, 0.0, 0.0)   # ngón trỏ: duỗi -> bóp cò
			f.position = shift + Vector3(0.0, 0.0, -0.012 * (1.0 - curl))
		elif i < 4:
			f.rotation_degrees = base + Vector3(deg * curl * (0.7 + 0.1 * i), 0.0, 0.0)
			f.position = shift
		else:
			f.rotation_degrees = base + Vector3(0.0, -deg * 0.5 * curl, 0.0)
			f.position = shift


## Cánh tay hai khớp: vai cố định trong không gian viewmodel, cổ tay = điểm bám trên vật cầm (con của pivot).
## Mỗi frame giải IK để khuỷu nằm về phía `pole`; hai đoạn (cánh tay trên, cẳng tay) là hai hộp nối vai-khuỷu-cổ tay.
func _make_arm(pivot: Node3D, wrist_local: Vector3, shoulder: Vector3, pole: Vector3, mat: Material) -> Dictionary:
	var upper := MeshInstance3D.new()
	var fore := MeshInstance3D.new()
	var l1: float = float(Global.VIEWMODEL["upper_arm"])
	var l2: float = float(Global.VIEWMODEL["fore_arm"])
	upper.mesh = _box(Vector3(0.095, 0.085, l1))
	fore.mesh = _box(Vector3(0.08, 0.07, l2))
	for mi in [upper, fore]:
		(mi as MeshInstance3D).material_override = mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	return {"pivot": pivot, "wrist_local": wrist_local, "shoulder": shoulder, "pole": pole.normalized(),
		"upper": upper, "fore": fore, "l1": l1, "l2": l2, "elbow": Vector3.ZERO, "wrist": Vector3.ZERO}


## Đặt hộp `m` nối a -> b (trục -Z của hộp chạy từ a tới b).
func _span(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d: Vector3 = b - a
	if d.length() < 0.0001:
		return
	var up: Vector3 = Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	m.transform = Transform3D(Basis.looking_at(d.normalized(), up), (a + b) * 0.5)


## Giải IK hai khớp (định lý cos): trả về vị trí khuỷu cho vai s, cổ tay w, độ dài l1/l2, khuỷu hướng về `pole`.
static func solve_two_bone(s: Vector3, w: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var d: Vector3 = w - s
	var dist: float = maxf(d.length(), 0.0001)
	var dir: Vector3 = d / dist
	var reach: float = clampf(dist, absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var a: float = (l1 * l1 - l2 * l2 + reach * reach) / (2.0 * reach)
	var h: float = sqrt(maxf(l1 * l1 - a * a, 0.0))
	var pd: Vector3 = pole - dir * pole.dot(dir)
	pd = pd.normalized() if pd.length() > 0.0001 else Vector3.DOWN
	return s + dir * a + pd * h


func _update_arm(arm: Dictionary) -> void:
	if arm.is_empty():
		return
	var pivot: Node3D = arm["pivot"]
	var wrist: Vector3 = pivot.transform * Vector3(arm["wrist_local"])
	var s: Vector3 = arm["shoulder"]
	var elbow: Vector3 = solve_two_bone(s, wrist, float(arm["l1"]), float(arm["l2"]), Vector3(arm["pole"]))
	arm["elbow"] = elbow
	arm["wrist"] = wrist
	_span(arm["upper"], s, elbow)
	_span(arm["fore"], elbow, wrist)


## Sai số bàn tay-cổ tay (m): đầu cẳng tay so với điểm bám trên vật cầm. Dùng trong test: phải ~0 khi tay với tới được.
func arm_error(which: String) -> float:
	var arm: Dictionary = _sword_arm if which == "sword" else _gun_arm
	var fore: MeshInstance3D = arm["fore"]
	var tip: Vector3 = fore.transform * Vector3(0.0, 0.0, -float(arm["l2"]) * 0.5)
	return tip.distance_to(Vector3(arm["wrist"]))


# ------------------------------------------------------------------ lớp nền

## Chuột xoay: vũ khí bị "hất" lệch rồi lò xo kéo về (có nảy nhẹ). relative = Vector2 pixel.
func add_look(relative: Vector2) -> void:
	var V: Dictionary = Global.VIEWMODEL
	var imp: float = float(Global.tv("sway_impulse"))
	_rot_spring.v.x += relative.y * imp
	_rot_spring.v.y += relative.x * imp


## Mỗi bước chân (nối Signal footstep của người chơi, đúng nhịp âm bước chân): tay nhún một nhịp, nghiêng luân phiên trái/phải.
func footstep(_speed: float = 0.0) -> void:
	var V: Dictionary = Global.VIEWMODEL
	var inten: float = clampf(float(Global.settings.get("bob", 1.0)), 0.0, 1.5)
	_pos_spring.v.y -= float(Global.tv("step_impulse")) * inten
	_rot_spring.v.z += _step_side * float(Global.tv("step_roll")) * inten * 10.0
	_step_side = -_step_side


## Tư thế nền theo trọng số trạng thái: trả về [vị trí kiếm, góc kiếm, vị trí súng, góc súng, tp, tr, tổng trọng số].
func _compose_base(speed: float, grounded: bool, inten: float) -> Array:
	var V: Dictionary = Global.VIEWMODEL
	var sp: Vector3 = _sword_rest_pos
	var sr: Vector3 = _sword_rest
	var gp: Vector3 = _gun_rest_pos
	var gr: Vector3 = Vector3.ZERO
	var tp: Vector3 = Vector3.ZERO
	var tr: Vector3 = Vector3.ZERO
	var total: float = 0.0
	var poses: Dictionary = V["sword_pose"]
	var gposes: Dictionary = V["gun_pose"]
	var body: Dictionary = V["body_pose"]
	for s in _w:
		var e: float = ease_u("io", float(_w[s]))
		if e <= 0.0:
			continue
		total += e
		if poses.has(s):
			sp += Vector3(poses[s]["pos"]) * inten * e
			sr += (Vector3(poses[s]["rot"]) - _sword_rest) * inten * e
		if gposes.has(s):
			gp += Vector3(gposes[s]["pos"]) * inten * e
			gr += Vector3(gposes[s]["rot"]) * inten * e
		if body.has(s):
			tp += Vector3(body[s]["pos"]) * inten * e
			tr += Vector3(body[s]["rot"]) * inten * e
	# Thở khi đứng yên, hạ kiếm về trước khi chạy nhanh; mờ dần khi đang ở tư thế trạng thái.
	var free: float = clampf(1.0 - total, 0.0, 1.0)
	var run_k: float = clampf(speed / float(V["bob_speed_ref"]), 0.0, 1.0) if grounded else 0.0
	var sway: float = float(V["idle_sway"]) * inten * (1.0 - run_k) * free
	sr += Vector3(sin(_t * 1.7) * sway - float(V["sprint_lean"]) * run_k * inten * free, 0.0, cos(_t * 1.1) * sway)
	sp += Vector3(0.0, sin(_t * 1.7) * 0.006 * inten * free, 0.0)
	return [sp, sr, gp, gr, tp, tr, total]


## Gọi mỗi frame hiển thị. st: "" | "slide" | "dash" | "wallrun" | "grapple" (cùng quy ước hoạt ảnh thân).
func update(delta: float, speed: float, grounded: bool, st: String = "", lateral: float = 0.0, fall_speed: float = 0.0) -> void:
	var V: Dictionary = Global.VIEWMODEL
	_driven = true
	_la = [speed, grounded, st, lateral]
	state_name = st
	# Nhún theo bước chạy: biên độ tăng theo tốc độ, chỉ khi đứng đất.
	var amp: float = clampf(speed / float(V["bob_speed_ref"]), 0.0, 1.5) if grounded else 0.0
	_bob_phase = fmod(_bob_phase + speed * delta * float(V["bob_freq"]) * TAU, TAU * 100.0)
	bob_offset = Vector3(cos(_bob_phase * 0.5) * float(V["bob_side"]) * amp, absf(sin(_bob_phase * 0.5)) * float(V["bob_amp"]) * amp * -1.0, 0.0)
	# Tiếp đất: đẩy một xung xuống, lò xo nảy lại.
	if grounded and not _was_grounded:
		# Rơi càng nhanh càng mạnh: tay đập xuống, nòng chúi theo (M29).
		var hard: float = clampf(fall_speed / 12.0, 0.0, 2.0) * float(Global.tv("land_fall_gain"))
		_pos_spring.v.y -= float(Global.tv("land_impulse")) * (1.0 + hard)
		_rot_spring.v.x += 14.0 * hard
	_was_grounded = grounded
	# Trọng số trạng thái trượt mượt về 1 (trạng thái hiện tại) / 0 (còn lại): đổi trạng thái là cross-fade.
	var fade: float = maxf(float(Global.tv("state_fade")), 0.01)
	for s in _w:
		_w[s] = move_toward(float(_w[s]), 1.0 if s == st else 0.0, delta / fade)
	var inten: float = clampf(float(Global.settings.get("bob", 1.0)), 0.0, 1.5)
	var base: Array = _compose_base(speed, grounded, inten)
	var tp: Vector3 = base[4]
	var tr: Vector3 = base[5]
	# Đi ngang: nghiêng cả tay theo hướng bước.
	tr.z += -clampf(lateral, -1.0, 1.0) * float(V["strafe_roll"]) * inten * (1.0 if grounded else 0.4)
	_t += delta
	_pos_spring.step(delta, tp, float(Global.tv("spring_k")), float(Global.tv("spring_c")))
	_rot_spring.step(delta, tr, float(Global.tv("rot_spring_k")), float(Global.tv("rot_spring_c")))
	var m: float = float(V["sway_max"])
	_rot_spring.x.x = clampf(_rot_spring.x.x, tr.x - m, tr.x + m)
	_rot_spring.x.y = clampf(_rot_spring.x.y, tr.y - m, tr.y + m)
	position = bob_offset + _pos_spring.x
	rotation_degrees = _rot_spring.x
	# Kiếm và súng: clip (nếu có) đặt đích, lò xo bám theo; hết clip thì đích = tư thế nền.
	var sw_done: bool = _sw.step(delta, base[0], base[1])
	_gn.step(delta, base[2], base[3])
	var kk: float = pow(4.0 / maxf(float(V["kick_time"]) * float(_weapon_kick()["time"]), 0.02), 2.0)
	_kick_spring.step(delta, Vector3.ZERO, kk, 2.0 * sqrt(kk) * float(Global.tv("kick_zeta")))
	# Bóp tay theo hành động (mượt): súng siết theo độ giật, kiếm siết khi chém/đỡ.
	var back_ref: float = maxf(float(Global.tv("kick_back")) * float(_weapon_kick()["back"]), 0.001)
	var gt: float = clampf(_kick_spring.x.z / back_ref, 0.0, 1.0)
	_gun_curl = lerpf(_gun_curl, maxf(gt, 0.5 if reloading else 0.0), 1.0 - exp(-delta * 25.0))
	_sword_curl = lerpf(_sword_curl, 1.0 if _sw.active() else 0.15, 1.0 - exp(-delta * 18.0))
	_update_fingers(_gun_fingers, _gun_curl, true)
	_update_fingers(_sword_fingers, _sword_curl, false)
	_update_parts(delta)
	if sw_done or not _sw.active():
		_run_queued()
	elif _sw.queued.is_valid() and _sw.t >= _sw.cancel_from:
		_run_queued()
	_apply()
	if Global.anim_debug:
		Global.anim_debug_text = debug_info()
		var smp: PackedFloat32Array = Global.anim_debug_samples
		smp.append(sword_pivot.position.distance_to(_sword_rest_pos))
		smp.append(sword_pivot.rotation_degrees.distance_to(_sword_rest) / 90.0)
		if smp.size() > 480:
			smp = smp.slice(smp.size() - 480)
		Global.anim_debug_samples = smp
	# Chớp nòng tắt sau flash_time.
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			muzzle_flash.visible = false
			_flash_light.visible = false


## Đứng một mình (test, màn xem trước): nếu chủ nhân không gọi update() trong frame, tự chạy với tham số lần cuối.
func _process(delta: float) -> void:
	if _driven:
		_driven = false
		return
	update(delta, float(_la[0]), bool(_la[1]), String(_la[2]), float(_la[3]))
	_driven = false


## Ghi tư thế lò xo xuống node (gọi sau mỗi lần lò xo đổi, kể cả xung tức thời như giật súng).
func _apply() -> void:
	sword_pivot.position = _sw.pos.x
	sword_pivot.rotation_degrees = _sw.rot.x
	gun_pivot.position = _gn.pos.x + Vector3(0.0, 0.0, _kick_spring.x.z)
	gun_pivot.rotation_degrees = _gn.rot.x + Vector3(_kick_spring.x.x, 0.0, 0.0)
	_update_arm(_sword_arm)
	_update_arm(_gun_arm)


# ------------------------------------------------------------------ chiến đấu

## Gửi lệnh cho lớp kiếm. Nếu clip đang chạy chưa tới cửa sổ hủy thì xếp hàng (1 lệnh, lệnh mới thay lệnh cũ).
func _sword_command(cmd_name: String, fn: Callable, immediate: bool = false) -> void:
	if immediate or not _sw.active() or _sw.t >= _sw.cancel_from:
		_sw.queued = Callable()
		pending_command = ""
		fn.call()
	else:
		_sw.queued = fn
		pending_command = cmd_name


func _run_queued() -> void:
	if _sw.queued.is_valid():
		var fn: Callable = _sw.queued
		_sw.queued = Callable()
		pending_command = ""
		fn.call()


func play_swing(windup: float, active: float, recovery: float) -> void:
	_sword_command("swing", func(): _start_swing(windup, active, recovery))


## Windup (anticipation): kéo kiếm ra sau, ease-out + nín nhẹ ở đỉnh; active: tăng tốc mạnh rồi dừng đột ngột;
## follow-through: lướt thêm một chút rồi mới thu về (lò xo góc trễ hơn lò xo vị trí nên cổ tay "quất").
func _start_swing(windup: float, active: float, recovery: float) -> void:
	var V: Dictionary = Global.VIEWMODEL
	var back: Vector3 = _sword_rest_pos + Vector3(0.1, 0.06, 0.18)
	var fwd: Vector3 = _sword_rest_pos + Vector3(-0.2, -0.04, -0.28)
	var kw: float = float(Global.tv("swing_windup_k"))
	var keys: Array = [
		{"d": windup * 0.8, "pos": back, "rot": Vector3(88.0, 45.0, -35.0), "ease": "out", "k": kw},
		{"d": windup * 0.2, "pos": back + Vector3(0.012, 0.008, 0.025), "rot": Vector3(90.0, 47.0, -36.0), "ease": "lin", "k": kw},
		{"d": active, "pos": fwd, "rot": Vector3(0.0, -55.0, -22.0), "ease": "in", "k": float(Global.tv("swing_active_k"))},
		{"d": recovery * 0.3, "pos": fwd + Vector3(-0.03, -0.015, -0.05), "rot": Vector3(-6.0, -62.0, -24.0), "ease": "out", "k": float(Global.tv("swing_follow_k"))},
		{"d": recovery * 0.7, "base": true, "ease": "io", "k": float(Global.tv("swing_recover_k"))},
	]
	_sw.start("swing", keys, windup + active)


## Parry: rút kiếm lên đỡ — bật nhanh, giữ trong cửa sổ parry (nín nhẹ), rồi hạ xuống.
func raise() -> void:
	_sword_command("raise", func(): _start_raise())


func _start_raise() -> void:
	var V: Dictionary = Global.VIEWMODEL
	var tin: float = float(V["guard_in"])
	var gp: Vector3 = Vector3(V["guard_pos"])
	var gr: Vector3 = Vector3(V["guard_rot"])
	var keys: Array = [
		{"d": tin, "pos": gp, "rot": gr, "ease": "out", "k": float(Global.tv("guard_k"))},
		{"d": float(Global.COMBAT["parry_window"]), "pos": gp + Vector3(0.0, 0.006, 0.012), "rot": gr + Vector3(-1.5, 1.0, 0.0), "ease": "lin", "k": float(Global.tv("guard_hold_k"))},
		{"d": 0.18, "base": true, "ease": "io", "k": float(Global.tv("swing_recover_k"))},
	]
	_sw.start("parry", keys, tin + 0.04)


## Parry thành công: cú đẩy kiếm ra trước (phản lực) + giật nhẹ; kiếm bật ra ngoài rồi thu về (clip, ngắt ngay).
func parry_hit() -> void:
	_blade_flash()
	_pos_spring.v += Vector3(0.0, 0.2, -1.8)
	_rot_spring.v += Vector3(-60.0, 0.0, 0.0)
	_sword_command("parry_hit", func(): _start_deflect(), true)


## Chớp sáng ngắn trên lưỡi kiếm lúc bật (M28). Không có khi giảm hiệu ứng.
func _blade_flash() -> void:
	if Global.reduced_fx or sword_pivot == null:
		return
	if _blade_light == null:
		return
	_blade_light.visible = true
	_blade_light.light_energy = float(Global.ta("pf_flash_energy"))
	if _blade_tween != null and _blade_tween.is_valid():
		_blade_tween.kill()
	_blade_tween = _blade_light.create_tween()
	_blade_tween.tween_property(_blade_light, "light_energy", 0.0, 0.12)
	_blade_tween.tween_callback(func(): _blade_light.visible = false)


func _start_deflect() -> void:
	var V: Dictionary = Global.VIEWMODEL
	var gp: Vector3 = Vector3(V["guard_pos"])
	var gr: Vector3 = Vector3(V["guard_rot"])
	var keys: Array = [
		{"d": 0.07, "pos": gp + Vector3(0.06, 0.04, -0.16), "rot": gr + Vector3(-10.0, 16.0, -10.0), "ease": "out", "k": float(Global.tv("guard_k"))},
		{"d": 0.28, "base": true, "ease": "io", "k": float(Global.tv("swing_recover_k"))},
	]
	_sw.start("parry_hit", keys, 0.12)


## Hai kiếm chạm nhau (clash): kiếm bị hất lên/ra, cả viewmodel bị đẩy lùi theo hướng đẩy (direction theo hệ camera, hướng AWAY khỏi đối thủ).
func clash(direction: Vector3) -> void:
	var V: Dictionary = Global.VIEWMODEL
	var f: float = float(Global.tv("clash_impulse"))
	_pos_spring.v += Vector3(clampf(direction.x, -1.0, 1.0) * f * 0.6, f * 0.15, absf(direction.z) * f + f * 0.4)
	_rot_spring.v += Vector3(-40.0, clampf(direction.x, -1.0, 1.0) * 40.0, 0.0)
	var keys: Array = [
		{"d": 0.06, "pos": _sword_rest_pos + Vector3(-0.1, 0.12, 0.12), "rot": Vector3(104.0, 30.0, -32.0), "ease": "out", "k": float(Global.tv("guard_k"))},
		{"d": 0.4, "base": true, "ease": "elastic", "k": float(Global.tv("parry_fail_k"))},
	]
	_sword_command("clash", func(): _sw.start("clash", keys, 0.15), true)


## Parry hụt: kiếm bị hất xuống thấp rồi loạng choạng nảy đàn hồi về lại. Luôn ngắt được clip hiện tại.
func parry_fail() -> void:
	_sword_command("parry_fail", func(): _start_parry_fail(), true)


func _start_parry_fail() -> void:
	var V: Dictionary = Global.VIEWMODEL
	var keys: Array = [
		{"d": 0.08, "pos": _sword_rest_pos + Vector3(-0.05, -0.2, 0.1), "rot": Vector3(25.0, 30.0, -35.0), "ease": "out", "k": float(Global.tv("guard_k"))},
		{"d": 0.45, "base": true, "ease": "elastic", "k": float(Global.tv("parry_fail_k"))},
	]
	_sw.start("parry_fail", keys, 0.3)
	_pos_spring.v += Vector3(0.0, -0.8, 0.5)


## Súng giật lùi + hất nòng + chớp nòng: xung tức thời vào lò xo giật, tự hồi về (nảy nhẹ).
func kick() -> void:
	if reloading:
		return
	var V: Dictionary = Global.VIEWMODEL
	var wk: Dictionary = _weapon_kick()
	var back: float = float(Global.tv("kick_back")) * float(wk["back"])
	var pitch: float = float(Global.tv("kick_pitch")) * float(wk["pitch"])
	_kick_spring.x = Vector3(minf(_kick_spring.x.x + pitch, pitch * 1.6), 0.0, minf(_kick_spring.x.z + back, back * 1.6))
	_kick_spring.v = Vector3.ZERO
	muzzle_flash.visible = true
	muzzle_flash.rotation.z = randf() * TAU
	muzzle_flash.scale = Vector3.ONE * randf_range(1.0, 1.7)
	_flash_light.visible = not Global.reduced_fx
	_flash_light.light_energy = float(V["flash_light"])
	_flash_t = float(V["flash_time"])
	_apply()


## Nạp đạn riêng từng súng (M29). Tổng thời gian các khoá = WEAPONS[id]["reload"] (không đổi nhịp chơi).
## on=false (xong/hủy) đưa về mượt.
func set_reloading(on: bool) -> void:
	var V: Dictionary = Global.VIEWMODEL
	if on:
		reloading = true
		var total: float = float(Global.WEAPONS[weapon_id]["reload"])
		_gn.start("reload", _reload_keys(weapon_id, total), 0.0)
	else:
		reloading = false
		_gn.start("reload_cancel", [{"d": 0.12, "base": true, "ease": "out", "k": float(Global.tv("reload_k")) * 3.0}], 0.0)


## Các bước nạp: [trọng số thời gian, lệch vị trí so với "low", góc, nhân độ cứng]. Bộ phận súng (băng/ống trượt/khoá nòng/nắp) chạy theo `_update_parts`.
static func reload_steps(id: String) -> Array:
	match id:
		"shotgun":   # mở, nhét 2 viên, đóng, kéo ống trượt
			return [
				[0.2, Vector3(0.0, 0.03, 0.0), Vector3(-32.0, 0.0, 38.0), 1.0],
				[0.2, Vector3(0.02, -0.03, 0.0), Vector3(-40.0, 0.0, 30.0), 1.5],
				[0.2, Vector3(0.02, -0.03, 0.0), Vector3(-42.0, 0.0, 32.0), 1.5],
				[0.15, Vector3(0.0, 0.04, 0.0), Vector3(-20.0, 0.0, 12.0), 1.0],
				[0.25, Vector3(0.0, 0.06, -0.06), Vector3(-8.0, 0.0, 5.0), 1.4],
			]
		"launcher":  # mở nắp miệng ống, nhét đạn, đóng
			return [
				[0.25, Vector3(0.05, 0.1, 0.0), Vector3(-30.0, 0.0, 40.0), 1.0],
				[0.35, Vector3(0.0, 0.12, 0.02), Vector3(-20.0, 0.0, 45.0), 1.2],
				[0.2, Vector3(0.0, 0.06, 0.0), Vector3(-35.0, 0.0, 25.0), 1.0],
				[0.2, Vector3(0.0, 0.0, 0.0), Vector3(-40.0, 0.0, 25.0), 1.0],
			]
		"sniper":    # nghiêng, kéo khoá, nhét đạn, đẩy khoá
			return [
				[0.2, Vector3(0.0, 0.04, 0.0), Vector3(-25.0, 0.0, 50.0), 1.0],
				[0.25, Vector3(0.0, 0.05, 0.05), Vector3(-25.0, 0.0, 55.0), 1.3],
				[0.3, Vector3(0.0, -0.03, 0.02), Vector3(-35.0, 0.0, 45.0), 1.5],
				[0.25, Vector3(0.0, 0.0, 0.0), Vector3(-30.0, 0.0, 40.0), 1.0],
			]
	return [   # súng lục: tháo băng, nhét băng mới, lên nòng
		[0.35, Vector3(0.0, 0.02, 0.0), Vector3(-40.0, 0.0, 10.0), 1.0],
		[0.3, Vector3(0.0, -0.045, 0.0), Vector3(-46.0, 0.0, 20.0), 1.6],
		[0.35, Vector3(0.0, 0.0, 0.0), Vector3(-40.0, 0.0, 25.0), 1.0],
	]


func _reload_keys(id: String, total: float) -> Array:
	var V: Dictionary = Global.VIEWMODEL
	var down: float = float(V["reload_down_time"])
	var up: float = float(V["reload_up_time"])
	var hold: float = maxf(total - down - up, 0.0)
	var low: Vector3 = _gun_rest_pos + Vector3(0.0, -0.35, 0.1)
	var rk: float = float(Global.tv("reload_k"))
	var keys: Array = [{"d": down, "pos": low, "rot": Vector3(-40.0, 0.0, 25.0), "ease": "io", "k": rk}]
	for st in reload_steps(id):
		keys.append({"d": hold * float(st[0]), "pos": low + Vector3(st[1]), "rot": Vector3(st[2]), "ease": "io", "k": rk * float(st[3])})
	keys.append({"d": up, "base": true, "ease": "io", "k": rk})
	return keys


## Cửa sổ trơn 0..1 trong [a, b] của tiến độ p.
static func _win(p: float, a: float, b: float) -> float:
	var u: float = clampf((p - a) / maxf(b - a, 0.0001), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## Bộ phận chuyển động của súng đang cầm theo tiến độ nạp (0..1; âm = không nạp, về chỗ cũ).
func _update_parts(delta: float) -> void:
	var p: float = -1.0
	if _gn.clip_name == "reload" and _gn.active():
		p = clampf(_gn.t / maxf(_gn.total(), 0.001), 0.0, 1.0)
	var k: float = 1.0 - exp(-delta * 30.0)
	for id in _anim_parts:
		var d: Dictionary = _anim_parts[id]
		var n: Node3D = d["node"]
		var pos: Vector3 = d["pos"]
		var rot: Vector3 = d["rot"]
		if p >= 0.0 and id == weapon_id:
			match id:
				"pistol":
					pos.y += -0.14 * (_win(p, 0.18, 0.34) - _win(p, 0.5, 0.68))   # băng rơi xuống rồi nhét lại
				"shotgun":
					pos.z += 0.07 * (_win(p, 0.78, 0.88) - _win(p, 0.88, 0.98))  # ống trượt kéo lùi rồi đẩy tới
				"launcher":
					var o: float = _win(p, 0.1, 0.25) - _win(p, 0.75, 0.9)
					rot.x += -75.0 * o
					pos.y += 0.05 * o                                              # nắp miệng ống mở rồi đóng
				"sniper":
					var lift: float = _win(p, 0.2, 0.3) - _win(p, 0.82, 0.9)
					var pull: float = _win(p, 0.3, 0.45) - _win(p, 0.7, 0.82)
					rot.z += 70.0 * lift
					pos.z += 0.08 * pull                                           # khoá nòng nâng, kéo lùi, đẩy tới, hạ
		n.position = n.position.lerp(pos, k)
		n.rotation_degrees = n.rotation_degrees.lerp(rot, k)


## Hệ số giật của súng đang cầm.
func _weapon_kick() -> Dictionary:
	var wk: Dictionary = Global.VIEWMODEL["weapon_kick"]
	return wk.get(weapon_id, wk["pistol"])


## Leo gờ xong: vũ khí bị nhấc lên và nòng hất lên một nhịp (nối Signal ledge_climbed).
func ledge() -> void:
	var f: float = float(Global.tv("ledge_impulse"))
	_pos_spring.v += Vector3(0.0, 0.6, 0.35) * f
	_rot_spring.v.x += -35.0 * f


## Bị đánh: cả viewmodel bị đẩy lùi theo hướng đòn (direction theo hệ tọa độ camera), lò xo kéo về.
func flinch(direction: Vector3) -> void:
	var f: float = float(Global.tv("flinch_impulse"))
	_pos_spring.v += Vector3(clampf(direction.x, -1.0, 1.0) * f * 0.7, -f * 0.35, f)


## Hồi sinh: xóa mọi hiệu ứng đang chạy, về tư thế nghỉ.
func reset() -> void:
	reloading = false
	_pos_spring = Spring.new()
	_rot_spring = Spring.new()
	_kick_spring = Spring.new()
	_sw.clear()
	_gn.clear()
	_sw.settle_k = _sw.base_k
	_gn.settle_k = _gn.base_k
	_sw.pos = Spring.new()
	_sw.rot = Spring.new()
	_gn.pos = Spring.new()
	_gn.rot = Spring.new()
	_sw.pos.x = _sword_rest_pos
	_sw.rot.x = _sword_rest
	_gn.pos.x = _gun_rest_pos
	_gn.rot.x = Vector3.ZERO
	_gun_curl = 0.0
	_sword_curl = 0.0
	for id in _anim_parts:
		var d: Dictionary = _anim_parts[id]
		(d["node"] as Node3D).position = d["pos"]
		(d["node"] as Node3D).rotation_degrees = d["rot"]
	for s in _w:
		_w[s] = 0.0
	pending_command = ""
	muzzle_flash.visible = false
	_flash_light.visible = false
	_apply()


## Chuỗi gỡ lỗi: clip + pha hiện tại của kiếm/súng và trọng số trạng thái (hiện trong lớp phủ F3 khi bật Global.ANIM["debug"]).
func debug_info() -> String:
	var ws: String = ""
	for s in _w:
		if float(_w[s]) > 0.01:
			ws += " %s=%.2f" % [s, float(_w[s])]
	return "VM sword[%s %.2f] gun[%s %.2f] st=%s%s%s" % [_sw.phase_name if _sw.active() else "base", _sw.phase_u, _gn.phase_name if _gn.active() else "base", _gn.phase_u, state_name, ws, (" queue=" + pending_command) if pending_command != "" else ""]
