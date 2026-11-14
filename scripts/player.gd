extends CharacterBody3D
## Người chơi FPS. Toàn bộ vật lý di chuyển nằm trong _physics_process (qua các hàm _move_*).
## Input đọc vào các field (move_input, want_*) để test headless tự điền (use_input = false).
## HUD/âm thanh/dây móc KHÔNG bị gọi trực tiếp — chỉ nghe Signal của Player.

signal speed_changed(speed: float)
signal state_changed(state_name: String)
signal dash_charges_changed(charges: int, max_charges: int)
signal grapple_started(point: Vector3)
signal grapple_ended
signal died

enum State { NORMAL, SLIDE, WALLRUN, GRAPPLE }

const STAND_HEIGHT: float = 1.8
const SLIDE_HEIGHT: float = 0.9
const HEAD_STAND: float = 1.6
const HEAD_SLIDE: float = 0.8

var move_input: Vector2 = Vector2.ZERO # x phải(+)/trái(-), y lùi(+)/tiến(-)
var want_jump: bool = false
var want_slide: bool = false
var want_dash: bool = false     # xung 1 lần, được tiêu thụ khi dash
var want_grapple: bool = false  # giữ
var use_input: bool = true

var state: State = State.NORMAL
var dead: bool = false
var dash_charges: int = 0

var _pitch: float = 0.0
var _last_speed: float = -1.0
var _dash_cd: float = 0.0
var _dash_recharge_t: float = 0.0
var _wall_lockout: float = 0.0
var _wall_time: float = 0.0
var _wall_normal: Vector3 = Vector3.ZERO
var _wall_side: float = 0.0
var _grapple_point: Vector3 = Vector3.ZERO
var _grapple_time: float = 0.0
var _grapple_cd: float = 0.0
var _prev_grapple: bool = false
var _shake: float = 0.0
var _redline: bool = false

@onready var head: Node3D = $Head
@onready var body_shape: CollisionShape3D = $Body
@onready var rope: Node3D = $Head/Rope
@onready var camera: Camera3D = $Head/Camera
@onready var melee: Node3D = $Head/Melee
@onready var sword_view: Node3D = $Head/SwordView
@onready var hurtbox: Area3D = $Hurtbox
@onready var parry: Node = $Parry
@onready var combat: Node = $Combat
@onready var instability: Node = $Instability


func _ready() -> void:
	dash_charges = Global.PLAYER["dash_max_charges"]
	# Signal của Player -> dây móc (con của Head). "Call down, signal up".
	grapple_started.connect(rope.show_to)
	grapple_ended.connect(rope.hide_rope)
	(body_shape.shape as CapsuleShape3D).height = STAND_HEIGHT
	# Chiến đấu: tiêm phụ thuộc rồi nối Signal của component (signal up). Hình ảnh nghe Signal.
	add_to_group("player")
	parry.setup(self)
	melee.setup(Global.TEAM_PLAYER, self)
	hurtbox.setup(Global.TEAM_PLAYER, Global.COMBAT["player_health"], parry)
	combat.setup(self, head, melee, parry)
	hurtbox.died.connect(_on_died)
	melee.clashed.connect(_on_clashed)
	melee.swing_started.connect(sword_view.play_swing)
	parry.parry_started.connect(sword_view.raise)
	# Instability: tích khi đánh trúng / parry, mất khi bị đánh; Redline tăng sát thương
	melee.hit_landed.connect(func(_hb, landed): if landed: instability.add(Global.INSTABILITY["hit_gain"]))
	parry.parried.connect(func(_h): instability.add(Global.INSTABILITY["parry_gain"]))
	hurtbox.hurt.connect(func(_h, _left): instability.lose(Global.INSTABILITY["damage_loss"]))
	instability.redline_changed.connect(_on_redline)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = Global.PLAYER["mouse_sens"]
		rotate_y(-event.relative.x * sens)
		_pitch = clampf(_pitch - event.relative.y * sens, -PI * 0.49, PI * 0.49)
		head.rotation.x = _pitch


func _process(delta: float) -> void:
	# Chỉ là hiệu ứng camera (không ảnh hưởng vật lý): nghiêng khi bám tường, hạ thấp khi trượt.
	var roll: float = 0.0
	if state == State.WALLRUN:
		roll = -_wall_side * deg_to_rad(Global.PLAYER["wall_roll_deg"])
	head.rotation.z = lerpf(head.rotation.z, roll, minf(1.0, 10.0 * delta))
	_shake = maxf(_shake - delta * 0.5, 0.0)
	var target_fov: float = 90.0 + clampf((horizontal_speed() - 10.0) * 0.5, 0.0, 18.0)
	camera.fov = lerpf(camera.fov, target_fov, minf(1.0, 6.0 * delta))
	camera.h_offset = randf_range(-1.0, 1.0) * _shake
	camera.v_offset = randf_range(-1.0, 1.0) * _shake
	var hy: float = HEAD_SLIDE if _is_crouched() else HEAD_STAND
	head.position.y = lerpf(head.position.y, hy, minf(1.0, 14.0 * delta))


func _read_input() -> void:
	move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	want_jump = Input.is_action_pressed("jump")
	want_slide = Input.is_action_pressed("slide")
	want_grapple = Input.is_action_pressed("grapple")
	if Input.is_action_just_pressed("dash"):
		want_dash = true
	combat.want_attack = Input.is_action_pressed("attack")
	combat.want_shoot = Input.is_action_pressed("shoot")
	if Input.is_action_just_pressed("parry"):
		combat.want_parry = true
	if Input.is_action_just_pressed("reload"):
		combat.want_reload = true
	if dead: # chết thì không điều khiển được
		move_input = Vector2.ZERO
		want_jump = false
		want_slide = false
		want_grapple = false
		want_dash = false
		combat.want_attack = false
		combat.want_shoot = false
		combat.want_parry = false
		combat.want_reload = false


## Rung camera (gọi từ main khi có va chạm/đòn trúng).
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func respawn(pos: Vector3) -> void:
	dead = false
	hurtbox.revive()
	combat.refill()
	instability.reset()
	global_position = pos
	velocity = Vector3.ZERO
	_set_state(State.NORMAL)


func _on_redline(active: bool) -> void:
	_redline = active
	var mult: float = float(Global.INSTABILITY["damage_mult"]) if active else 1.0
	melee.damage_mult = mult
	combat.damage_mult = mult


func _on_died() -> void:
	dead = true
	died.emit()


func _on_clashed(direction: Vector3) -> void:
	velocity += direction * float(Global.COMBAT["clash_knockback"])
	_shake = maxf(_shake, 0.05)


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _physics_process(delta: float) -> void:
	if use_input:
		_read_input()
	_tick_timers(delta)
	_try_dash()
	_try_start_grapple()

	match state:
		State.NORMAL:
			_move_normal(delta)
		State.SLIDE:
			_move_slide(delta)
		State.WALLRUN:
			_move_wallrun(delta)
		State.GRAPPLE:
			_move_grapple(delta)

	move_and_slide()

	if not dead:
		instability.tick(delta, horizontal_speed())

	var speed: float = horizontal_speed()
	if absf(speed - _last_speed) > 0.05:
		_last_speed = speed
		speed_changed.emit(speed)


func _wish_dir() -> Vector3:
	return (global_transform.basis * Vector3(move_input.x, 0.0, move_input.y)).normalized()


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(State.keys()[new_state])


# ------------------------------------------------------------------ timers / dash

func _tick_timers(delta: float) -> void:
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_wall_lockout = maxf(_wall_lockout - delta, 0.0)
	_grapple_cd = maxf(_grapple_cd - delta, 0.0)
	var max_c: int = Global.PLAYER["dash_max_charges"]
	if dash_charges < max_c:
		_dash_recharge_t -= delta * (float(Global.INSTABILITY["dash_recharge_mult"]) if _redline else 1.0)
		if _dash_recharge_t <= 0.0:
			dash_charges += 1
			_dash_recharge_t = Global.PLAYER["dash_recharge"]
			dash_charges_changed.emit(dash_charges, max_c)


func _try_dash() -> void:
	var wants: bool = want_dash
	want_dash = false # xung 1 lần
	if not wants or dash_charges <= 0 or _dash_cd > 0.0:
		return
	var dir: Vector3 = _wish_dir()
	if dir == Vector3.ZERO:
		dir = -global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized()
	# CỘNG vào vận tốc hiện tại (không thay thế) -> giữ trọn động lượng.
	var imp: float = Global.PLAYER["dash_impulse"]
	velocity.x += dir.x * imp
	velocity.z += dir.z * imp
	var max_c: int = Global.PLAYER["dash_max_charges"]
	if dash_charges == max_c:
		_dash_recharge_t = Global.PLAYER["dash_recharge"]
	dash_charges -= 1
	_dash_cd = Global.PLAYER["dash_cooldown"]
	_shake = maxf(_shake, 0.02)
	dash_charges_changed.emit(dash_charges, max_c)


# ------------------------------------------------------------------ NORMAL

func _move_normal(delta: float) -> void:
	var cfg: Dictionary = Global.PLAYER
	var wish_dir: Vector3 = _wish_dir()

	if is_on_floor():
		if want_slide and horizontal_speed() > float(cfg["slide_min_speed"]):
			_enter_slide()
			return
		if want_jump:
			# Frame nhảy KHÔNG bị ma sát -> giữ động lượng khi nhảy liên tục (bunny hop).
			velocity.y = cfg["jump_velocity"]
			_accelerate(wish_dir, cfg["walk_speed"], cfg["air_accel"], delta)
		else:
			_apply_friction(delta)
			_accelerate(wish_dir, cfg["walk_speed"], cfg["ground_accel"], delta)
	else:
		velocity.y -= float(cfg["gravity"]) * delta
		_accelerate(wish_dir, cfg["walk_speed"], cfg["air_accel"], delta)
		if _can_wallrun():
			_enter_wallrun()


## Cộng tốc độ theo wish_dir chỉ tới khi thành phần dọc wish_dir đạt wish_speed:
## vận tốc đã vượt wish_speed không bị cắt, và air-strafe vẫn cộng thêm được tốc độ.
func _accelerate(wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> void:
	if wish_dir == Vector3.ZERO:
		return
	var add: float = wish_speed - velocity.dot(wish_dir)
	if add <= 0.0:
		return
	velocity += wish_dir * minf(accel * delta, add)


func _apply_friction(delta: float) -> void:
	var speed: float = horizontal_speed()
	if speed < 0.001:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var drop: float = maxf(speed, Global.PLAYER["stop_speed"]) * float(Global.PLAYER["ground_friction"]) * delta
	var factor: float = maxf(speed - drop, 0.0) / speed
	velocity.x *= factor
	velocity.z *= factor


# ------------------------------------------------------------------ SLIDE

func _is_crouched() -> bool:
	return (body_shape.shape as CapsuleShape3D).height < STAND_HEIGHT - 0.01


func _set_crouch(on: bool) -> void:
	var cap: CapsuleShape3D = body_shape.shape
	cap.height = SLIDE_HEIGHT if on else STAND_HEIGHT
	body_shape.position.y = cap.height * 0.5


func _can_stand() -> bool:
	return not test_move(global_transform, Vector3.UP * (STAND_HEIGHT - SLIDE_HEIGHT + 0.05))


func _enter_slide() -> void:
	var cfg: Dictionary = Global.PLAYER
	var dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
	velocity += dir * float(cfg["slide_boost"])
	_set_crouch(true)
	_set_state(State.SLIDE)


func _exit_slide() -> void:
	_set_crouch(false)
	_set_state(State.NORMAL)


func _move_slide(delta: float) -> void:
	var cfg: Dictionary = Global.PLAYER
	var wish_dir: Vector3 = _wish_dir()

	if not is_on_floor():
		velocity.y -= float(cfg["gravity"]) * delta
		_accelerate(wish_dir, cfg["walk_speed"], cfg["air_accel"], delta)
		if _can_stand():
			_exit_slide()
		return

	if want_jump and _can_stand():
		velocity.y = cfg["jump_velocity"]
		_exit_slide()
		return

	# Ma sát rất nhỏ + trượt xuống dốc thì được cộng tốc độ.
	var speed: float = horizontal_speed()
	var factor: float = maxf(1.0 - float(cfg["slide_friction"]) * delta, 0.0)
	velocity.x *= factor
	velocity.z *= factor
	var n: Vector3 = get_floor_normal()
	var g := Vector3(0.0, -float(cfg["gravity"]), 0.0)
	velocity += (g - n * g.dot(n)) * delta
	_accelerate(wish_dir, cfg["walk_speed"], cfg["slide_steer"], delta)

	if (not want_slide or speed < float(cfg["slide_end_speed"])) and _can_stand():
		_exit_slide()


# ------------------------------------------------------------------ WALLRUN

## Dò tường 2 bên bằng raycast. Trả về {} nếu không có tường gần như thẳng đứng.
func _find_wall() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var origin: Vector3 = global_position + Vector3(0.0, 1.0, 0.0)
	var reach: float = Global.PLAYER["wall_ray"]
	for side in [-1.0, 1.0]:
		var dir: Vector3 = global_transform.basis.x * side
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, Global.L_WORLD)
		q.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty() and absf(hit["normal"].y) < 0.25:
			return {"normal": hit["normal"], "side": side}
	return {}


func _can_wallrun() -> bool:
	if _wall_lockout > 0.0 or move_input.y >= -0.1:
		return false
	if horizontal_speed() < float(Global.PLAYER["wall_min_speed"]):
		return false
	return not _find_wall().is_empty()


func _enter_wallrun() -> void:
	var wall: Dictionary = _find_wall()
	_wall_normal = wall["normal"]
	_wall_side = wall["side"]
	_wall_time = 0.0
	_set_state(State.WALLRUN)


func _exit_wallrun(lockout: float) -> void:
	_wall_lockout = lockout
	_set_state(State.NORMAL)


func _move_wallrun(delta: float) -> void:
	var cfg: Dictionary = Global.PLAYER
	_wall_time += delta
	var wall: Dictionary = _find_wall()
	if is_on_floor() or wall.is_empty() or _wall_time > float(cfg["wall_max_time"]):
		_exit_wallrun(cfg["wall_lockout"] * (2.5 if _wall_time > float(cfg["wall_max_time"]) else 1.0))
		return
	_wall_normal = wall["normal"]
	_wall_side = wall["side"]

	var tangent: Vector3 = _wall_normal.cross(Vector3.UP).normalized()
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	if horiz.dot(tangent) < 0.0:
		tangent = -tangent
	var speed: float = maxf(horizontal_speed(), float(cfg["wall_min_speed"]))

	if want_jump:
		var out: Vector3 = tangent * speed + _wall_normal * float(cfg["wall_jump_push"])
		velocity = Vector3(out.x, cfg["jump_velocity"], out.z)
		_exit_wallrun(cfg["wall_lockout"])
		return

	# Giữ tốc độ dọc theo tường, trọng lực gần như tắt, hơi ép sát vào tường.
	var vy: float = move_toward(velocity.y, -float(cfg["wall_fall"]), 40.0 * delta)
	var along: Vector3 = tangent * speed - _wall_normal * 1.5
	velocity = Vector3(along.x, vy, along.z)


# ------------------------------------------------------------------ GRAPPLE

func _try_start_grapple() -> void:
	var pressed: bool = want_grapple and not _prev_grapple
	_prev_grapple = want_grapple
	if not pressed or _grapple_cd > 0.0 or state == State.GRAPPLE:
		return
	var space := get_world_3d().direct_space_state
	var from: Vector3 = head.global_position
	var to: Vector3 = from - head.global_transform.basis.z * float(Global.PLAYER["grapple_range"])
	var q := PhysicsRayQueryParameters3D.create(from, to, Global.L_WORLD)
	q.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return
	if state == State.SLIDE:
		_exit_slide()
	_grapple_point = hit["position"]
	_grapple_time = 0.0
	_set_state(State.GRAPPLE)
	grapple_started.emit(_grapple_point)


func _end_grapple() -> void:
	_grapple_cd = Global.PLAYER["grapple_cooldown"]
	_set_state(State.NORMAL)
	grapple_ended.emit()


func _move_grapple(delta: float) -> void:
	var cfg: Dictionary = Global.PLAYER
	_grapple_time += delta
	var to: Vector3 = _grapple_point - head.global_position
	var dist: float = to.length()
	if not want_grapple or dist < float(cfg["grapple_stop_dist"]) or _grapple_time > float(cfg["grapple_max_time"]):
		_end_grapple() # thả ra: giữ nguyên quán tính hiện tại
		return
	var dir: Vector3 = to / dist
	# Lực kéo tăng dần theo thời gian giữ.
	var t: float = clampf(_grapple_time / float(cfg["grapple_ramp"]), 0.0, 1.0)
	var pull: float = lerpf(float(cfg["grapple_pull_start"]), float(cfg["grapple_pull_max"]), t)
	if velocity.dot(dir) < float(cfg["grapple_max_speed"]):
		velocity += dir * pull * delta
	velocity.y -= float(cfg["gravity"]) * 0.4 * delta
	_accelerate(_wish_dir(), cfg["walk_speed"], cfg["air_accel"], delta)
