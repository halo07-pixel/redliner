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
signal exploded(position: Vector3, radius: float) # đạn nổ của pháo thủ phát nổ

const MannequinScript = preload("res://scripts/mannequin.gd")
const MannequinGltfScript = preload("res://scripts/mannequin_gltf.gd")
const HurtboxScript = preload("res://scripts/components/hurtbox_component.gd")
const ParryScript = preload("res://scripts/components/parry_component.gd")
const SwordTrail = preload("res://scripts/sword_trail.gd")
const MeleeScript = preload("res://scripts/components/melee_hitbox_component.gd")
const InstabilityScript = preload("res://scripts/instability.gd")
const BulletScript = preload("res://scripts/bullet.gd")
const RocketScript = preload("res://scripts/rocket.gd")

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
var score_mult: float = 1.0

var hurtbox: Area3D
var parry: Node
var melee: Node3D
var instability: Node
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
var _retreat_t: float = 0.0   # lùi một nhịp sau khi bị parry / thua clash
var _punish: bool = false     # người chơi đang Destabilized
var _path: PackedVector3Array = PackedVector3Array()
var _path_t: float = 0.0


## Gọi trước add_child. difficulty = số wave: bot khoẻ hơn, nhanh hơn, phản ứng nhanh hơn
## (đường cong + mức độ khó ở Global.bot_stats).
func setup(p_type: String, p_difficulty: int) -> void:
	type_name = p_type
	difficulty = p_difficulty
	cfg = Global.BOTS[p_type]
	var st: Dictionary = Global.bot_stats(p_type, p_difficulty)
	reaction = float(st["reaction"])
	parry_chance = float(st["parry"])
	dodge_chance = float(st["dodge"])
	speed = float(st["speed"])
	max_health = float(st["health"])
	score_mult = float(st["score_mult"])


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

	# Người que glTF (GodoDude + vũ khí thật) nếu có asset; không thì dùng hình nhân dựng bằng khối.
	mannequin = (MannequinGltfScript if MannequinGltfScript.has_asset(type_name) else MannequinScript).new()
	mannequin.color = cfg["color"]
	mannequin.kind = type_name
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
	SwordTrail.attach(melee)
	melee.windup_override = float(cfg["windup"])
	# Hoạt ảnh chiến đấu nghe Signal của component (signal up); chỉ hiển thị, không ảnh hưởng logic.
	melee.swing_started.connect(func(w, a, r): mannequin.play("swing", w + a + r, {"windup": w, "active": a, "recovery": r}))
	melee.staggered.connect(func(d): mannequin.play("stagger", d))
	parry.parry_started.connect(func(): mannequin.play("parry", float(Global.ANIM["parry_time"])))
	parry.parry_missed.connect(func(): mannequin.play("parry_miss", float(Global.ANIM["parry_miss_time"])))
	# Mất thế (dùng chung cơ chế với người chơi): thua clash / parry hụt / bị parry -> Destabilized.
	instability = InstabilityScript.new()
	add_child(instability)
	melee.clashed.connect(func(_d): instability.clash_penalty())
	melee.got_parried.connect(func(): instability.add(Global.INSTABILITY["parried_loss"]))
	# Thua nhịp thì lùi lại một chút thay vì đứng yên (đổi nhịp)
	melee.clashed.connect(func(_d): _retreat_t = float(Global.DIFFICULTY["retreat_time"]))
	melee.got_parried.connect(func(): _retreat_t = float(Global.DIFFICULTY["retreat_time"]))
	parry.parry_missed.connect(func(): instability.add(Global.INSTABILITY["parry_miss_loss"]))
	parry.parried.connect(func(_h): instability.lose(Global.INSTABILITY["parry_relief"]))
	instability.destabilized_changed.connect(_on_destabilized)
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.07, 0.9)
	blade.mesh = bm
	blade.position = Vector3(0.4, -0.1, -0.5)
	melee.add_child(blade)


## Destabilized: huỷ đòn đang đánh, không tấn công/parry trong vài giây (chững lại, là cơ hội cho người chơi).
func _on_destabilized(active: bool) -> void:
	parry.locked = active
	if active:
		melee.stagger(float(Global.INSTABILITY["destabilized_time"]))
		mannequin.flash()


var _kb: Vector3 = Vector3.ZERO # lực đẩy từ vụ nổ, tắt dần
var _lift: float = 0.0


## Bị đẩy lùi (vụ nổ). Ngang tắt dần theo thời gian, dọc là xung nhảy một lần.
func apply_knockback(push: Vector3) -> void:
	_kb = Vector3(push.x, 0.0, push.z)
	_lift = maxf(push.y, 0.0)


func _physics_process(delta: float) -> void:
	if not dead:
		instability.tick(delta)
	if dead:
		mannequin.animate(delta, 0.0, true, 0.0) # chạy nốt hoạt ảnh ngã
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

	if _lift > 0.0:
		velocity.y = _lift
		_lift = 0.0
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var dir: Vector3 = to / dist if dist > 0.01 else -global_transform.basis.z
	if dist > 0.05:
		rotation.y = atan2(-to.x, -to.z) # quay mặt (-Z) về phía người chơi

	_update_punish()
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
	velocity.x = wish.x + _kb.x
	velocity.z = wish.z + _kb.z
	_kb = _kb.move_toward(Vector3.ZERO, 30.0 * delta)
	move_and_slide()
	mannequin.animate(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor(), velocity.y)


# ------------------------------------------------------------------ quyết định

## Người chơi vừa mất thế (Destabilized): bot cận chiến báo đòn nhanh + chạy nhanh hơn, bot bắn ra đòn sớm.
func _update_punish() -> void:
	var was: bool = _punish
	_punish = not target.dead and "instability" in target and target.instability.destabilized
	if _punish and not was:
		var D: Dictionary = Global.DIFFICULTY
		_atk_cd = minf(_atk_cd, float(D["punish_attack_cd"]))
		_shoot_cd = minf(_shoot_cd, float(D["punish_shoot_delay"]))


func _decide(dir: Vector3, dist: float) -> Vector3:
	var D: Dictionary = Global.DIFFICULTY
	var delta: float = get_physics_process_delta_time()
	var spd: float = speed * (float(D["punish_speed_mult"]) if _punish else 1.0)
	if _retreat_t > 0.0:
		_retreat_t -= delta
		return _steer(-dir) * spd * 0.6
	var wish := Vector3.ZERO
	var keep: float = cfg["keep_range"]
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.5, 3.0)
		_strafe_dir = -_strafe_dir
	if keep > 0.0:
		# Xạ thủ / pháo thủ: giữ khoảng cách, đi ngang (đổi hướng định kỳ)
		if dist < keep - 3.0:
			wish = _steer(-dir) * spd
		elif dist > keep + 3.0:
			wish = _navigate(target.global_position, dir, dist) * spd
		else:
			wish = Vector3(-dir.z, 0.0, dir.x) * _strafe_dir * spd * 0.6
	elif bool(cfg["melee"]):
		wish = _melee_move(dir, dist, spd)

	if bool(cfg["melee"]) and dist <= float(cfg["range"]) + 0.3 and _atk_cd <= 0.0 and melee.can_swing():
		melee.windup_override = float(cfg["windup"]) * (float(D["punish_windup_mult"]) if _punish else 1.0)
		if melee.try_swing():
			_atk_cd = float(D["punish_attack_cd"]) if _punish else float(cfg["attack_cd"])
			sound.emit("slash")
	if bool(cfg["shoots"]) and _shoot_cd <= 0.0 and dist >= 6.0 and dist <= float(Global.COMBAT["turret_range"]) and _has_line_of_sight():
		_shoot_cd = float(cfg["shoot_interval"]) * randf_range(0.8, 1.2)
		_shoot_predicted()
	if bool(cfg.get("bombs", false)) and _shoot_cd <= 0.0 and dist >= float(Global.BOMB["min_range"]) and dist <= float(Global.BOMB["max_range"]) and _has_line_of_sight():
		_shoot_cd = float(Global.BOMB["interval"]) * randf_range(0.85, 1.15)
		_throw_bomb()
	return wish


## Di chuyển cận chiến: lao thẳng vào, nhưng chỉ tối đa `max_melee_attackers` bot được áp sát cùng lúc
## (bot gần người chơi nhất được vào trước); phần còn lại đi vòng quanh ở rìa vòng. Bot "lao nhanh" lượn
## sang bên khi còn xa để bọc sườn.
func _melee_move(dir: Vector3, dist: float, spd: float) -> Vector3:
	var D: Dictionary = Global.DIFFICULTY
	if dist <= float(cfg["range"]):
		return Vector3.ZERO
	var ring: float = float(D["ring_radius"])
	if dist < ring + 1.0 and _melee_rank() >= int(D["max_melee_attackers"]):
		if dist < ring - 0.5:
			return _steer(-dir) * spd * 0.5
		return Vector3(-dir.z, 0.0, dir.x) * _strafe_dir * spd * 0.5
	var goal: Vector3 = target.global_position
	if bool(cfg.get("flank", false)) and dist > 6.0:
		goal += Vector3(-dir.z, 0.0, dir.x) * _strafe_dir * 5.0
	return _navigate(goal, dir, dist) * spd


## Thứ hạng của bot trong số bot cận chiến còn sống (0 = gần người chơi nhất).
func _melee_rank() -> int:
	var rank: int = 0
	var my_d: float = global_position.distance_to(target.global_position)
	for b in get_tree().get_nodes_in_group("bots"):
		if b == self or b.dead or not bool(b.cfg["melee"]):
			continue
		var d: float = b.global_position.distance_to(target.global_position)
		if d < my_d or (is_equal_approx(d, my_d) and b.get_instance_id() < get_instance_id()):
			rank += 1
	return rank


## Hướng đi (vector đơn vị, nằm ngang) tới `goal`: đường thẳng nếu thoáng và cùng độ cao, ngược lại
## đi theo navmesh (tính lại mỗi 0.3 s). Navmesh chưa sẵn sàng thì dùng né tường bằng ray như cũ.
func _navigate(goal: Vector3, dir: Vector3, dist: float) -> Vector3:
	var map: RID = get_world_3d().navigation_map
	var ready: bool = NavigationServer3D.map_get_iteration_id(map) > 0 and not NavigationServer3D.map_get_regions(map).is_empty()
	var level_diff: float = absf(target.global_position.y - global_position.y)
	var goal_dir: Vector3 = goal - global_position
	goal_dir.y = 0.0
	goal_dir = goal_dir.normalized() if goal_dir.length() > 0.01 else dir
	if not ready or (level_diff < 0.8 and dist < 25.0 and _has_line_of_sight()):
		return _steer(goal_dir)
	_path_t -= get_physics_process_delta_time()
	if _path_t <= 0.0:
		_path_t = 0.3
		_path = NavigationServer3D.map_get_path(map, global_position, goal, true)
	for i in range(1, _path.size()):
		var off: Vector3 = _path[i] - global_position
		off.y = 0.0
		if off.length() > 0.4 or i == _path.size() - 1:
			return off.normalized() if off.length() > 0.05 else Vector3.ZERO
	return _steer(goal_dir)


## Pháo thủ: ném đạn nổ vòng cung về phía người chơi (có đón đầu). Không hại phe bot.
func _throw_bomb() -> void:
	var B: Dictionary = Global.BOMB
	var from: Vector3 = _chest(self) + Vector3(0.0, 0.2, 0.0)
	var tpos: Vector3 = _chest(target)
	var tvel: Vector3 = target.velocity if "velocity" in target else Vector3.ZERO
	var flight: float = from.distance_to(tpos) / float(B["projectile_speed"])
	tpos += Vector3(tvel.x, 0.0, tvel.z) * flight * 0.6
	var aim: Vector3 = tpos - from
	var flat_len: float = Vector2(aim.x, aim.z).length()
	var r: Node3D = RocketScript.new()
	var rc: Dictionary = B.duplicate()
	rc["hit_mask"] = Global.L_WORLD | Global.L_PLAYER_HURT
	rc["skip_team"] = Global.TEAM_ENEMY
	get_parent().add_child(r)
	r.global_position = from + aim.normalized() * 0.8
	r.setup(self, rc, aim.normalized())
	r.velocity.y += 0.5 * float(B["gravity"]) * (flat_len / float(B["projectile_speed"])) # bù trọng lực: vòng cung
	r.exploded.connect(func(pos: Vector3, rad: float): exploded.emit(pos, rad))
	sound.emit("launcher")


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
	mannequin.play("shoot", float(Global.ANIM["shoot_time"]))
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
	var local_dir: Vector3 = mannequin.global_transform.basis.inverse() * Vector3(hit.get("direction", Vector3.ZERO))
	mannequin.play("hurt", float(Global.ANIM["hurt_time"]), {"direction": local_dir})


func _on_died() -> void:
	dead = true
	var info := {
		"type": type_name,
		"kind": _last_hit.get("kind", ""),
		"reflected": _last_hit.has("bullet") and is_instance_valid(_last_hit["bullet"]) and _last_hit["bullet"].reflected,
		"staggered": melee.is_staggered(),
		"score": int(round(float(cfg["score"]) * score_mult)),
	}
	hurtbox.collision_layer = 0
	_body_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	sound.emit("hit")
	died.emit(self, info)
	mannequin.play("die", float(Global.ANIM["die_time"]))
	mannequin.fade_out(0.3)
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(queue_free)
