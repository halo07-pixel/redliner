extends Node
## Điều khiển chiến đấu của người chơi: kiếm (qua MeleeHitbox), súng tia tức thì, parry, nạp đạn.
## Input nằm ở các field want_* (Player điền từ Input; test headless tự điền).

signal ammo_changed(current: int, maximum: int)
signal shot_fired(from: Vector3, to: Vector3)
signal hit_confirmed(landed: bool)

var want_attack: bool = false  # giữ
var want_shoot: bool = false   # giữ
var want_parry: bool = false   # xung 1 lần
var want_reload: bool = false  # xung 1 lần

var ammo: int = 0
var reloading: bool = false

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
	ammo = Global.COMBAT["gun_mag"]


func refill() -> void:
	ammo = Global.COMBAT["gun_mag"]
	reloading = false
	_shot_cd = 0.0
	ammo_changed.emit(ammo, Global.COMBAT["gun_mag"])


func _physics_process(delta: float) -> void:
	_shot_cd = maxf(_shot_cd - delta, 0.0)
	if reloading:
		_reload_t -= delta
		if _reload_t <= 0.0:
			reloading = false
			ammo = Global.COMBAT["gun_mag"]
			ammo_changed.emit(ammo, Global.COMBAT["gun_mag"])

	var blocked: bool = _melee.is_staggered()
	if want_parry and not blocked:
		_parry.press()
	if want_attack and not blocked:
		_melee.try_swing()
	if want_reload:
		_start_reload()
	if want_shoot and not blocked:
		_shoot()
	want_parry = false
	want_reload = false


func _start_reload() -> void:
	if reloading or ammo >= int(Global.COMBAT["gun_mag"]):
		return
	reloading = true
	_reload_t = Global.COMBAT["gun_reload"]


func _shoot() -> void:
	if reloading or _shot_cd > 0.0:
		return
	if ammo <= 0:
		_start_reload()
		return
	ammo -= 1
	_shot_cd = Global.COMBAT["gun_cooldown"]
	var from: Vector3 = _head.global_position
	var dir: Vector3 = -_head.global_transform.basis.z
	var to: Vector3 = from + dir * float(Global.COMBAT["gun_range"])
	var q := PhysicsRayQueryParameters3D.create(from, to, Global.L_WORLD | Global.L_ENEMY_HURT)
	q.collide_with_areas = true
	var hit: Dictionary = _head.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		to = hit["position"]
		var c: Object = hit["collider"]
		if c.has_method("take_hit"):
			var landed: bool = c.take_hit({
				"damage": Global.COMBAT["gun_damage"],
				"kind": "hitscan",
				"source": _body,
				"direction": dir,
			})
			hit_confirmed.emit(landed)
	shot_fired.emit(from + _head.global_transform.basis * Vector3(-0.3, -0.25, -0.7), to)
	ammo_changed.emit(ammo, Global.COMBAT["gun_mag"])
	if ammo == 0:
		_start_reload()
