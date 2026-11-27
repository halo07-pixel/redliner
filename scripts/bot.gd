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
const MannequinLowpolyScript = preload("res://scripts/mannequin_lowpoly.gd")
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
const STEP_HEIGHT: float = 0.75 # leo được bậc thấp; navmesh coi mép cao tới ~0.7 m (agent_max_climb 0.5 + lượng tử ô) là đi được

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
var _rank_until: int = 0
var _rank_cache: int = 0
var _blocked_t: float = 0.0   # thời gian muốn đi mà không nhúc nhích được (kẹt vật cản thấp...)
var _force_nav_t: float = 0.0 # đang ép đi theo navmesh (bỏ đường thẳng) sau khi bị kẹt
var _steer_hold: Vector3 = Vector3.ZERO # hướng lách đã chọn quanh vật cản (giữ nhất quán, không đổi bên liên tục)
var _steer_clear_t: float = 0.0
var _hv: Vector3 = Vector3.ZERO     # vận tốc ngang đã làm mượt (gia tốc / phanh)
var _vault_cd: float = 0.0
var _vault_push_t: float = 0.0
var _vault_dir: Vector3 = Vector3.ZERO
var _prev_yaw: float = 0.0
var _cover_pt: Vector3 = Vector3.INF # điểm nấp đã chọn (INF = không nấp)
var _cover_t: float = 0.0
var _unstick_t: float = 0.0
var _blocked_count: int = 0
var _blocked_win: float = 0.0


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
	# M44: thân low poly (Blender) -> không có thì người que glTF (GodoDude) -> không có thì hình nhân khối
	mannequin = (MannequinLowpolyScript if MannequinLowpolyScript.has_asset(type_name) else (MannequinGltfScript if MannequinGltfScript.has_asset(type_name) else MannequinScript)).new()
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
	melee.swing_started.connect(_on_swing_tell)
	melee.staggered.connect(func(d): mannequin.play("stagger", d))
	parry.parry_started.connect(func(): mannequin.play("parry", float(Global.ANIM["parry_time"])))
	parry.parried.connect(func(_h): mannequin.play("parry_hit", float(Global.ANIM["parry_hit_time"])))
	melee.clashed.connect(func(d): mannequin.play("clash", float(Global.ANIM["clash_time"]), {"direction": mannequin.global_transform.basis.inverse() * Vector3(d)}))
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


## Báo đòn (M28, chỉ hình ảnh/âm thanh): tiếng "tick" khi bắt đầu gồng, chớp sáng vũ khí đúng lúc cửa sổ parry của người chơi mở
## (parry_window trước khi đòn chạm). Không đổi thời gian windup. Chỉ khi bot ở gần người chơi.
func _on_swing_tell(w: float, _a: float, _r: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if global_position.distance_to((target as Node3D).global_position) > float(Global.ta("pf_tell_range")):
		return
	Sfx.play_at("tell", global_position + Vector3(0.0, 1.5, 0.0))
	var win: float = float(Global.COMBAT["parry_window"])
	var delay: float = maxf(w - win, 0.0)
	get_tree().create_timer(delay).timeout.connect(func():
		if is_inside_tree() and not dead and mannequin != null and mannequin.has_method("flash_weapon"):
			mannequin.flash_weapon(win))


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
	_vault_cd = maxf(_vault_cd - delta, 0.0)
	_cover_t = maxf(_cover_t - delta, 0.0)
	_unstick_t = maxf(_unstick_t - delta, 0.0)
	_blocked_win = maxf(_blocked_win - delta, 0.0)
	if _blocked_win <= 0.0:
		_blocked_count = 0
	if dist > 0.05:
		# quay mặt (-Z) về phía người chơi, có tốc độ xoay (ra đòn thì xoay nhanh để đòn trúng hướng)
		var turn: float = float(Global.BOT_MOVE["turn_rate_attack"] if melee.phase != melee.Phase.IDLE else Global.BOT_MOVE["turn_rate"])
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, turn * delta))

	_update_punish()
	if target.dead:
		_clear_threat()
	else:
		_react_to_threat(delta, dir)

	var wish := Vector3.ZERO
	var snap: bool = false
	if target.dead or melee.is_staggered():
		wish = Vector3.ZERO
	elif _dodge_t > 0.0:
		_dodge_t -= delta
		wish = _dodge_vec
		snap = true # né: bật tức thì
	elif melee.phase != melee.Phase.IDLE:
		wish = Vector3.ZERO # đang ra đòn: đứng yên cam kết
	elif _unstick_t > 0.0:
		wish = Vector3(-dir.z, 0.0, dir.x) * _strafe_dir * speed * 0.7 # kẹt nhiều lần: lách ngang một nhịp
	else:
		wish = _decide(dir, dist)
	_smooth_velocity(wish, delta, snap)
	velocity.x = _hv.x + _kb.x
	velocity.z = _hv.z + _kb.z
	_kb = _kb.move_toward(Vector3.ZERO, 30.0 * delta)
	_try_step_up()
	_try_vault(wish, delta)
	move_and_slide()
	_track_blocked(wish, delta)
	mannequin.set_look_target(target.global_position + Vector3(0.0, 1.45, 0.0) if not target.dead else null)   # đầu/thân nhìn người chơi (IK, chỉ hiển thị)
	_animate_body(delta)


## Làm mượt vận tốc ngang: tăng tốc dần, phanh nhanh hơn; `snap` (né) đặt thẳng.
func _smooth_velocity(wish: Vector3, delta: float, snap: bool) -> void:
	if snap:
		_hv = Vector3(wish.x, 0.0, wish.z)
		return
	var M: Dictionary = Global.BOT_MOVE
	var w := Vector3(wish.x, 0.0, wish.z)
	var rate: float = float(M["accel"]) if w.length_squared() > 0.01 else float(M["decel"])
	_hv = _hv.move_toward(w, rate * delta)
	if _vault_push_t > 0.0:
		_vault_push_t -= delta
		_hv = _vault_dir * float(M["vault_push"]) # đang bật lên: đẩy tiến qua mép


## Nhảy leo: đang đi bị một khối tĩnh cao hơn bậc (STEP_HEIGHT) chắn, mà người chơi ở cao hơn (hoặc đang kẹt),
## và nóc khối thấp hơn `vault_max` -> bật lên qua mép. Navmesh không có đường lên bệ cao nên bot dừng ở chân bệ rồi nhảy.
func _try_vault(wish: Vector3, _delta: float) -> void:
	if _vault_cd > 0.0 or not is_on_floor() or _vault_push_t > 0.0:
		return
	var flat := Vector3(wish.x, 0.0, wish.z)
	if dead:
		return
	var higher: bool = target.global_position.y > global_position.y + 0.8
	if higher and flat.length() < 0.5:
		# Đã tới cuối đường navmesh (chân bệ) và đứng yên: hướng thẳng về phía người chơi để nhảy lên.
		var tt: Vector3 = target.global_position - global_position
		tt.y = 0.0
		if tt.length() < 8.0 and tt.length() > 0.1:
			flat = tt.normalized()
	if flat.length() < 0.5:
		return
	if not higher and _force_nav_t <= 0.0:
		return
	var dirn: Vector3 = flat.normalized()
	var motion: Vector3 = dirn * 0.6
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, motion, hit):
		return
	if not (hit.get_collider() is StaticBody3D) or absf(hit.get_normal().y) > 0.6:
		return
	var into := Vector3(-hit.get_normal().x, 0.0, -hit.get_normal().z)
	if into.length() < 0.1 or into.normalized().dot(dirn) < 0.5:
		return # chỉ nhảy khi đang đi thẳng vào mặt khối, không phải lướt dọc mép
	dirn = into.normalized()
	motion = dirn * 0.6
	var vmax: float = float(Global.BOT_MOVE["vault_max"])
	var h: float = STEP_HEIGHT + 0.25
	while h <= vmax:
		var up := Vector3.UP * h
		if test_move(global_transform, up):
			return # có trần
		if not test_move(global_transform.translated(up), motion):
			velocity.y = sqrt(2.0 * GRAVITY * (h + 0.35))
			_vault_dir = dirn
			_vault_push_t = 0.45
			_vault_cd = float(Global.BOT_MOVE["vault_cd"])
			return
		h += 0.25


## Muốn đi mà gần như không nhúc nhích (vật cản thấp như thùng, góc tường) -> ép đi theo navmesh một lúc
## thay vì cứ húc thẳng; hết kẹt thì quay lại đường thẳng.
func _track_blocked(wish: Vector3, delta: float) -> void:
	_force_nav_t = maxf(_force_nav_t - delta, 0.0)
	var want: float = Vector2(wish.x, wish.z).length()
	var moved: float = Vector2(get_position_delta().x, get_position_delta().z).length()
	if want > 1.0 and moved < want * delta * 0.25:
		_blocked_t += delta
		if _blocked_t > 0.4:
			_force_nav_t = 1.5
			_blocked_t = 0.0
			_blocked_count += 1
			_blocked_win = 3.0
			if _blocked_count >= 2: # ép navmesh vẫn kẹt: lách ngang một nhịp rồi thử lại
				_unstick_t = float(Global.BOT_MOVE["unstick_time"])
				_strafe_dir = -_strafe_dir
				_blocked_count = 0
	else:
		_blocked_t = maxf(_blocked_t - delta, 0.0)


## Leo bậc: đang đi trên sàn mà bị chặn bởi một mép tĩnh thấp hơn STEP_HEIGHT (chỗ nối dốc - bệ) thì
## nhấc lên qua mép. CharacterBody3D không tự leo bậc nên bot sẽ đứng kẹt trước mép nếu thiếu bước này.
func _try_step_up() -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < 0.5 or not is_on_floor():
		return
	var motion: Vector3 = flat.normalized() * 0.4
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, motion, hit):
		return
	if not (hit.get_collider() is StaticBody3D) or absf(hit.get_normal().y) > 0.6:
		return # chỉ leo qua mép tường tĩnh dựng đứng, không leo lên bot khác / dốc
	var up := Vector3.UP * STEP_HEIGHT
	if test_move(global_transform, up) or test_move(global_transform.translated(up), motion):
		return # có trần chặn, hoặc là tường cao thật
	global_position += up
	velocity.y = 0.0


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
	if keep > 0.0 and _cover_t > 0.0 and _cover_pt != Vector3.INF:
		# Vừa bắn xong: chạy vào chỗ nấp (che tầm nhìn người chơi) chờ nạp, rồi ló ra bắn tiếp.
		var co: Vector3 = _cover_pt - global_position
		co.y = 0.0
		if co.length() > 0.8:
			return _navigate(_cover_pt, co.normalized(), co.length()) * spd
		return Vector3.ZERO
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
		_maybe_take_cover()
	if bool(cfg.get("bombs", false)) and _shoot_cd <= 0.0 and dist >= float(Global.BOMB["min_range"]) and dist <= float(Global.BOMB["max_range"]) and _has_line_of_sight():
		_shoot_cd = float(Global.BOMB["interval"]) * randf_range(0.85, 1.15)
		_throw_bomb()
		_maybe_take_cover()
	return wish


## Sau mỗi lần bắn, có xác suất `cover_chance` tìm chỗ nấp gần và chạy vào đó cho tới lượt bắn kế.
func _maybe_take_cover() -> void:
	var M: Dictionary = Global.BOT_MOVE
	_cover_pt = Vector3.INF
	if randf() >= float(M["cover_chance"]):
		return
	_cover_pt = _find_cover(float(M["cover_radius"]))
	if _cover_pt != Vector3.INF:
		_cover_t = clampf(_shoot_cd * 0.8, 0.6, 2.5)


## Điểm nấp: thử 8 hướng x 2 bán kính quanh bot, nằm trên navmesh, ray từ điểm đó tới ngực người chơi bị chắn.
## Chọn điểm gần bot nhất; không có thì INF.
func _find_cover(radius: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var nmap: RID = get_world_3d().navigation_map
	var has_nav: bool = not NavigationServer3D.map_get_regions(nmap).is_empty()
	var best: Vector3 = Vector3.INF
	var best_d: float = INF
	var a0: float = randf() * TAU
	for r in [radius * 0.5, radius]:
		for k in 8:
			var ang: float = a0 + TAU * float(k) / 8.0
			var c: Vector3 = global_position + Vector3(cos(ang), 0.0, sin(ang)) * r
			if has_nav:
				c = NavigationServer3D.map_get_closest_point(nmap, c)
			if absf(c.y - global_position.y) > 1.0 or c.distance_to(target.global_position) < 6.0:
				continue
			var q := PhysicsRayQueryParameters3D.create(c + Vector3(0.0, 1.2, 0.0), _chest(target), Global.L_WORLD)
			q.exclude = [get_rid()]
			if space.intersect_ray(q).is_empty():
				continue # vẫn thấy người chơi: không phải chỗ nấp
			var d: float = c.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = c
		if best != Vector3.INF:
			return best
	return Vector3.INF


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
		var nmap: RID = get_world_3d().navigation_map
		if not NavigationServer3D.map_get_regions(nmap).is_empty():
			goal = NavigationServer3D.map_get_closest_point(nmap, goal) # điểm bọc sườn phải nằm trên navmesh (không trong tường)
	return _navigate(goal, dir, dist) * spd


## Thứ hạng của bot trong số bot cận chiến còn sống (0 = gần người chơi nhất).
func _melee_rank() -> int:
	var now: int = Engine.get_physics_frames()
	if now < _rank_until:
		return _rank_cache   # tính lại tối đa 5 lần/giây mỗi bot (vòng lặp O(số bot) trên mỗi bot ở gần)
	_rank_until = now + 12
	_rank_cache = _compute_melee_rank()
	return _rank_cache


func _compute_melee_rank() -> int:
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
	if not ready or (_force_nav_t <= 0.0 and level_diff < 0.8 and dist < 25.0 and _has_line_of_sight()):
		return _steer(goal_dir)
	_path_t -= get_physics_process_delta_time()
	if _path_t <= 0.0:
		var far: bool = global_position.distance_to(target.global_position) > float(Global.BOT_MOVE["far_dist"])
		_path_t = float(Global.BOT_MOVE["far_path_interval"] if far else Global.BOT_MOVE["path_interval"])
		_path = NavigationServer3D.map_get_path(map, global_position, goal, true)
	var pick: int = -1
	for i in range(1, _path.size()):
		var off0: Vector3 = _path[i] - global_position
		off0.y = 0.0
		if off0.length() > 0.4 or i == _path.size() - 1:
			pick = i
			break
	if pick < 0:
		return _steer(goal_dir)
	# Nhìn trước: nếu thấy thẳng được điểm ngoặt xa hơn (trong tầm lookahead, cùng độ cao) thì nhắm điểm đó -> đường cong mượt, không bẻ góc ở từng điểm.
	var la: float = float(Global.BOT_MOVE["lookahead"])
	var j: int = pick + 1
	while j < _path.size() and j <= pick + 3:
		var p: Vector3 = _path[j]
		if absf(p.y - global_position.y) > 0.8 or p.distance_to(global_position) > la or not _clear_walk(p):
			break
		pick = j
		j += 1
	var off: Vector3 = _path[pick] - global_position
	off.y = 0.0
	return off.normalized() if off.length() > 0.05 else Vector3.ZERO


## Đi thẳng tới `p` không bị khối nào chắn (ray thấp + ray ngang đầu gối, cách xa mép một chút).
func _clear_walk(p: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for h in [0.3, 1.0]:
		var o: Vector3 = global_position + Vector3(0.0, h, 0.0)
		var q := PhysicsRayQueryParameters3D.create(o, Vector3(p.x, o.y, p.z), Global.L_WORLD)
		q.exclude = [get_rid()]
		if not space.intersect_ray(q).is_empty():
			return false
	return true


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
	# Ray ở nhiều độ cao: vật cản thấp (thùng gỗ/thùng nổ cao ~0.5 m) nằm dưới ray ngang hông nên phải quét cả thấp.
	var space := get_world_3d().direct_space_state
	var hit: Dictionary = {}
	var best: float = INF
	for h in [0.2, 0.55, 1.0]:
		var origin: Vector3 = global_position + Vector3(0.0, h, 0.0)
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 2.0, Global.L_WORLD)
		q.exclude = [get_rid()]
		var r: Dictionary = space.intersect_ray(q)
		if not r.is_empty():
			var d: float = origin.distance_to(r["position"])
			if d < best:
				best = d
				hit = r
	var normal: Vector3 = Vector3(hit["normal"].x, 0.0, hit["normal"].z) if not hit.is_empty() else Vector3.ZERO
	if normal.length() < 0.01:
		# thoáng (hoặc chỉ là mặt dốc/sàn): nếu đã thoáng đủ lâu thì bỏ hướng lách đã chọn
		_steer_clear_t += get_physics_process_delta_time()
		if _steer_clear_t > 0.4:
			_steer_hold = Vector3.ZERO
		return dir
	_steer_clear_t = 0.0
	var tangent: Vector3 = normal.normalized().cross(Vector3.UP).normalized()
	if _steer_hold != Vector3.ZERO:
		# Đã chọn một bên để lách: giữ bên đó (nếu không sẽ lắc qua lắc lại ở mép vật cản).
		if tangent.dot(_steer_hold) < 0.0:
			tangent = -tangent
	else:
		var side: float = tangent.dot(dir)
		if absf(side) < 0.15:
			tangent *= _strafe_dir # húc vuông góc: chọn một bên thay vì đứng yên
		elif side < 0.0:
			tangent = -tangent
	_steer_hold = tangent
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

## Vùng bị trúng theo độ cao điểm trúng (nếu đòn có "point"): "head" | "torso" | "legs". Đòn kiếm không có điểm = torso.
func hit_zone(hit: Dictionary) -> String:
	var pt: Variant = hit.get("point")
	if not (pt is Vector3):
		return "torso"
	var h: float = (pt as Vector3).y - global_position.y
	if h >= float(Global.ANIM["head_zone"]):
		return "head"
	if h <= float(Global.ANIM["leg_zone"]):
		return "legs"
	return "torso"


## Chỉ hiển thị (M30): hướng đi cục bộ + quay người + trạng thái núp/vault cho animator. Không đổi vận tốc hay AI.
func _animate_body(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed: float = flat.length()
	var yaw: float = mannequin.global_rotation.y
	var turn: float = rad_to_deg(angle_difference(_prev_yaw, yaw)) / maxf(delta, 0.0001)
	_prev_yaw = yaw
	if mannequin.has_method("set_motion"):
		var dir := Vector2(0.0, 1.0)
		if speed > 0.3:
			var lv: Vector3 = mannequin.global_transform.basis.inverse() * flat
			dir = Vector2(lv.x, -lv.z).normalized()
		mannequin.set_motion(dir, clampf(turn, -720.0, 720.0))
	var st: String = ""
	if _vault_push_t > 0.0:
		st = "vault"
	elif _cover_t > 0.0 and _cover_pt != Vector3.INF and global_position.distance_to(_cover_pt) < 1.0:
		st = "cover"
	mannequin.animate(delta, speed, is_on_floor(), velocity.y, st)


func _on_hurt(hit: Dictionary, _left: float) -> void:
	_last_hit = hit
	mannequin.flash()
	var local_dir: Vector3 = mannequin.global_transform.basis.inverse() * Vector3(hit.get("direction", Vector3.ZERO))
	mannequin.play("hurt", float(Global.ANIM["hurt_time"]), {"direction": local_dir, "zone": hit_zone(hit)})


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
	var die_dir: Vector3 = mannequin.global_transform.basis.inverse() * Vector3(_last_hit.get("direction", Vector3.ZERO))
	mannequin.play("die", float(Global.ANIM["die_time"]), {"direction": die_dir, "zone": hit_zone(_last_hit)})
	mannequin.fade_out(0.3)
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(queue_free)
