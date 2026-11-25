extends Node
## Điều khiển chiến đấu của người chơi: kiếm (thường + chém rộng), 4 súng (súng lục, shotgun,
## pháo nổ, bắn tỉa), parry, nạp đạn, đổi súng. Mỗi súng có băng đạn riêng.
## Input nằm ở các field want_* (Player điền từ Input; test headless tự điền).

const RocketScript = preload("res://scripts/rocket.gd")
const GunFlawsScript = preload("res://scripts/gun_flaws.gd")

signal ammo_changed(current: int, maximum: int)
signal shot_fired(from: Vector3, to: Vector3)
signal hit_confirmed(landed: bool)
signal reloading_changed(on: bool)
signal weapon_changed(id: String, display_name: String)
signal exploded(position: Vector3, radius: float)
signal self_impulse(velocity_delta: Vector3)   # lỗi giật bật người: Player cộng vào vận tốc
signal charge_changed(ratio: float)               # lỗi nạp ngắm: 0..1 (0 = không nạp)
signal flaw_changed(spread_deg: float, max_deg: float)   # lỗi súng đang cầm đổi (HUD vẽ chấm ngắm nở)

var want_attack: bool = false  # giữ
var want_shoot: bool = false   # giữ
var want_zoom: bool = false    # giữ (bắn tỉa)
var want_parry: bool = false   # xung 1 lần
var want_reload: bool = false  # xung 1 lần
var want_heavy: bool = false   # xung 1 lần: chém rộng
var want_weapon: int = -1      # xung: chọn súng theo chỉ số (0..3)
var want_cycle: int = 0        # xung: +1 súng kế, -1 súng trước

var weapon: String = "pistol"
var reloading: bool = false
var ammo: int:
	get:
		return int(_ammo.get(weapon, 0))
	set(v):
		_ammo[weapon] = v

## Hệ số nâng cấp (M35; main áp từ RunProgress). 1.0 = không đổi.
var damage_mult: float = 1.0
var fire_rate_mult: float = 1.0
var mag_mult: float = 1.0
var reload_mult: float = 1.0

## Lỗi riêng của súng (M36) + hệ số riêng theo súng từ nâng cấp: "<id>_damage_mult", "<id>_pierce".
var flaws = GunFlawsScript.new()
var weapon_mods: Dictionary = {}
var locked: bool = false          # Vô Tận: một súng mỗi lượt, tắt đổi súng
var move_mult: float = 1.0        # hệ số tốc độ chạy do lỗi (nạp ngắm); Player nhân vào
var _charge: float = 0.0
var _charge_lock: bool = false
var _last_spread: float = -1.0
var _air_time: float = 0.0        # M38 Nạp bằng cú nhảy: giây đã bay liên tục
var _marks: Dictionary = {}       # M38 Tia đánh dấu: hurtbox -> giây còn lại
var _chain_t: float = 0.0         # M38 Săn liên hoàn: giây còn được bắn không cần nạp ngắm
var _super: bool = false          # M38 Nạp thêm: phát đang bắn là siêu đạn

var _ammo: Dictionary = {}
var _head: Node3D
var _body: Node3D
var _melee: Node
var _parry: Node
var _shot_cd: float = 0.0
var _reload_t: float = 0.0


func setup(p_body: Node3D, p_head: Node3D, p_melee: Node, p_parry: Node) -> void:
	_body = p_body
	_head = p_head
	_melee = p_melee
	_parry = p_parry
	for id in Global.WEAPON_ORDER:
		_ammo[id] = int(Global.WEAPONS[id]["mag"])


func cfg() -> Dictionary:
	return Global.WEAPONS[weapon]


func max_ammo() -> int:
	return maxi(roundi(float(cfg()["mag"]) * mag_mult), 1)


func is_zooming() -> bool:
	return want_zoom and weapon == "sniper" and not reloading


## FOV khi ngắm; 0 nếu không zoom.
func zoom_fov() -> float:
	return float(cfg().get("zoom_fov", 0.0)) if is_zooming() else 0.0


func refill() -> void:
	for id in Global.WEAPON_ORDER:
		_ammo[id] = int(Global.WEAPONS[id]["mag"])
	if reloading:
		reloading_changed.emit(false)
	reloading = false
	_shot_cd = 0.0
	ammo_changed.emit(ammo, max_ammo())


func switch_to(id: String) -> void:
	if id == weapon or not Global.WEAPONS.has(id):
		return
	if reloading:
		reloading = false
		reloading_changed.emit(false)
	_cancel_charge()
	weapon = id
	_last_spread = -1.0
	_shot_cd = float(cfg()["draw"]) # thời gian rút súng
	weapon_changed.emit(id, String(cfg()["name"]))
	ammo_changed.emit(ammo, max_ammo())


func _physics_process(delta: float) -> void:
	_shot_cd = maxf(_shot_cd - delta, 0.0)
	flaws.tick(delta)
	_emit_flaw()
	_tick_perks(delta)
	if reloading:
		_reload_t -= delta
		if _reload_t <= 0.0:
			reloading = false
			reloading_changed.emit(false)
			ammo = max_ammo()
			ammo_changed.emit(ammo, max_ammo())

	if want_weapon >= 0 and want_weapon < Global.WEAPON_ORDER.size() and not locked:
		switch_to(Global.WEAPON_ORDER[want_weapon])
	if want_cycle != 0 and not locked:
		var n: int = Global.WEAPON_ORDER.size()
		var i: int = Global.WEAPON_ORDER.find(weapon)
		switch_to(Global.WEAPON_ORDER[posmod(i + want_cycle, n)])

	var blocked: bool = _melee.is_staggered()
	if want_parry and not blocked:
		_parry.press()
	if want_heavy and not blocked:
		_melee.try_swing(true)
	elif want_attack and not blocked:
		_melee.try_swing()
	if want_reload:
		_start_reload()
	_handle_shoot(delta, blocked)
	want_parry = false
	want_reload = false
	want_heavy = false
	want_weapon = -1
	want_cycle = 0


## Phát flaw_changed khi độ lệch đổi (làm tròn 0.05 độ để không phát mỗi khung hình khi đứng yên).
func _emit_flaw() -> void:
	var sp: float = snappedf(flaws.spread(weapon), 0.05)
	if is_equal_approx(sp, _last_spread):
		return
	_last_spread = sp
	flaw_changed.emit(sp, flaws.max_spread(weapon))


func _airborne() -> bool:
	return _body.has_method("is_on_floor") and not _body.is_on_floor()


func _sliding() -> bool:
	return "state" in _body and _body.state == _body.State.SLIDE


## Thẻ có hiệu ứng theo thời gian: nạp bằng cú nhảy, hết hạn đánh dấu, cửa sổ săn liên hoàn.
func _tick_perks(delta: float) -> void:
	_chain_t = maxf(_chain_t - delta, 0.0)
	for hb in _marks.keys():
		if not is_instance_valid(hb):
			_marks.erase(hb)
			continue
		_marks[hb] = float(_marks[hb]) - delta
		if float(_marks[hb]) <= 0.0:
			hb.damage_taken_mult = 1.0
			_marks.erase(hb)
	if float(weapon_mods.get("shotgun_airreload", 0.0)) > 0.0 and _airborne():
		_air_time += delta
		if _air_time >= float(Global.PERKS["airreload_secs"]):
			_air_time -= float(Global.PERKS["airreload_secs"])
			var cap: int = maxi(roundi(float(Global.WEAPONS["shotgun"]["mag"]) * mag_mult), 1)
			if int(_ammo.get("shotgun", 0)) < cap:
				_ammo["shotgun"] = int(_ammo["shotgun"]) + 1
				if weapon == "shotgun":
					ammo_changed.emit(ammo, max_ammo())
	else:
		_air_time = 0.0


## Hệ số / giá trị nâng cấp riêng của súng đang cầm (vd "damage_mult" -> weapon_mods["pistol_damage_mult"]).
func _wmod(key: String, default: float) -> float:
	return float(weapon_mods.get(weapon + "_" + key, default))


func _start_reload() -> void:
	if reloading or ammo >= max_ammo():
		return
	reloading = true
	_reload_t = float(cfg()["reload"]) / reload_mult
	reloading_changed.emit(true)


## Thời gian giữ cần để nổ phát hiện tại (0 = bắn thường): lỗi nạp ngắm, trừ Săn liên hoàn và Nạp trượt.
func _charge_need() -> float:
	var ct: float = flaws.charge_time(weapon)
	if ct <= 0.0 or _chain_t > 0.0:
		return 0.0
	if _sliding():
		ct *= maxf(1.0 - _wmod("slide", 0.0), 0.2)
	return ct


## Bắn theo súng: thường thì bắn khi giữ; súng có lỗi nạp ngắm thì phải giữ đủ thời gian (thả sớm = huỷ).
## Thẻ Nạp thêm: đủ nạp rồi giữ thêm `overcharge_extra` s thì thành siêu đạn; thả sau khi đủ nạp vẫn nổ phát thường.
func _handle_shoot(delta: float, blocked: bool) -> void:
	var ct: float = _charge_need()
	if ct <= 0.0:
		_cancel_charge()
		if not want_shoot:
			_charge_lock = false   # thả chuột trong cửa sổ săn liên hoàn cũng mở khoá cho lần nạp sau
		elif not blocked:
			_shoot()
		return
	var over: bool = _wmod("overcharge", 0.0) > 0.0
	if not want_shoot:
		_charge_lock = false
		if over and _charge >= ct and not blocked and not reloading and ammo > 0:
			_cancel_charge()
			_shoot()   # thả sau khi đủ nạp: phát thường
		else:
			_cancel_charge()
		return
	if blocked or reloading or _charge_lock or _shot_cd > 0.0:
		_cancel_charge()
		return
	if ammo <= 0:
		_shoot()   # hết đạn: tự nạp
		return
	_charge += delta
	move_mult = 1.0 if (_sliding() and _wmod("slide", 0.0) > 0.0) else flaws.charge_move_mult(weapon)
	var full: float = ct + (float(Global.PERKS["overcharge_extra"]) if over else 0.0)
	charge_changed.emit(minf(_charge / full, 1.0))
	if _wmod("mark", 0.0) > 0.0:
		_mark_target()
	if _charge >= full:
		_cancel_charge()
		_charge_lock = true   # phải thả chuột mới nạp phát sau
		_super = over
		_shoot()
		_super = false


## Tia đánh dấu: bot bị tia laser quét trúng bị nhận thêm sát thương một lúc.
func _mark_target() -> void:
	var hit: Dictionary = _ray(_head.global_position, -_head.global_transform.basis.z, float(cfg()["range"]), [_body])
	if hit.is_empty():
		return
	var hb: Object = hit["collider"]
	if not hb.has_method("take_hit") or not ("damage_taken_mult" in hb) or ("dead" in hb and hb.dead):
		return
	hb.damage_taken_mult = float(Global.PERKS["mark_mult"])
	_marks[hb] = float(Global.PERKS["mark_time"])


func _cancel_charge() -> void:
	if _charge > 0.0 or move_mult != 1.0:
		_charge = 0.0
		move_mult = 1.0
		charge_changed.emit(0.0)


## Đoạn tia laser khi đang nạp ngắm: từ nòng tới điểm trúng (hoặc hết tầm). Presentation đọc để vẽ.
func laser_segment() -> PackedVector3Array:
	var from: Vector3 = _head.global_position
	var dir: Vector3 = -_head.global_transform.basis.z
	var muzzle: Vector3 = from + _head.global_transform.basis * Vector3(-0.3, -0.25, -0.7)
	var hit: Dictionary = _ray(from, dir, float(cfg()["range"]), [_body])
	var to: Vector3 = hit["position"] if not hit.is_empty() else from + dir * float(cfg()["range"])
	return PackedVector3Array([muzzle, to])


func _shoot() -> void:
	if reloading or _shot_cd > 0.0:
		return
	if ammo <= 0:
		_start_reload()
		return
	var c: Dictionary = cfg()
	ammo -= 1
	_shot_cd = float(c["cooldown"]) / fire_rate_mult
	var from: Vector3 = _head.global_position
	var dir: Vector3 = flaws.aim(weapon, -_head.global_transform.basis.z)
	var muzzle: Vector3 = from + _head.global_transform.basis * Vector3(-0.3, -0.25, -0.7)
	var to: Vector3 = from + dir * float(c["range"])
	match String(c["kind"]):
		"pellets":
			if _wmod("shockwave", 0.0) > 0.0:
				_shockwave(from, dir)
			to = _fire_pellets(from, dir, c)
		"explosive":
			_launch_rocket(from, dir, c)
			to = from + dir * 3.0
		_:
			to = _fire_hitscan(from, dir, c)
	flaws.on_shot(weapon)
	_emit_flaw()
	var kick: Vector3 = flaws.knockback(weapon, dir, _body.is_on_floor() if _body.has_method("is_on_floor") else true)
	if kick != Vector3.ZERO:
		self_impulse.emit(kick)
	shot_fired.emit(muzzle, to)
	ammo_changed.emit(ammo, max_ammo())
	if ammo == 0:
		_start_reload()


func _ray(from: Vector3, dir: Vector3, length: float, exclude: Array = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * length, Global.L_WORLD | Global.L_ENEMY_HURT)
	q.collide_with_areas = true
	q.exclude = exclude
	return _head.get_world_3d().direct_space_state.intersect_ray(q)


func _hit(collider: Object, damage: float, dir: Vector3, extra: Dictionary = {}) -> bool:
	if not collider.has_method("take_hit"):
		return false
	var h := {"damage": damage * damage_mult, "kind": "hitscan", "source": _body, "direction": dir}
	h.merge(extra, true)
	return collider.take_hit(h)


## Súng lục / bắn tỉa. Bắn tỉa: headshot nhân sát thương, xuyên 1 mục tiêu với sát thương giảm.
func _fire_hitscan(from: Vector3, dir: Vector3, c: Dictionary) -> Vector3:
	var damage: float = float(c["damage"]) * _wmod("damage_mult", 1.0)
	var pierce: int = int(c.get("pierce", 0)) + int(_wmod("pierce", 0.0))
	if _super:
		damage *= float(Global.PERKS["overcharge_damage"])
		pierce = 99   # siêu đạn xuyên mọi mục tiêu
	var exclude: Array = []
	var end: Vector3 = from + dir * float(c["range"])
	var any_landed: bool = false
	var any_target: bool = false
	for step in pierce + 1:
		var hit: Dictionary = _ray(from, dir, float(c["range"]), exclude)
		if hit.is_empty():
			break
		end = hit["position"]
		var col: Object = hit["collider"]
		if not col.has_method("take_hit"):
			break # trúng tường: dừng
		any_target = true
		var d: float = damage
		var head: bool = false
		if c.has("headshot_mult"):
			var base_y: float = (col as Node3D).global_position.y
			head = (hit["position"] as Vector3).y - base_y > float(c["headshot_height"])
			if head:
				d *= float(c["headshot_mult"])
		if _hit(col, d, dir, {"headshot": head, "point": hit["position"]}):
			any_landed = true
			if weapon == "sniper" and _wmod("chain", 0.0) > 0.0 and "dead" in col and col.dead:
				_chain_t = float(Global.PERKS["chain_window"])   # Săn liên hoàn: hạ gục mở cửa sổ bắn liền
		exclude.append(col.get_rid())
		damage *= float(c.get("pierce_mult", 0.7 if int(_wmod("pierce", 0.0)) > 0 else 1.0))
	if any_target:
		hit_confirmed.emit(any_landed)
	return end


## Shotgun: nhiều viên tản, sát thương giảm theo khoảng cách. Trả về điểm trúng giữa nòng.
## Thẻ Cú đá đôi (+sát thương khi đang bay) và Đạn dội (mảnh trúng tường nảy một lần).
func _fire_pellets(from: Vector3, dir: Vector3, c: Dictionary) -> Vector3:
	var basis := Basis.looking_at(dir, Vector3.UP)
	var spread: float = deg_to_rad(float(c["spread_deg"]))
	var any_landed: bool = false
	var any_target: bool = false
	var centre: Vector3 = from + dir * float(c["range"])
	var air_mult: float = 1.0 + _wmod("airkick", 0.0) if _airborne() else 1.0
	var ricochet: bool = _wmod("ricochet", 0.0) > 0.0
	for i in int(c["pellets"]):
		var ang: float = randf() * TAU
		var rad: float = sqrt(randf()) * spread
		var pd: Vector3 = (basis * Vector3(sin(rad) * cos(ang), sin(rad) * sin(ang), -cos(rad))).normalized()
		var hit: Dictionary = _ray(from, pd, float(c["range"]))
		if hit.is_empty():
			continue
		if i == 0:
			centre = hit["position"]
		var col: Object = hit["collider"]
		var travelled: float = from.distance_to(hit["position"])
		var mult: float = air_mult
		if not col.has_method("take_hit"):
			if not ricochet:
				continue
			# nảy khỏi tường một lần
			var n: Vector3 = hit.get("normal", Vector3.UP)
			var rd: Vector3 = pd.bounce(n).normalized()
			var rfrom: Vector3 = (hit["position"] as Vector3) + n * 0.05
			hit = _ray(rfrom, rd, maxf(float(c["range"]) - travelled, 1.0))
			if hit.is_empty() or not (hit["collider"] as Object).has_method("take_hit"):
				continue
			col = hit["collider"]
			pd = rd
			travelled += rfrom.distance_to(hit["position"])
			mult *= float(Global.PERKS["ricochet_mult"])
		var k: float = clampf(1.0 - travelled / float(c["falloff_range"]), 0.0, 1.0)
		var d: float = float(c["damage"]) * lerpf(float(c["min_falloff"]), 1.0, k) * mult
		any_target = true
		if _hit(col, d, pd):
			any_landed = true
	if any_target:
		hit_confirmed.emit(any_landed)
	return centre


## Thẻ Sóng xung kích: hất lùi mọi bot trong nón phía trước, trong tầm `shockwave_range`.
func _shockwave(from: Vector3, dir: Vector3) -> void:
	var shape := SphereShape3D.new()
	shape.radius = float(Global.PERKS["shockwave_range"])
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, from)
	q.collision_mask = Global.L_ENEMY_HURT
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var seen: Array = []
	for r in _head.get_world_3d().direct_space_state.intersect_shape(q, 32):
		var hb: Object = r["collider"]
		if hb in seen:
			continue
		seen.append(hb)
		var body: Node3D = hb.get_parent() as Node3D
		if body == null or body == _body or not body.has_method("apply_knockback") or ("dead" in body and body.dead):
			continue
		var to: Vector3 = body.global_position + Vector3(0.0, 0.95, 0.0) - from
		if to.length() < 0.01 or to.normalized().dot(dir) < float(Global.PERKS["shockwave_cone"]):
			continue
		var flat: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
		body.apply_knockback(flat * float(Global.PERKS["shockwave_push"]) + Vector3(0.0, 3.0, 0.0))


func _launch_rocket(from: Vector3, dir: Vector3, c: Dictionary) -> void:
	var cluster: bool = _wmod("cluster", 0.0) > 0.0
	var count: int = int(Global.PERKS["cluster_count"]) if cluster else 1
	var basis := Basis.looking_at(dir, Vector3.UP)
	for i in count:
		var d: Vector3 = dir
		if cluster:
			var a: float = TAU * float(i) / float(count)
			var off: float = deg_to_rad(float(Global.PERKS["cluster_spread_deg"]))
			d = (basis * Vector3(sin(off) * cos(a), sin(off) * sin(a), -cos(off))).normalized()
		_spawn_rocket(from, d, c, cluster)


func _spawn_rocket(from: Vector3, dir: Vector3, c: Dictionary, cluster: bool) -> void:
	var r: Node3D = RocketScript.new()
	_body.get_parent().add_child(r)
	r.global_position = from + dir * 0.8
	var rc: Dictionary = c.duplicate()
	rc["damage"] = float(c["damage"]) * damage_mult
	rc["self_damage_mult"] = flaws.self_damage_mult(weapon, float(c["self_damage_mult"]))
	if cluster:
		rc["damage"] = float(rc["damage"]) * float(Global.PERKS["cluster_damage"])
		rc["blast_radius"] = float(c["blast_radius"]) * float(Global.PERKS["cluster_radius"])
	if _wmod("jump", 0.0) > 0.0:
		rc["self_push_mult"] = float(Global.PERKS["launcher_jump_mult"])
	if _wmod("sticky", 0.0) > 0.0:
		rc["sticky"] = float(Global.PERKS["sticky_fuse"])
	if _wmod("chain", 0.0) > 0.0:
		rc["chain"] = true
	r.setup(_body, rc, dir)
	r.exploded.connect(func(pos: Vector3, radius: float): exploded.emit(pos, radius))
