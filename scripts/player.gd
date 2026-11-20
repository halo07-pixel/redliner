extends CharacterBody3D
## Người chơi FPS. Toàn bộ vật lý di chuyển nằm trong _physics_process (qua các hàm _move_*).
## Input đọc vào các field (move_input, want_*) để test headless tự điền (use_input = false).
## HUD/âm thanh/dây móc KHÔNG bị gọi trực tiếp — chỉ nghe Signal của Player.

signal speed_changed(speed: float)
signal state_changed(state_name: String)
signal dash_charges_changed(charges: int, max_charges: int)
signal stamina_changed(value: float, maximum: float)
signal slammed(position: Vector3, radius: float)
signal grapple_started(point: Vector3)
signal grapple_ended
signal died
signal footstep(speed: float)
signal ledge_climbed
signal jumped

enum State { NORMAL, SLIDE, WALLRUN, GRAPPLE, SLAM, LEDGE }
const SwordTrail = preload("res://scripts/sword_trail.gd")
const BODY_LAYER: int = 2 # render layer 2 (bit thứ hai): thân người chơi

const STAND_HEIGHT: float = 1.8
const SLIDE_HEIGHT: float = 0.9
const HEAD_STAND: float = 1.6
const HEAD_SLIDE: float = 0.8

var move_input: Vector2 = Vector2.ZERO # x phải(+)/trái(-), y lùi(+)/tiến(-)
var want_jump: bool = false
var want_slide: bool = false
var want_dash: bool = false     # xung 1 lần, được tiêu thụ khi dash
var want_grapple: bool = false  # giữ
var want_slam: bool = false     # xung 1 lần, được tiêu thụ khi slam
var use_input: bool = true

var state: State = State.NORMAL
var dead: bool = false
var dash_stamina: float = 0.0
## Số charge dash hiển thị = stamina / dash_cost (gán trực tiếp được: đặt stamina tương ứng).
var dash_charges: int:
	get:
		return int(floor(dash_stamina / float(Global.PLAYER["dash_cost"]) + 0.0001))
	set(v):
		dash_stamina = float(v) * float(Global.PLAYER["dash_cost"])

var _pitch: float = 0.0
var _last_speed: float = -1.0
var _dash_cd: float = 0.0
var _regen_delay_t: float = 0.0
var _last_charges: int = -1
var _slide_boost_cd: float = 0.0
var _slam_cd: float = 0.0
var _slam_start_y: float = 0.0
var _wall_lockout: float = 0.0
var _wall_time: float = 0.0
var _wall_normal: Vector3 = Vector3.ZERO
var _wall_side: float = 0.0
var _grapple_point: Vector3 = Vector3.ZERO
var _grapple_time: float = 0.0
var _grapple_cd: float = 0.0
var _prev_grapple: bool = false
var _shake: float = 0.0
var _coyote_t: float = 0.0
var _jump_buf_t: float = 0.0
var _prev_want_jump: bool = false
var _step_dist: float = 0.0
var _bob_phase: float = 0.0
var _cam_base: Vector3 = Vector3.ZERO
var _ledge_cd: float = 0.0
var _ledge_t: float = 0.0
var _ledge_phase: int = 0 # 0 = kéo lên, 1 = bước qua
var _ledge_target: Vector3 = Vector3.ZERO
var _ledge_dir: Vector3 = Vector3.ZERO
var _ledge_speed: float = 0.0
var _dash_anim_t: float = 0.0
var body_view: Node3D

@onready var head: Node3D = $Head
@onready var body_shape: CollisionShape3D = $Body
@onready var rope: Node3D = $Head/Rope
@onready var camera: Camera3D = $Head/Camera
@onready var melee: Node3D = $Head/Melee
@onready var viewmodel: Node3D = $Head/ViewModel
@onready var hurtbox: Area3D = $Hurtbox
@onready var parry: Node = $Parry
@onready var combat: Node = $Combat
@onready var instability: Node = $Instability


func _ready() -> void:
	_cam_base = camera.position
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
	# Thân người: ẩn với camera của chính mình (layer 2) nhưng vẫn đổ bóng.
	body_view = load("res://scripts/mannequin.gd").new()
	body_view.color = Color(0.8, 0.8, 0.85)
	body_view.kind = "swordsman"
	add_child(body_view)
	body_view.set_render_layers(BODY_LAYER)
	camera.cull_mask = 0xFFFFF & ~BODY_LAYER
	melee.clashed.connect(_on_clashed)
	melee.swing_started.connect(viewmodel.play_swing)
	SwordTrail.attach(melee)
	combat.shot_fired.connect(func(_f, _t): viewmodel.kick())
	combat.reloading_changed.connect(viewmodel.set_reloading)
	hurtbox.hurt.connect(func(h, _left): viewmodel.flinch(camera.global_transform.basis.inverse() * Vector3(h.get("direction", Vector3.ZERO))))
	# Hoạt ảnh thân chiến đấu (chỉ thấy qua bóng): nghe Signal, không ảnh hưởng logic.
	melee.swing_started.connect(func(w, a, r): body_view.play("swing", w + a + r, {"windup": w, "active": a, "recovery": r}))
	melee.staggered.connect(func(d): body_view.play("stagger", d))
	parry.parry_started.connect(func(): body_view.play("parry", float(Global.ANIM["parry_time"])))
	parry.parry_missed.connect(func(): body_view.play("parry_miss", float(Global.ANIM["parry_miss_time"])))
	hurtbox.hurt.connect(func(h, _left): body_view.play("hurt", float(Global.ANIM["hurt_time"]), {"direction": body_view.global_transform.basis.inverse() * Vector3(h.get("direction", Vector3.ZERO))}))
	combat.shot_fired.connect(func(_f, _t): body_view.play("shoot", float(Global.ANIM["shoot_time"])))
	parry.parry_started.connect(viewmodel.raise)
	parry.parried.connect(func(_h): viewmodel.parry_hit())
	parry.parry_missed.connect(viewmodel.parry_fail)
	# Instability "mất thế": thua clash / parry hụt / bị parry thì tăng; parry thành công và đánh trúng thì giảm.
	melee.clashed.connect(func(_d): instability.clash_penalty())
	melee.got_parried.connect(func(): instability.add(Global.INSTABILITY["parried_loss"]))
	parry.parry_missed.connect(func(): instability.add(Global.INSTABILITY["parry_miss_loss"]))
	parry.parried.connect(func(_h): instability.lose(Global.INSTABILITY["parry_relief"]))
	melee.hit_landed.connect(func(_hb, landed): if landed: instability.lose(Global.INSTABILITY["hit_relief"]))
	instability.destabilized_changed.connect(_on_destabilized)
	combat.shot_fired.connect(_on_shot_recoil)
	hurtbox.hurt.connect(func(_h, _l): cancel_ledge())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = float(Global.PLAYER["mouse_sens"]) * float(Global.settings["mouse_mult"]) * (camera.fov / 90.0) # ngắm thì chậm tay lại
		apply_look(event.relative * sens)
		viewmodel.add_look(event.relative)


## Xoay nhìn theo (yaw, pitch) radian: dùng chung cho chuột và cần phải tay cầm.
func apply_look(delta_rad: Vector2) -> void:
	var inv: float = -1.0 if bool(Global.settings["invert_y"]) else 1.0
	rotate_y(-delta_rad.x)
	_pitch = clampf(_pitch - delta_rad.y * inv, -PI * 0.49, PI * 0.49)
	head.rotation.x = _pitch


func _process(delta: float) -> void:
	# Chỉ là hiệu ứng camera (không ảnh hưởng vật lý): nghiêng khi bám tường, hạ thấp khi trượt.
	if use_input and not dead:
		var stick: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if stick != Vector2.ZERO:
			var k: float = float(Global.PLAYER["gamepad_look_speed"]) * float(Global.settings["pad_sens"]) * (camera.fov / 90.0)
			apply_look(stick * k * delta)
			viewmodel.add_look(stick * 12.0)
	var roll: float = 0.0
	if state == State.WALLRUN:
		roll = -_wall_side * deg_to_rad(Global.PLAYER["wall_roll_deg"])
	elif not Global.reduced_fx and is_on_floor():
		roll = -move_input.x * deg_to_rad(Global.PLAYER["strafe_roll_deg"]) * clampf(horizontal_speed() / 9.0, 0.0, 1.0)
	head.rotation.z = lerpf(head.rotation.z, roll, minf(1.0, 10.0 * delta))
	_shake = maxf(_shake - delta * 0.5, 0.0)
	var target_fov: float = float(Global.settings["fov"]) + clampf((horizontal_speed() - 10.0) * 0.5, 0.0, 18.0)
	var zoom: float = combat.zoom_fov()
	if zoom > 0.0:
		target_fov = zoom
	camera.fov = lerpf(camera.fov, target_fov, minf(1.0, (14.0 if zoom > 0.0 else 6.0) * delta))
	_update_bob(delta)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake
	camera.v_offset = randf_range(-1.0, 1.0) * _shake
	viewmodel.update(delta, horizontal_speed(), is_on_floor(), _anim_state_name(), move_input.x)
	var hy: float = HEAD_SLIDE if _is_crouched() else HEAD_STAND
	head.position.y = lerpf(head.position.y, hy, minf(1.0, 14.0 * delta))


## Lắc đầu khi chạy trên sàn (chỉ hình ảnh); tắt khi giảm hiệu ứng hoặc đặt bob = 0.
func _update_bob(delta: float) -> void:
	var amp: float = float(Global.PLAYER["bob_amplitude"]) * float(Global.settings["bob"])
	var moving: bool = state == State.NORMAL and is_on_floor() and horizontal_speed() > 1.0
	if Global.reduced_fx or amp <= 0.0 or not moving:
		camera.position = camera.position.lerp(_cam_base, minf(1.0, 12.0 * delta))
		return
	_bob_phase += horizontal_speed() * delta * float(Global.PLAYER["bob_frequency"]) * TAU
	var k: float = clampf(horizontal_speed() / 9.0, 0.0, 1.5)
	var target := _cam_base + Vector3(sin(_bob_phase * 0.5) * amp * 0.6, absf(sin(_bob_phase * 0.5)) * amp * k, 0.0)
	camera.position = camera.position.lerp(target, minf(1.0, 18.0 * delta))


func _read_input() -> void:
	move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	want_jump = Input.is_action_pressed("jump")
	want_slide = Input.is_action_pressed("slide")
	want_grapple = Input.is_action_pressed("grapple")
	if Input.is_action_just_pressed("dash"):
		want_dash = true
	if Input.is_action_just_pressed("slam"):
		want_slam = true
	combat.want_attack = Input.is_action_pressed("attack")
	combat.want_shoot = Input.is_action_pressed("shoot")
	if Input.is_action_just_pressed("parry"):
		combat.want_parry = true
	if Input.is_action_just_pressed("reload"):
		combat.want_reload = true
	if Input.is_action_just_pressed("heavy"):
		combat.want_heavy = true
	combat.want_zoom = Input.is_action_pressed("zoom")
	for i in Global.WEAPON_ORDER.size():
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			combat.want_weapon = i
	if Input.is_action_just_pressed("weapon_next"):
		combat.want_cycle = 1
	if Input.is_action_just_pressed("weapon_prev"):
		combat.want_cycle = -1
	if dead: # chết thì không điều khiển được
		move_input = Vector2.ZERO
		want_jump = false
		want_slide = false
		want_grapple = false
		want_dash = false
		want_slam = false
		combat.want_attack = false
		combat.want_shoot = false
		combat.want_parry = false
		combat.want_reload = false
		combat.want_heavy = false
		combat.want_zoom = false


## Rung camera (gọi từ main khi có va chạm/đòn trúng).
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount * (float(Global.FX["reduced_shake"]) if Global.reduced_fx else 1.0))


func respawn(pos: Vector3) -> void:
	dead = false
	hurtbox.revive()
	combat.refill()
	instability.reset()
	global_position = pos
	velocity = Vector3.ZERO
	_set_state(State.NORMAL)
	body_view.clear_overlay()
	viewmodel.reset()


## Destabilized: huỷ đòn đang đánh, khoá kiếm/parry/bắn, stamina dash về 0 (ngừng hồi trong lúc mất thế).
func _on_destabilized(active: bool) -> void:
	parry.locked = active
	if active:
		melee.stagger(float(Global.INSTABILITY["destabilized_time"]))
		dash_stamina = 0.0
		_emit_dash()
		_shake = maxf(_shake, 0.1)


func _on_died() -> void:
	body_view.play("die", float(Global.ANIM["die_time"]))
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
	_tick_feel(delta)
	if state == State.LEDGE and (want_dash or want_grapple or want_slam):
		cancel_ledge()
	_try_dash()
	_try_start_grapple()
	_try_slam()

	match state:
		State.NORMAL:
			_move_normal(delta)
		State.SLIDE:
			_move_slide(delta)
		State.WALLRUN:
			_move_wallrun(delta)
		State.GRAPPLE:
			_move_grapple(delta)
		State.SLAM:
			_move_slam(delta)
		State.LEDGE:
			_move_ledge(delta)

	move_and_slide()
	_tick_footsteps(delta)
	if state == State.SLAM and is_on_floor():
		_land_slam()
	_animate_body(delta)

	if not dead:
		instability.tick(delta)

	var speed: float = horizontal_speed()
	if absf(speed - _last_speed) > 0.05:
		_last_speed = speed
		speed_changed.emit(speed)


## Đẩy trạng thái xuống hình nhân (call down). Chỉ hiển thị, không ảnh hưởng vật lý.
func _animate_body(delta: float) -> void:
	_dash_anim_t = maxf(_dash_anim_t - delta, 0.0)
	body_view.animate(delta, horizontal_speed(), is_on_floor(), velocity.y, _anim_state_name(), _wall_side)


## Tên trạng thái dùng chung cho hoạt ảnh thân và viewmodel: "" | slide | wallrun | grapple | dash.
func _anim_state_name() -> String:
	match state:
		State.SLIDE:
			return "slide"
		State.WALLRUN:
			return "wallrun"
		State.GRAPPLE:
			return "grapple"
	return "dash" if _dash_anim_t > 0.0 else ""


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
	_slide_boost_cd = maxf(_slide_boost_cd - delta, 0.0)
	_slam_cd = maxf(_slam_cd - delta, 0.0)
	var cfg: Dictionary = Global.PLAYER
	_regen_delay_t = maxf(_regen_delay_t - delta, 0.0)
	if dash_stamina < float(cfg["dash_stamina_max"]) and _regen_delay_t <= 0.0 and not instability.destabilized:
		dash_stamina = minf(dash_stamina + float(cfg["dash_regen"]) * delta, float(cfg["dash_stamina_max"]))
		_emit_dash()


func _emit_dash() -> void:
	stamina_changed.emit(dash_stamina, Global.PLAYER["dash_stamina_max"])
	if dash_charges != _last_charges:
		_last_charges = dash_charges
		dash_charges_changed.emit(dash_charges, Global.PLAYER["dash_max_charges"])


func _try_dash() -> void:
	var wants: bool = want_dash
	want_dash = false # xung 1 lần
	if not wants or dash_stamina < float(Global.PLAYER["dash_cost"]) or _dash_cd > 0.0:
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
	dash_stamina -= float(Global.PLAYER["dash_cost"])
	_regen_delay_t = Global.PLAYER["dash_regen_delay"]
	_dash_cd = Global.PLAYER["dash_cooldown"]
	_shake = maxf(_shake, 0.02)
	_dash_anim_t = float(Global.ANIM["dash_time"])
	_emit_dash()


# ------------------------------------------------------------------ NORMAL

func _move_normal(delta: float) -> void:
	var cfg: Dictionary = Global.PLAYER
	var wish_dir: Vector3 = _wish_dir()

	if is_on_floor():
		if want_slide and horizontal_speed() > float(cfg["slide_min_speed"]):
			_enter_slide()
			return
		if _jump_requested():
			# Frame nhảy KHÔNG bị ma sát -> giữ động lượng khi nhảy liên tục (bunny hop).
			_do_jump()
			_accelerate(wish_dir, cfg["walk_speed"], cfg["air_accel"], delta)
		else:
			_apply_friction(delta)
			_accelerate(wish_dir, cfg["walk_speed"], cfg["ground_accel"], delta)
	else:
		velocity.y -= float(cfg["gravity"]) * delta
		_accelerate(wish_dir, cfg["walk_speed"], cfg["air_accel"], delta)
		if _coyote_t > 0.0 and _jump_requested() and velocity.y <= 0.5:
			_do_jump() # coyote: vừa rời mép sàn vẫn nhảy được
		elif _try_ledge():
			return
		elif _can_wallrun():
			_enter_wallrun()


# ------------------------------------------------------------------ cảm giác: coyote, buffer, trèo gờ, bước chân

func _tick_feel(delta: float) -> void:
	var cfg: Dictionary = Global.PLAYER
	if want_jump and not _prev_want_jump:
		_jump_buf_t = float(cfg["jump_buffer"])
	else:
		_jump_buf_t = maxf(_jump_buf_t - delta, 0.0)
	_prev_want_jump = want_jump
	if is_on_floor():
		_coyote_t = float(cfg["coyote_time"])
	else:
		_coyote_t = maxf(_coyote_t - delta, 0.0)
	_ledge_cd = maxf(_ledge_cd - delta, 0.0)


func _jump_requested() -> bool:
	return want_jump or _jump_buf_t > 0.0


func _do_jump() -> void:
	velocity.y = Global.PLAYER["jump_velocity"]
	_coyote_t = 0.0
	_jump_buf_t = 0.0
	jumped.emit()


## Phát signal footstep theo quãng đường đi bộ trên sàn (không phát khi trượt/bay/chạy tường).
func _tick_footsteps(delta: float) -> void:
	if state != State.NORMAL or not is_on_floor() or horizontal_speed() < 1.0:
		return
	_step_dist += horizontal_speed() * delta
	if _step_dist >= float(Global.PLAYER["step_stride"]):
		_step_dist = 0.0
		footstep.emit(horizontal_speed())


## Dò bệ phía trước để trèo: tường ngang ngực, đỉnh bệ trống và đủ chỗ đứng. Chỉ khi đang giữ phím tiến,
## đang rơi / gần đỉnh nhảy. Trả về true nếu bắt đầu trèo.
func _try_ledge() -> bool:
	var cfg: Dictionary = Global.PLAYER
	if _ledge_cd > 0.0 or dead or move_input.y > -0.3 or velocity.y > float(cfg["ledge_max_rise_speed"]):
		return false
	var fwd: Vector3 = -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var feet: Vector3 = global_position
	var space := get_world_3d().direct_space_state
	var reach: float = float(cfg["ledge_reach"])
	var chest := PhysicsRayQueryParameters3D.create(feet + Vector3(0.0, 1.0, 0.0), feet + Vector3(0.0, 1.0, 0.0) + fwd * reach, Global.L_WORLD)
	var wall: Dictionary = space.intersect_ray(chest)
	if wall.is_empty() or absf((wall["normal"] as Vector3).y) > 0.3:
		return false
	var inset: Vector3 = (wall["position"] as Vector3) + fwd * 0.45
	var top_from: Vector3 = Vector3(inset.x, feet.y + float(cfg["ledge_max_height"]) + 0.4, inset.z)
	var down := PhysicsRayQueryParameters3D.create(top_from, top_from - Vector3(0.0, float(cfg["ledge_max_height"]) + 0.4 - float(cfg["ledge_min_height"]) + 0.5, 0.0), Global.L_WORLD)
	var top: Dictionary = space.intersect_ray(down)
	if top.is_empty() or (top["normal"] as Vector3).y < 0.7:
		return false
	var height: float = (top["position"] as Vector3).y - feet.y
	if height < float(cfg["ledge_min_height"]) or height > float(cfg["ledge_max_height"]):
		return false
	# Đủ chỗ đứng trên bệ?
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = STAND_HEIGHT - 0.2
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	var stand: Vector3 = Vector3(inset.x, (top["position"] as Vector3).y + 0.05, inset.z)
	q.transform = Transform3D(Basis.IDENTITY, stand + Vector3(0.0, cap.height * 0.5 + 0.1, 0.0))
	q.collision_mask = Global.L_WORLD
	if not space.intersect_shape(q, 1).is_empty():
		return false
	_begin_ledge(fwd, stand)
	return true


func _begin_ledge(fwd: Vector3, target: Vector3) -> void:
	_ledge_dir = fwd
	_ledge_target = target
	_ledge_t = 0.0
	_ledge_phase = 0
	_ledge_speed = clampf(horizontal_speed(), 4.0, 12.0)
	velocity = Vector3.ZERO
	_set_state(State.LEDGE)


## Hai pha: kéo thẳng lên dọc mép, rồi bước qua mặt bệ. Dùng vận tốc để va chạm vẫn đúng.
func _move_ledge(delta: float) -> void:
	var cfg: Dictionary = Global.PLAYER
	_ledge_t += delta
	var goal: Vector3 = Vector3(global_position.x, _ledge_target.y, global_position.z) if _ledge_phase == 0 else _ledge_target
	var time_left: float = maxf(float(cfg["ledge_up_time"] if _ledge_phase == 0 else cfg["ledge_over_time"]) - (_ledge_t if _ledge_phase == 0 else _ledge_t), delta)
	velocity = (goal - global_position) / time_left
	var arrived: bool = global_position.distance_to(goal) < 0.08
	if _ledge_phase == 0 and (arrived or _ledge_t >= float(cfg["ledge_up_time"])):
		_ledge_phase = 1
		_ledge_t = 0.0
	elif _ledge_phase == 1 and (arrived or _ledge_t >= float(cfg["ledge_over_time"])):
		_end_ledge(true)


func _end_ledge(done: bool) -> void:
	_ledge_cd = float(Global.PLAYER["ledge_cooldown"])
	velocity = _ledge_dir * _ledge_speed if done else Vector3.ZERO
	_set_state(State.NORMAL)
	if done:
		ledge_climbed.emit()


## Huỷ trèo gờ (bị đánh, dash, móc, đập đất): rơi xuống tiếp.
func cancel_ledge() -> void:
	if state == State.LEDGE:
		_end_ledge(false)


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
	if _slide_boost_cd <= 0.0:
		velocity += dir * float(cfg["slide_boost"])
		_slide_boost_cd = cfg["slide_boost_cooldown"]
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

	if _jump_requested() and _can_stand():
		_do_jump()
		# Slide hop: nhảy ngay khi đang trượt giữ trọn động lượng và được cộng thêm một chút.
		if horizontal_speed() < float(cfg["slide_hop_max_speed"]):
			var hop_dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
			velocity += hop_dir * float(cfg["slide_hop_boost"])
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
	if not want_grapple:
		_release_redirect() # tự nhả: xoay vận tốc theo hướng nhìn thay vì giữ nguyên hướng kéo
		_end_grapple()
		return
	if dist < float(cfg["grapple_stop_dist"]) or _grapple_time > float(cfg["grapple_max_time"]):
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


## Nhả móc chủ động: xoay vận tốc về hướng nhìn (giữ độ lớn) + cộng một chút dọc hướng nhìn.
func _release_redirect() -> void:
	var cfg: Dictionary = Global.PLAYER
	var speed: float = velocity.length()
	if speed < 8.0:
		return
	var look: Vector3 = -head.global_transform.basis.z
	var blended: Vector3 = velocity.lerp(look * speed, float(cfg["grapple_redirect_blend"]))
	velocity = blended.normalized() * speed + look * float(cfg["grapple_release_boost"])


# ------------------------------------------------------------------ SLAM

func _height_above_ground() -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 60.0, Global.L_WORLD)
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return 999.0 if hit.is_empty() else global_position.y - hit["position"].y


func _try_slam() -> void:
	var wants: bool = want_slam
	want_slam = false # xung 1 lần
	if not wants or dead or _slam_cd > 0.0 or is_on_floor() or state == State.SLAM or state == State.WALLRUN:
		return
	if _height_above_ground() < float(Global.PLAYER["slam_min_height"]):
		return
	if state == State.GRAPPLE:
		_end_grapple()
	if state == State.SLIDE:
		_exit_slide()
	_slam_start_y = global_position.y
	_set_state(State.SLAM)


func _move_slam(delta: float) -> void:
	var cfg: Dictionary = Global.PLAYER
	velocity.y = -float(cfg["slam_speed"])
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	_accelerate(_wish_dir(), cfg["slam_air_steer"], cfg["air_accel"], delta)


## Chạm đất: sóng xung kích gây sát thương + choáng bot gần đó, người chơi nảy lên theo độ cao rơi.
func _land_slam() -> void:
	var cfg: Dictionary = Global.PLAYER
	var fallen: float = _slam_start_y - global_position.y
	var radius: float = cfg["slam_radius"]
	for b in get_tree().get_nodes_in_group("bots"):
		if b.dead:
			continue
		var to: Vector3 = b.global_position - global_position
		if to.length() > radius:
			continue
		var dir: Vector3 = to.normalized() if to.length() > 0.01 else Vector3.FORWARD
		b.hurtbox.take_hit({"damage": float(cfg["slam_damage"]), "kind": "slam", "source": self, "direction": dir})
		b.melee.stagger(float(cfg["slam_stagger"]))
	velocity.y = minf(float(cfg["slam_speed"]) * float(cfg["slam_bounce"]) + fallen * 0.1, float(cfg["slam_bounce_max"]))
	_slam_cd = cfg["slam_cooldown"]
	_shake = maxf(_shake, 0.08)
	_set_state(State.NORMAL)
	slammed.emit(global_position, radius)


## Bị đẩy bởi vụ nổ của chính mình (rocket-jump): cộng thẳng vào vận tốc, bỏ giới hạn tốc độ recoil.
func apply_blast(push: Vector3) -> void:
	velocity += push
	if state == State.GRAPPLE:
		_end_grapple()
	_shake = maxf(_shake, 0.06)


## Recoil movement: bắn khi đang trên không đẩy người chơi ngược hướng nòng.
func _on_shot_recoil(from: Vector3, to: Vector3) -> void:
	if is_on_floor() or state == State.SLAM:
		return
	if velocity.length() > float(Global.PLAYER["recoil_max_speed"]):
		return
	var dir: Vector3 = (to - from).normalized()
	velocity -= dir * float(Global.PLAYER["recoil_impulse"]) * float(combat.cfg()["recoil"])
