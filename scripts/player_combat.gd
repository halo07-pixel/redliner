extends Node
## Điều khiển chiến đấu của người chơi: kiếm (thường + chém rộng), 4 súng (súng lục, shotgun,
## pháo nổ, bắn tỉa), parry, nạp đạn, đổi súng. Mỗi súng có băng đạn riêng.
## Input nằm ở các field want_* (Player điền từ Input; test headless tự điền).

const RocketScript = preload("res://scripts/rocket.gd")

signal ammo_changed(current: int, maximum: int)
signal shot_fired(from: Vector3, to: Vector3)
signal hit_confirmed(landed: bool)
signal reloading_changed(on: bool)
signal weapon_changed(id: String, display_name: String)
signal exploded(position: Vector3, radius: float)

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
	return int(cfg()["mag"])


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
	weapon = id
	_shot_cd = float(cfg()["draw"]) # thời gian rút súng
	weapon_changed.emit(id, String(cfg()["name"]))
	ammo_changed.emit(ammo, max_ammo())


func _physics_process(delta: float) -> void:
	_shot_cd = maxf(_shot_cd - delta, 0.0)
	if reloading:
		_reload_t -= delta
		if _reload_t <= 0.0:
			reloading = false
			reloading_changed.emit(false)
			ammo = max_ammo()
			ammo_changed.emit(ammo, max_ammo())

	if want_weapon >= 0 and want_weapon < Global.WEAPON_ORDER.size():
		switch_to(Global.WEAPON_ORDER[want_weapon])
	if want_cycle != 0:
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
	if want_shoot and not blocked:
		_shoot()
	want_parry = false
	want_reload = false
	want_heavy = false
	want_weapon = -1
	want_cycle = 0


func _start_reload() -> void:
	if reloading or ammo >= max_ammo():
		return
	reloading = true
	_reload_t = float(cfg()["reload"])
	reloading_changed.emit(true)


func _shoot() -> void:
	if reloading or _shot_cd > 0.0:
		return
	if ammo <= 0:
		_start_reload()
		return
	var c: Dictionary = cfg()
	ammo -= 1
	_shot_cd = float(c["cooldown"])
	var from: Vector3 = _head.global_position
	var dir: Vector3 = -_head.global_transform.basis.z
	var muzzle: Vector3 = from + _head.global_transform.basis * Vector3(-0.3, -0.25, -0.7)
	var to: Vector3 = from + dir * float(c["range"])
	match String(c["kind"]):
		"pellets":
			to = _fire_pellets(from, dir, c)
		"explosive":
			_launch_rocket(from, dir, c)
			to = from + dir * 3.0
		_:
			to = _fire_hitscan(from, dir, c)
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
	var h := {"damage": damage, "kind": "hitscan", "source": _body, "direction": dir}
	h.merge(extra, true)
	return collider.take_hit(h)


## Súng lục / bắn tỉa. Bắn tỉa: headshot nhân sát thương, xuyên 1 mục tiêu với sát thương giảm.
func _fire_hitscan(from: Vector3, dir: Vector3, c: Dictionary) -> Vector3:
	var damage: float = float(c["damage"])
	var pierce: int = int(c.get("pierce", 0))
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
		if _hit(col, d, dir, {"headshot": head}):
			any_landed = true
		exclude.append(col.get_rid())
		damage *= float(c.get("pierce_mult", 1.0))
	if any_target:
		hit_confirmed.emit(any_landed)
	return end


## Shotgun: nhiều viên tản, sát thương giảm theo khoảng cách. Trả về điểm trúng giữa nòng.
func _fire_pellets(from: Vector3, dir: Vector3, c: Dictionary) -> Vector3:
	var basis := Basis.looking_at(dir, Vector3.UP)
	var spread: float = deg_to_rad(float(c["spread_deg"]))
	var any_landed: bool = false
	var any_target: bool = false
	var centre: Vector3 = from + dir * float(c["range"])
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
		if not col.has_method("take_hit"):
			continue
		var dist: float = from.distance_to(hit["position"])
		var k: float = clampf(1.0 - dist / float(c["falloff_range"]), 0.0, 1.0)
		var d: float = float(c["damage"]) * lerpf(float(c["min_falloff"]), 1.0, k)
		any_target = true
		if _hit(col, d, pd):
			any_landed = true
	if any_target:
		hit_confirmed.emit(any_landed)
	return centre


func _launch_rocket(from: Vector3, dir: Vector3, c: Dictionary) -> void:
	var r: Node3D = RocketScript.new()
	_body.get_parent().add_child(r)
	r.global_position = from + dir * 0.8
	r.setup(_body, c, dir)
	r.exploded.connect(func(pos: Vector3, radius: float): exploded.emit(pos, radius))
