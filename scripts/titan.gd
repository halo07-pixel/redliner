extends CharacterBody3D
## Titan khổng lồ (M24). Dùng chung giao diện với bot.gd ở những chỗ hệ thống ngoài cần (group "bots", signal `died`,
## `sound`, `exploded`, `hurtbox`, `melee`, `cfg`, `type_name`, `dead`), nhưng AI riêng: đi theo navmesh Titan (bán kính lớn),
## hai đòn có báo trước dài (giậm: vòng đỏ dưới đất, quét: dải đỏ phía trước) và ba vùng nhận sát thương:
## thân (trầy), gáy (rất đau), gối (đánh nhiều thì quỵ -> gáy thấp xuống). Parry được đòn của Titan -> choáng.
## Chỉ phát Signal ra ngoài (tiếng, rung màn hình, thanh máu); logic vật lý ở _physics_process.

signal sound(sound_name: String)
signal died(bot: Node3D, info: Dictionary)
signal exploded(position: Vector3, radius: float) # (giữ giao diện bot; Titan không nổ)
signal health_changed(current: float, maximum: float)
signal stepped(position: Vector3) # mỗi bước chân (main rung màn hình theo khoảng cách)
signal stomp_landed(position: Vector3, radius: float)
signal weak_point_hit(zone: String) # "nape" | "knee"

const MannequinScript = preload("res://scripts/mannequin.gd")
const HurtboxScript = preload("res://scripts/components/hurtbox_component.gd")
const GRAVITY: float = 24.0

enum S { WALK, STOMP_WIND, STOMP_REC, SWIPE_WIND, SWIPE_ACTIVE, SWIPE_REC, KNEEL, STAGGER, DEAD }

## Giao diện tối thiểu cho code cũ gọi `bot.melee.stagger(...)` (slam, rocket): Titan chỉ choáng với đòn đủ nặng.
class MeleeStub extends RefCounted:
	var owner_ref: Node
	var phase: int = 0
	func stagger(_d: float) -> void:
		pass
	func is_staggered() -> bool:
		return false

var type_name: String = "titan"
var difficulty: int = 1
var cfg: Dictionary = {}
var health: float = 600.0
var max_health: float = 600.0
var score_mult: float = 1.0
var speed: float = 4.0
var dead: bool = false
var is_titan: bool = true
var nav_map: RID = RID()   # navmesh Titan (arena dựng); không có thì đi thẳng

var target: Node3D
var mannequin: Node3D
var hurtbox: Area3D        # vùng thân (slam / nổ gọi hurtbox.take_hit)
var melee = MeleeStub.new()
var state: int = S.WALK

var _nape: Area3D
var _knees: Array = []
var _grapple_area: Area3D
var _body_shape: CollisionShape3D
var _zones: Array = []     # tất cả vùng nhận sát thương (để tắt khi chết)
var _t: float = 0.0
var _stomp_cd: float = 2.0
var _swipe_cd: float = 1.5
var _stomp_pt: Vector3 = Vector3.ZERO
var _swipe_dir: Vector3 = Vector3.ZERO
var _swipe_hit: bool = false
var _knee_acc: float = 0.0
var _hv: Vector3 = Vector3.ZERO
var _path: PackedVector3Array = PackedVector3Array()
var _path_t: float = 0.0
var _step_t: float = 0.0
var _kneeled: bool = false
var _marker: MeshInstance3D
var _last_hit: Dictionary = {}


## Gọi trước add_child (cùng chữ ký bot.gd): difficulty = số wave.
func setup(p_type: String, p_difficulty: int) -> void:
	type_name = p_type
	difficulty = p_difficulty
	cfg = Global.BOTS["titan"]
	var st: Dictionary = Global.bot_stats("titan", p_difficulty)
	max_health = float(st["health"])
	health = max_health
	speed = float(st["speed"])
	score_mult = float(st["score_mult"])


func _ready() -> void:
	if cfg.is_empty():
		setup("titan", difficulty)
	add_to_group("bots")
	var T: Dictionary = Global.TITAN
	var S_: float = float(T["scale"])
	collision_layer = Global.L_ENEMY
	collision_mask = Global.L_WORLD | Global.L_PLAYER
	_body_shape = CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = float(T["body_radius"])
	cs.height = float(T["body_height"])
	_body_shape.shape = cs
	_body_shape.position = Vector3(0.0, float(T["body_height"]) * 0.5, 0.0)
	add_child(_body_shape)

	mannequin = MannequinScript.new()
	mannequin.color = cfg["color"]
	mannequin.kind = "titan"
	mannequin.ik_feet = false
	mannequin.scale = Vector3.ONE * S_
	add_child(mannequin)

	# Vùng nhận sát thương: thân (capsule), gáy (cầu sau cổ), hai gối. Mỗi vùng là một Hurtbox máu vô hạn;
	# máu thật của Titan do `_on_zone_hit` trừ theo hệ số vùng.
	hurtbox = _make_zone("body", _capsule(float(T["body_radius"]) + 0.2, float(T["body_height"]) - 1.0), Vector3(0.0, float(T["body_height"]) * 0.5 + 0.3, 0.0))
	_nape = _make_zone("nape", _sphere(1.5), Vector3(0.0, 9.0, 1.4))
	for sx in [-1.0, 1.0]:
		_knees.append(_make_zone("knee", _sphere(1.4), Vector3(1.0 * sx, 3.0, 0.0)))
	# Bề mặt để móc grapple (Area trên tầng riêng L_TITAN, tia grapple quét tầng này).
	_grapple_area = Area3D.new()
	_grapple_area.collision_layer = Global.L_TITAN
	_grapple_area.collision_mask = 0
	_grapple_area.monitoring = false
	var gs := CollisionShape3D.new()
	gs.shape = _capsule(float(T["body_radius"]) + 0.4, float(T["body_height"]))
	gs.position = Vector3(0.0, float(T["body_height"]) * 0.5, 0.0)
	_grapple_area.add_child(gs)
	add_child(_grapple_area)
	health_changed.emit(health, max_health)


func _capsule(r: float, h: float) -> CapsuleShape3D:
	var c := CapsuleShape3D.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.01)
	return c


func _sphere(r: float) -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s


func _make_zone(zone: String, shape: Shape3D, pos: Vector3) -> Area3D:
	var hb: Area3D = HurtboxScript.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	hb.add_child(cs)
	add_child(hb)
	hb.setup(Global.TEAM_ENEMY, 1.0e9, null)
	hb.set_meta("zone", zone)
	hb.hurt.connect(func(hit: Dictionary, _l: float): _on_zone_hit(zone, hit))
	_zones.append(hb)
	return hb


func apply_knockback(_push: Vector3) -> void:
	pass # quá nặng để bị đẩy


func hit_zone(_hit: Dictionary) -> String:
	return "torso"


# ------------------------------------------------------------------ sát thương

func _on_zone_hit(zone: String, hit: Dictionary) -> void:
	if dead:
		return
	var T: Dictionary = Global.TITAN
	var raw: float = float(hit["damage"])
	health = maxf(health - raw * float(T[zone + "_mult"]), 0.0)
	_last_hit = hit
	health_changed.emit(health, max_health)
	mannequin.flash()
	if zone != "body":
		weak_point_hit.emit(zone)
	if zone == "knee" and state != S.KNEEL and state != S.DEAD:
		_knee_acc += raw
		if _knee_acc >= float(T["knee_threshold"]):
			_start_kneel()
	if health <= 0.0:
		_die()


func _start_kneel() -> void:
	_knee_acc = 0.0
	_cancel_attack()
	state = S.KNEEL
	_t = float(Global.TITAN["kneel_time"])
	_set_kneel(true)
	mannequin.play("stagger", _t)
	sound.emit("clash")


## Quỵ: hạ chiều cao thân + dời gáy/gối xuống để gáy trong tầm với.
func _set_kneel(on: bool) -> void:
	_kneeled = on
	var T: Dictionary = Global.TITAN
	var k: float = float(T["kneel_height"]) if on else 1.0
	mannequin.scale = Vector3(float(T["scale"]), float(T["scale"]) * k, float(T["scale"]))
	_nape.position = Vector3(0.0, -9.0 * (1.0 - k), 0.0)
	_grapple_area.position = Vector3(0.0, -float(T["body_height"]) * (1.0 - k) * 0.5, 0.0)


func _on_parried() -> void:
	if dead:
		return
	_cancel_attack()
	state = S.STAGGER
	_t = float(Global.TITAN["parry_stagger"])
	mannequin.play("stagger", _t)
	sound.emit("clash")


func _cancel_attack() -> void:
	if _marker != null:
		_marker.visible = false


func _die() -> void:
	dead = true
	state = S.DEAD
	_cancel_attack()
	var info := {
		"type": type_name,
		"kind": _last_hit.get("kind", ""),
		"reflected": false,
		"staggered": false,
		"score": int(round(float(cfg["score"]) * score_mult)),
	}
	for z in _zones:
		z.collision_layer = 0
	_grapple_area.collision_layer = 0
	_body_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	sound.emit("hit")
	died.emit(self, info)
	mannequin.play("die", float(Global.ANIM["die_time"]))
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_callback(func(): mannequin.fade_out(0.8))
	tw.tween_interval(0.9)
	tw.tween_callback(queue_free)


# ------------------------------------------------------------------ AI

func _physics_process(delta: float) -> void:
	if dead:
		mannequin.animate(delta, 0.0, true, 0.0)
		return
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node3D
		if target == null:
			return
	_stomp_cd = maxf(_stomp_cd - delta, 0.0)
	_swipe_cd = maxf(_swipe_cd - delta, 0.0)
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var T: Dictionary = Global.TITAN
	var wish := Vector3.ZERO
	match state:
		S.WALK:
			wish = _walk(delta, to, dist)
		S.STOMP_WIND:
			_face(to, delta, 0.6)
			_t -= delta
			if _t <= 0.0:
				_do_stomp()
		S.STOMP_REC:
			_t -= delta
			if _t <= 0.0:
				state = S.WALK
		S.SWIPE_WIND:
			_face(to, delta, 0.8)
			_swipe_dir = -global_transform.basis.z
			_place_swipe_marker()
			_t -= delta
			if _t <= 0.0:
				state = S.SWIPE_ACTIVE
				_t = float(T["swipe_active"])
				_swipe_hit = false
				sound.emit("slash")
		S.SWIPE_ACTIVE:
			_scan_swipe()
			_t -= delta
			if _t <= 0.0:
				state = S.SWIPE_REC
				_t = float(T["swipe_recovery"])
				_cancel_attack()
		S.SWIPE_REC:
			_t -= delta
			if _t <= 0.0:
				state = S.WALK
		S.KNEEL:
			_t -= delta
			if _t <= 0.0:
				_set_kneel(false)
				state = S.WALK
		S.STAGGER:
			_t -= delta
			if _t <= 0.0:
				state = S.WALK
	_hv = _hv.move_toward(wish, float(T["speed_accel"]) * delta)
	velocity.x = _hv.x
	velocity.z = _hv.z
	move_and_slide()
	var sp: float = Vector2(velocity.x, velocity.z).length()
	_step_t -= delta * clampf(sp / maxf(speed, 0.1), 0.0, 1.0)
	if sp > 0.5 and _step_t <= 0.0:
		_step_t = float(T["step_interval"])
		stepped.emit(global_position)
		sound.emit("step")
	mannequin.set_look_target(target.global_position + Vector3(0.0, 1.45, 0.0) if not target.dead else null)
	mannequin.animate(delta, sp * 0.6, is_on_floor(), velocity.y)


func _face(to: Vector3, delta: float, rate_mult: float = 1.0) -> void:
	if to.length() < 0.05:
		return
	var goal: float = atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, goal, minf(1.0, float(Global.TITAN["turn_rate"]) * rate_mult * delta))


func _walk(delta: float, to: Vector3, dist: float) -> Vector3:
	var T: Dictionary = Global.TITAN
	if target.dead:
		return Vector3.ZERO
	_face(to, delta)
	# Chọn đòn khi trong tầm và đang quay mặt đúng hướng (quét cần quay mặt; giậm nhắm vị trí người chơi lúc bắt đầu).
	var fwd: Vector3 = -global_transform.basis.z
	var facing: bool = to.length() > 0.1 and fwd.dot(to.normalized()) > 0.85
	if _swipe_cd <= 0.0 and dist <= float(T["swipe_range"]) and facing:
		_start_swipe()
		return Vector3.ZERO
	if _stomp_cd <= 0.0 and dist <= float(T["stomp_range"]):
		_start_stomp()
		return Vector3.ZERO
	if dist < float(T["stomp_radius"]) * 0.6:
		return Vector3.ZERO # đã đứng sát: chờ đòn kế, không dẫm lên người chơi
	return _nav_dir(to, dist) * speed


func _nav_dir(to: Vector3, dist: float) -> Vector3:
	var dir: Vector3 = to / dist if dist > 0.01 else -global_transform.basis.z
	if not nav_map.is_valid() or NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return dir
	_path_t -= get_physics_process_delta_time()
	if _path_t <= 0.0:
		_path_t = 0.5
		_path = NavigationServer3D.map_get_path(nav_map, global_position, target.global_position, true)
	for i in range(1, _path.size()):
		var off: Vector3 = _path[i] - global_position
		off.y = 0.0
		if off.length() > 3.0 or i == _path.size() - 1:
			return off.normalized() if off.length() > 0.1 else Vector3.ZERO
	return dir


func _start_stomp() -> void:
	var T: Dictionary = Global.TITAN
	state = S.STOMP_WIND
	_t = float(T["stomp_windup"])
	_stomp_pt = target.global_position
	_stomp_pt.y = global_position.y
	_show_marker("disc", _stomp_pt, float(T["stomp_radius"]))
	mannequin.play("swing", _t + 0.5, {"windup": _t, "active": 0.2, "recovery": 0.3})


func _do_stomp() -> void:
	var T: Dictionary = Global.TITAN
	state = S.STOMP_REC
	_t = float(T["stomp_recovery"])
	_stomp_cd = float(T["stomp_cd"])
	_cancel_attack()
	stomp_landed.emit(_stomp_pt, float(T["stomp_radius"]))
	sound.emit("clash")
	if target.dead:
		return
	var tp: Vector3 = target.global_position
	var flat: float = Vector2(tp.x - _stomp_pt.x, tp.z - _stomp_pt.z).length()
	if flat <= float(T["stomp_radius"]) and tp.y - _stomp_pt.y <= float(T["stomp_max_height"]):
		_hit_player(float(T["stomp_damage"]), float(T["stomp_push"]), Vector3(tp.x - _stomp_pt.x, 0.0, tp.z - _stomp_pt.z))


func _start_swipe() -> void:
	var T: Dictionary = Global.TITAN
	state = S.SWIPE_WIND
	_t = float(T["swipe_windup"])
	_swipe_dir = -global_transform.basis.z
	_swipe_cd = float(T["swipe_cd"])
	mannequin.play("swing", _t + float(T["swipe_active"]) + float(T["swipe_recovery"]), {"windup": _t, "active": float(T["swipe_active"]), "recovery": float(T["swipe_recovery"])})


## Dải hình chữ nhật trước mặt Titan (quét). Người chơi nhảy cao hơn `stomp_max_height` * 2 hoặc ra ngoài dải thì tránh được.
func _in_swipe(p: Vector3) -> bool:
	var T: Dictionary = Global.TITAN
	var rel: Vector3 = p - global_position
	var f: float = rel.dot(_swipe_dir)
	var side: float = absf(rel.dot(_swipe_dir.cross(Vector3.UP)))
	return f > 0.0 and f <= float(T["swipe_reach"]) and side <= float(T["swipe_width"]) * 0.5 and rel.y <= float(T["stomp_max_height"]) * 2.0


func _scan_swipe() -> void:
	if _swipe_hit or target.dead:
		return
	if _in_swipe(target.global_position):
		_swipe_hit = true
		var T: Dictionary = Global.TITAN
		_hit_player(float(T["swipe_damage"]), float(T["swipe_push"]), _swipe_dir)


## Gây sát thương cho người chơi qua hurtbox (có thể bị parry -> Titan choáng). Đòn đã parry thì không đẩy lùi.
func _hit_player(damage: float, push: float, dir: Vector3) -> void:
	var d: Vector3 = dir
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else -global_transform.basis.z
	var landed: bool = target.hurtbox.take_hit({"damage": damage, "kind": "melee", "source": self, "direction": d, "on_parried": _on_parried})
	if landed and target.has_method("apply_blast"):
		target.apply_blast(d * push + Vector3.UP * 5.0)


# ------------------------------------------------------------------ báo đòn (hình ảnh)

func _show_marker(kind: String, at: Vector3, size: float) -> void:
	if _marker == null:
		_marker = MeshInstance3D.new()
		_marker.top_level = true
		_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.1, 0.05, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.15, 0.05)
		_marker.material_override = mat
		add_child(_marker)
	var cyl := CylinderMesh.new()
	cyl.top_radius = size
	cyl.bottom_radius = size
	cyl.height = 0.06
	_marker.mesh = cyl
	_marker.global_position = at + Vector3(0.0, 0.12, 0.0)
	_marker.global_rotation = Vector3.ZERO
	_marker.visible = true


func _place_swipe_marker() -> void:
	var T: Dictionary = Global.TITAN
	if _marker == null or not (_marker.mesh is BoxMesh):
		if _marker == null:
			_show_marker("disc", global_position, 1.0)
		var bm := BoxMesh.new()
		bm.size = Vector3(float(T["swipe_width"]), 0.06, float(T["swipe_reach"]))
		_marker.mesh = bm
	_marker.visible = true
	var c: Vector3 = global_position + _swipe_dir * float(T["swipe_reach"]) * 0.5
	_marker.global_position = Vector3(c.x, global_position.y + 0.12, c.z)
	_marker.global_rotation = Vector3(0.0, rotation.y, 0.0)
