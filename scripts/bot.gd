extends CharacterBody3D
## Bot AI (PvE). Dùng lại các component chiến đấu (Hurtbox, Melee, Parry) và hình nhân.
## Quyết định hành vi + di chuyển nằm trong _physics_process. Âm thanh/điểm chỉ ra ngoài qua
## Signal (`sound`, `died`). Tìm người chơi qua group "player". Không dùng navmesh: bám theo
## hướng người chơi + né vật cản bằng raycast (đấu trường là sân mở).
##
## Hành vi: đuổi theo -> vào tầm thì chém (có báo đòn) / giữ khoảng cách và bắn (xạ thủ);
## thấy đòn của người chơi thì có xác suất parry hoặc né (sau độ trễ phản ứng);
## bị parry/clash thì choáng.

signal sound(sound_name: String)
signal died(bot: Node3D, info: Dictionary)

const MannequinScript = preload("res://scripts/mannequin.gd")
const HurtboxScript = preload("res://scripts/components/hurtbox_component.gd")
const ParryScript = preload("res://scripts/components/parry_component.gd")
const MeleeScript = preload("res://scripts/components/melee_hitbox_component.gd")
const BulletScript = preload("res://scripts/bullet.gd")

const GRAVITY: float = 24.0
const DODGE_SPEED: float = 14.0
const DODGE_TIME: float = 0.25

var type_name: String = "swordsman"
var difficulty: int = 1
var cfg: Dictionary = {}
var reaction: float = 0.35
var parry_chance: float = 0.1
var dodge_chance: float = 0.2
var speed: float = 7.5
var max_health: float = 60.0

var hurtbox: Area3D
var parry: Node
var melee: Node3D
var mannequin: Node3D
var target: Node3D
var dead: bool = false

var _atk_cd: float = 0.6
var _shoot_cd: float = 1.5
var _strafe_dir: float = 1.0
var _strafe_t: float = 2.0
var _dodge_t: float = 0.0
var _dodge_vec: Vector3 = Vector3.ZERO
var _threat_kind: String = ""
var _threat_t: float = 0.0
var _will_parry: bool = false
var _will_dodge: bool = false
var _last_hit: Dictionary = {}
var _body_shape: CollisionShape3D


## Gọi trước add_child. difficulty = số wave: bot khoẻ hơn, nhanh hơn, phản ứng nhanh hơn.
func setup(p_type: String, p_difficulty: int) -> void:
	type_name = p_type
	difficulty = p_difficulty
	cfg = Global.BOTS[p_type]
	var d: float = float(p_difficulty - 1)
	reaction = float(cfg["reaction"]) * maxf(0.5, 1.0 - 0.06 * d)
	parry_chance = minf(float(cfg["parry"]) + 0.03 * d, 0.8)
	dodge_chance = minf(float(cfg["dodge"]) + 0.02 * d, 0.7)
	speed = float(cfg["speed"]) * (1.0 + 0.02 * d)
	max_health = float(cfg["health"]) * (1.0 + 0.08 * d)


func _ready() -> void:
	if cfg.is_empty():
		setup(type_name, difficulty)
	add_to_group("bots")
	collision_layer = Global.L_ENEMY
	collision_mask = Global.L_WORLD | Global.L_ENEMY | Global.L_PLAYER
	_body_shape = CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.35
	cs.height = 1.8
	_body_shape.shape = cs
	_body_shape.position = Vector3(0.0, 0.9, 0.0)
	add_child(_body_shape)

	mannequin = MannequinScript.new()
	mannequin.color = cfg["color"]
	add_child(mannequin)

	parry = ParryScript.new()
	add_child(parry)
	parry.setup(self)

	hurtbox = HurtboxScript.new()
	var hs := CollisionShape3D.new()
	var hc := CapsuleShape3D.new()
	hc.radius = 0.4
	hc.height = 1.9
	hs.shape = hc
	hs.position = Vector3(0.0, 0.95, 0.0)
	hurtbox.add_child(hs)
	add_child(hurtbox)
	hurtbox.setup(Global.TEAM_ENEMY, max_health, parry)
	hurtbox.hurt.connect(_on_hurt)
	hurtbox.died.connect(_on_died)

	melee = MeleeScript.new()
	melee.position = Vector3(0.0, 1.2, 0.0)
	add_child(melee)
	melee.setup(Global.TEAM_ENEMY, self)
	melee.windup_override = float(cfg["windup"])
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.07, 0.9)
	blade.mesh = bm
	blade.position = Vector3(0.4, -0.1, -0.5)
	melee.add_child(blade)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node3D
		if target == null:
			return
	_atk_cd = maxf(_atk_cd - delta, 0.0)
	_shoot_cd = maxf(_shoot_cd - delta, 0.0)
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta

	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var dir: Vector3 = to / dist if dist > 0.01 else -global_transform.basis.z
	if dist > 0.05:
		rotation.y = atan2(-to.x, -to.z) # quay mặt (-Z) về phía người chơi

	if target.dead:
		_clear_threat()
	else:
		_react_to_threat(delta, dir)

	var wish := Vector3.ZERO
	if target.dead or melee.is_staggered():
		wish = Vector3.ZERO
	elif _dodge_t > 0.0:
		_dodge_t -= delta
		wish = _dodge_vec
	elif melee.phase != melee.Phase.IDLE:
		wish = Vector3.ZERO # đang ra đòn: đứng yên cam kết
	else:
		wish = _decide(dir, dist)
	velocity.x = wish.x
	velocity.z = wish.z
	move_and_slide()


# ------------------------------------------------------------------ quyết định

func _decide(dir: Vector3, dist: float) -> Vector3:
	var wish := Vector3.ZERO
	var keep: float = cfg["keep_range"]
	if keep > 0.0:
		# Xạ thủ: giữ khoảng cách, đi ngang (đổi hướng định kỳ)
		_strafe_t -= get_physics_process_delta_time()
		if _strafe_t <= 0.0:
			_strafe_t = randf_range(1.5, 3.0)
			_strafe_dir = -_strafe_dir
		if dist < keep - 3.0:
			wish = _steer(-dir) * speed
		elif dist > keep + 3.0:
			wish = _steer(dir) * speed
		else:
			wish = Vector3(-dir.z, 0.0, dir.x) * _strafe_dir * speed * 0.6
	elif bool(cfg["melee"]):
		if dist > float(cfg["range"]):
			wish = _steer(dir) * speed

	if bool(cfg["melee"]) and dist <= float(cfg["range"]) + 0.3 and _atk_cd <= 0.0 and melee.can_swing():
		if melee.try_swing():
			_atk_cd = cfg["attack_cd"]
			sound.emit("slash")
	if bool(cfg["shoots"]) and _shoot_cd <= 0.0 and dist >= 6.0 and dist <= float(Global.COMBAT["turret_range"]) and _has_line_of_sight():
		_shoot_cd = float(cfg["shoot_interval"]) * randf_range(0.8, 1.2)
		_shoot_predicted()
	return wish


## Né vật cản: nếu phía trước (2 m) có tường thì trượt dọc theo tường.
func _steer(dir: Vector3) -> Vector3:
	var origin: Vector3 = global_position + Vector3(0.0, 0.5, 0.0)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 2.0, Global.L_WORLD)
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return dir
	var tangent: Vector3 = hit["normal"].cross(Vector3.UP).normalized()
	if tangent.dot(dir) < 0.0:
		tangent = -tangent
	return tangent


func _chest(node: Node3D) -> Vector3:
	return node.global_position + Vector3(0.0, 1.2, 0.0)


func _has_line_of_sight() -> bool:
	var q := PhysicsRayQueryParameters3D.create(_chest(self), _chest(target), Global.L_WORLD)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _shoot_predicted() -> void:
	var from: Vector3 = _chest(self)
	var tpos: Vector3 = _chest(target)
	var tvel: Vector3 = target.velocity if "velocity" in target else Vector3.ZERO
	var lead: float = from.distance_to(tpos) / float(Global.COMBAT["bullet_speed"])
	shoot_at(tpos + Vector3(tvel.x, 0.0, tvel.z) * lead * 0.8)


func shoot_at(target_pos: Vector3) -> Node3D:
	var origin: Vector3 = _chest(self)
	var dir: Vector3 = (target_pos - origin).normalized()
	var b: Node3D = BulletScript.new()
	b.setup(Global.TEAM_ENEMY, self, dir)
	get_parent().add_child(b)
	b.global_position = origin + dir * 0.8
	sound.emit("shot")
	return b


# ------------------------------------------------------------------ phản ứng với đòn

## Tìm mối đe doạ: đòn kiếm của người chơi (đang báo/đang chém về phía mình) hoặc đạn bay tới.
## Trả về [loại, thời gian tới khi trúng].
func _find_threat() -> Array:
	var p: Node3D = target
	var my_chest: Vector3 = _chest(self)
	var best_kind: String = ""
	var best_tti: float = INF
	var pm: Node3D = p.melee
	if pm.phase == pm.Phase.WINDUP or pm.phase == pm.Phase.ACTIVE:
		var off: Vector3 = global_position - p.global_position
		if off.length() < 3.4 and (-p.head.global_transform.basis.z).dot(off.normalized()) > 0.6:
			best_kind = "melee"
			best_tti = 0.0
	for b in get_tree().get_nodes_in_group("bullets"):
		if b.team == Global.TEAM_ENEMY:
			continue
		var rel: Vector3 = my_chest - b.global_position
		var d: float = rel.length()
		if d < 14.0 and b.velocity.dot(rel) > 0.0:
			var tti: float = d / maxf(b.velocity.length(), 0.01)
			if tti < best_tti:
				best_kind = "bullet"
				best_tti = tti
	return [best_kind, best_tti]


func _clear_threat() -> void:
	_threat_kind = ""
	_threat_t = 0.0


## Có độ trễ phản ứng (reaction): thấy đòn rồi mới sau `reaction` giây mới hành động. Bot chỉ
## parry được nếu còn kịp (độ trễ ngắn hơn thời gian đòn tới).
func _react_to_threat(delta: float, dir: Vector3) -> void:
	var th: Array = _find_threat()
	var kind: String = th[0]
	var tti: float = th[1]
	if kind == "":
		_clear_threat()
		return
	if _threat_kind == "":
		_threat_kind = kind
		_threat_t = 0.0
		_will_parry = randf() < parry_chance
		_will_dodge = randf() < dodge_chance
	_threat_t += delta
	if _threat_t < reaction:
		return
	if _will_parry and parry.can_press() and (kind == "melee" or tti <= 0.12):
		parry.press()
		_will_parry = false
	elif _will_dodge and _dodge_t <= 0.0 and melee.phase == melee.Phase.IDLE and (kind == "melee" or tti > 0.15):
		_dodge_t = DODGE_TIME
		_dodge_vec = Vector3(-dir.z, 0.0, dir.x) * (1.0 if randf() < 0.5 else -1.0) * DODGE_SPEED
		_will_dodge = false


# ------------------------------------------------------------------ nhận đòn / chết

func _on_hurt(hit: Dictionary, _left: float) -> void:
	_last_hit = hit
	mannequin.flash()


func _on_died() -> void:
	dead = true
	var info := {
		"type": type_name,
		"kind": _last_hit.get("kind", ""),
		"reflected": _last_hit.has("bullet") and is_instance_valid(_last_hit["bullet"]) and _last_hit["bullet"].reflected,
		"staggered": melee.is_staggered(),
		"score": int(cfg["score"]),
	}
	hurtbox.collision_layer = 0
	_body_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	sound.emit("hit")
	died.emit(self, info)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.0, 0.05, 1.0), 0.3)
	tw.tween_callback(queue_free)
