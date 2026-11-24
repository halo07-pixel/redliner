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
signal grapple_target_changed(valid: bool) # tâm ngắm đang có điểm móc được (HUD hiện chấm)
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
## Hệ số / chỉ số nâng cấp (M35; main áp từ RunProgress).
var speed_mult: float = 1.0
var stamina_regen_mult: float = 1.0
var pickup_magnet: float = float(Global.XP["magnet_base"])
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
const Motion = preload("res://scripts/motion.gd")
var _roll_v: float = 0.0            # vận tốc lò xo camera (M26)
var _fov_v: float = 0.0
var _head_v: float = 0.0
var _redirect_target: Vector3 = Vector3.ZERO   # nhả móc: vận tốc đích, xoay dần trong grapple_redirect_time
var _redirect_rate: float = 0.0
var _redirect_left: float = 0.0
var _grapple_chain: float = 0.0     # M33: số lần móc liên tiếp (giảm dần theo thời gian)
var _grapple_len: float = 0.0       # độ dài dây hiện tại (chỉ ngắn lại)
var _grapple_taut: bool = false     # dây đang căng ở khung gần nhất
var _target_valid: bool = false
var _grapple_node: Node3D = null    # Titan đang móc (điểm móc bám theo thân)
var _grapple_local: Vector3 = Vector3.ZERO
var _target_timer: float = 0.0
var _shake: float = 0.0
var _coyote_t: float = 0.0
var _jump_buf_t: float = 0.0
var _prev_want_jump: bool = false
var _step_dist: float = 0.0
var _step_sign: float = 1.0   # đổi dấu mỗi bước chân: camera lắc ngang luân phiên trái/phải
var _cam_fx: Vector3 = Vector3.ZERO     # lệch camera do hiệu ứng (z: lao khi chém, y: đập khi tiếp đất), có lò xo
var _cam_fx_v: Vector3 = Vector3.ZERO
var _pk_rot: Vector2 = Vector2.ZERO    # giật camera do parry (x: pitch, y: roll; độ), tắt dần bằng lò xo
var _pk_rot_v: Vector2 = Vector2.ZERO
var _fall_peak: float = 0.0          # vận tốc rơi lớn nhất trong lần đang trên không (cho viewmodel: tiếp đất mạnh)
var _pk_fov: float = 0.0               # FOV nảy do parry (độ)
var _pk_fov_v: float = 0.0
var _fall_vy: float = 0.0                # vận tốc rơi lớn nhất từ lúc rời đất (để tính cú đập khi tiếp đất)
var _was_floor_vis: bool = true
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
	melee.clashed.connect(func(d): viewmodel.clash(camera.global_transform.basis.inverse() * Vector3(d)))
	melee.clashed.connect(func(d): body_view.play("clash", float(Global.ANIM["clash_time"]), {"direction": body_view.global_transform.basis.inverse() * Vector3(d)}))
	body_view.ik_feet = false   # thân người chơi chỉ để đổ bóng
	melee.swing_started.connect(viewmodel.play_swing)
	melee.swing_started.connect(func(_w, _a, _r): _cam_fx_v.z -= float(Global.ta("cam_lunge")) * _cam_fx_amount())
	footstep.connect(viewmodel.footstep)
	ledge_climbed.connect(viewmodel.ledge)
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
	parry.parried.connect(func(_h): body_view.play("parry_hit", float(Global.ANIM["parry_hit_time"])))
	parry.parry_missed.connect(viewmodel.parry_fail)
	# Instability "mất thế": thua clash / parry hụt / bị parry thì tăng; parry thành công và đánh trúng thì giảm.
	melee.clashed.connect(func(_d): instability.clash_penalty())
	melee.got_parried.connect(func(): instability.add(Global.INSTABILITY["parried_loss"]))
	parry.parry_missed.connect(func(): instability.add(Global.INSTABILITY["parry_miss_loss"]))
	parry.parried.connect(func(_h): instability.lose(Global.INSTABILITY["parry_relief"]))
	melee.hit_landed.connect(func(_hb, landed): if landed: instability.lose(Global.INSTABILITY["hit_relief"]))
	instability.destabilized_changed.connect(_on_destabilized)
	combat.shot_fired.connect(_on_shot_recoil)
	combat.self_impulse.connect(func(v: Vector3): velocity += v)   # lỗi giật bật người của súng
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
	if state == State.SLIDE and not Global.reduced_fx:
		# Lướt: camera nghiêng nhẹ về phía bước ngang (hoặc bên phải nếu đi thẳng), tỉ lệ theo hệ số hiệu ứng camera.
		var side: float = -signf(move_input.x) if absf(move_input.x) > 0.1 else -1.0
		roll += side * deg_to_rad(float(Global.ta("slide_tilt_deg"))) * _cam_fx_amount()
	if state == State.GRAPPLE and not Global.reduced_fx:
		# Đang kéo: camera nghiêng nhẹ về phía điểm móc.
		var to_a: Vector3 = _grapple_point - head.global_position
		roll += -signf(to_a.dot(head.global_transform.basis.x)) * deg_to_rad(float(Global.PLAYER["grapple_tilt_deg"])) * clampf(absf(to_a.normalized().dot(head.global_transform.basis.x)) * 3.0, 0.0, 1.0)
	var rr: Vector2 = Motion.damp(head.rotation.z, roll, _roll_v, float(Global.MOTION["cam_roll_time"]), delta)
	head.rotation.z = rr.x
	_roll_v = rr.y
	_step_cam_fx(delta)
	_shake = maxf(_shake - delta * 0.5, 0.0)
	_step_parry_react(delta)
	var target_fov: float = float(Global.settings["fov"]) + clampf((horizontal_speed() - 10.0) * 0.5, 0.0, float(Global.PLAYER["fov_speed_max"])) + _pk_fov
	var zoom: float = combat.zoom_fov()
	if zoom > 0.0:
		target_fov = zoom
	var fr: Vector2 = Motion.damp(camera.fov, target_fov, _fov_v, 0.07 if zoom > 0.0 else float(Global.MOTION["cam_fov_time"]), delta)
	camera.fov = fr.x
	_fov_v = fr.y
	_update_bob(delta)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake
	camera.v_offset = randf_range(-1.0, 1.0) * _shake
	if not is_on_floor():
		_fall_peak = maxf(_fall_peak, -velocity.y)
	viewmodel.update(delta, horizontal_speed(), is_on_floor(), _anim_state_name(), move_input.x, _fall_peak)
	if is_on_floor():
		_fall_peak = 0.0
	var hy: float = HEAD_SLIDE if _is_crouched() else HEAD_STAND
	var hr: Vector2 = Motion.damp(head.position.y, hy, _head_v, float(Global.MOTION["cam_head_time"]), delta)
	head.position.y = hr.x
	_head_v = hr.y


## Hệ số hiệu ứng camera (lao khi chém, đập khi tiếp đất, nghiêng khi lướt): 0 = tắt, 1 = mặc định. Tắt hẳn khi giảm hiệu ứng.
func _cam_fx_amount() -> float:
	return 0.0 if Global.reduced_fx else clampf(float(Global.settings.get("cam_fx", 1.0)), 0.0, 1.5)


## Lò xo cho lệch camera do hiệu ứng + cú đập khi tiếp đất theo độ cao rơi. Chỉ hình ảnh, chạy ở _process.
func _step_cam_fx(delta: float) -> void:
	var floor_now: bool = is_on_floor()
	if not floor_now:
		_fall_vy = minf(_fall_vy, velocity.y)
	elif not _was_floor_vis:
		var drop: float = clampf(-_fall_vy - float(Global.ANIM["cam_dip_min_fall"]), 0.0, 30.0)
		_cam_fx_v.y -= minf(drop * float(Global.ta("cam_dip_per_speed")), float(Global.ta("cam_dip_max"))) * _cam_fx_amount()
		_fall_vy = 0.0
	_was_floor_vis = floor_now
	var k: float = float(Global.ta("cam_fx_k"))
	var c: float = float(Global.ta("cam_fx_c"))
	var n: int = maxi(1, ceili(delta / (1.0 / 120.0)))
	var h: float = delta / float(n)
	for i in n:
		_cam_fx_v += (-_cam_fx * k - _cam_fx_v * c) * h
		_cam_fx += _cam_fx_v * h


## Lắc đầu khi chạy trên sàn (chỉ hình ảnh); tắt khi giảm hiệu ứng hoặc đặt bob = 0.
## Nhịp lắc bám theo quãng đường bước chân (`_step_dist` / step_stride): điểm thấp nhất của camera trùng tiếng bước chân.
func _update_bob(delta: float) -> void:
	var amp: float = float(Global.PLAYER["bob_amplitude"]) * float(Global.settings["bob"])
	var moving: bool = state == State.NORMAL and is_on_floor() and horizontal_speed() > 1.0
	var fx: Vector3 = _cam_fx * (0.0 if Global.reduced_fx else 1.0)
	if Global.reduced_fx or amp <= 0.0 or not moving:
		camera.position = camera.position.lerp(_cam_base + fx, minf(1.0, 12.0 * delta))
		return
	_bob_phase = clampf(_step_dist / float(Global.PLAYER["step_stride"]), 0.0, 1.0) * TAU
	var k: float = clampf(horizontal_speed() / 9.0, 0.0, 1.5)
	var target := _cam_base + fx + Vector3(sin(_bob_phase * 0.5) * _step_sign * amp * 0.6, absf(sin(_bob_phase * 0.5)) * amp * k, 0.0)
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


## Parry thành công (M28): camera giật theo hướng đòn bị đỡ + FOV nảy. `incoming` = hướng đòn bay tới người chơi (thế giới).
## Chỉ hình ảnh; nhân với hệ số "cam_fx", tắt khi giảm hiệu ứng.
func parry_react(incoming: Vector3) -> void:
	var amt: float = _cam_fx_amount()
	if amt <= 0.0:
		return
	var local: Vector3 = head.global_transform.basis.inverse() * incoming
	var kick: float = float(Global.ta("pf_cam_kick")) * amt
	_pk_rot.x += kick
	_pk_rot.y += -signf(local.x) * kick * 0.6 if absf(local.x) > 0.05 else 0.0
	_pk_fov += float(Global.ta("pf_fov_punch")) * amt


func _step_parry_react(delta: float) -> void:
	var rx: Vector2 = Motion.damp(_pk_rot.x, 0.0, _pk_rot_v.x, 0.12, delta)
	var ry: Vector2 = Motion.damp(_pk_rot.y, 0.0, _pk_rot_v.y, 0.12, delta)
	_pk_rot = Vector2(rx.x, ry.x)
	_pk_rot_v = Vector2(rx.y, ry.y)
	var rf: Vector2 = Motion.damp(_pk_fov, 0.0, _pk_fov_v, 0.15, delta)
	_pk_fov = rf.x
	_pk_fov_v = rf.y
	camera.rotation = Vector3(deg_to_rad(_pk_rot.x), 0.0, deg_to_rad(_pk_rot.y))


## Rung camera (gọi từ main khi có va chạm/đòn trúng).
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount * (float(Global.FX["reduced_shake"]) if Global.reduced_fx else 1.0))


## Dịch chuyển sang tầng mới (Vô Tận): giữ máu, đạn, đồ; chỉ đổi chỗ, dừng mọi đà và trạng thái chuyển động.
func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_set_state(State.NORMAL)


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
	_step_redirect(delta)
	_tick_feel(delta)
	if state == State.LEDGE and (want_dash or want_grapple or want_slam):
		cancel_ledge()
	_try_dash()
	_try_start_grapple()
	_update_grapple_target(delta)
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

	_apply_speed_cap(delta)
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
	_grapple_chain = maxf(_grapple_chain - delta * float(Global.PLAYER["grapple_chain_recover"]), 0.0)
	_slide_boost_cd = maxf(_slide_boost_cd - delta, 0.0)
	_slam_cd = maxf(_slam_cd - delta, 0.0)
	var cfg: Dictionary = Global.PLAYER
	_regen_delay_t = maxf(_regen_delay_t - delta, 0.0)
	if dash_stamina < float(cfg["dash_stamina_max"]) and _regen_delay_t <= 0.0 and not instability.destabilized:
		dash_stamina = minf(dash_stamina + float(cfg["dash_regen"]) * stamina_regen_mult * delta, float(cfg["dash_stamina_max"]))
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
			_accelerate(wish_dir, float(cfg["walk_speed"]) * speed_mult * combat.move_mult, cfg["air_accel"], delta)
		else:
			_apply_friction(delta)
			_accelerate(wish_dir, float(cfg["walk_speed"]) * speed_mult * combat.move_mult, cfg["ground_accel"], delta)
	else:
		velocity.y -= float(cfg["gravity"]) * delta
		_accelerate(wish_dir, float(cfg["walk_speed"]) * speed_mult * combat.move_mult, cfg["air_accel"], delta)
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
		_step_sign = -_step_sign
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
		_accelerate(wish_dir, float(cfg["walk_speed"]) * speed_mult * combat.move_mult, cfg["air_accel"], delta)
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

## Tìm điểm móc: tia chính giữa tâm ngắm; trượt thì thử các tia trong nón `grapple_assist_deg` (chọn lệch tâm ít nhất).
## Trả về {} nếu không có.
func _find_grapple_point() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var from: Vector3 = head.global_position
	var fwd: Vector3 = -head.global_transform.basis.z
	var rng: float = float(Global.PLAYER["grapple_range"])
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * rng, Global.L_WORLD | Global.L_TITAN)
	q.exclude = [get_rid()]
	q.collide_with_areas = true
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		return hit
	var cone: float = deg_to_rad(float(Global.PLAYER["grapple_assist_deg"]))
	if cone <= 0.0:
		return {}
	var right: Vector3 = head.global_transform.basis.x
	var up: Vector3 = head.global_transform.basis.y
	for ring in [0.5, 1.0]:   # vòng trong rồi vòng ngoài: ưu tiên lệch ít
		var best: Dictionary = {}
		var best_d: float = INF
		for k in 8:
			var a: float = TAU * float(k) / 8.0
			var dir: Vector3 = (fwd + (right * cos(a) + up * sin(a)) * tan(cone * ring)).normalized()
			q = PhysicsRayQueryParameters3D.create(from, from + dir * rng, Global.L_WORLD | Global.L_TITAN)
			q.exclude = [get_rid()]
			q.collide_with_areas = true
			var h: Dictionary = space.intersect_ray(q)
			if not h.is_empty() and (h["normal"] as Vector3).y < 0.7:   # bỏ qua mặt sàn: móc xuống đất vô ích
				var d: float = (h["position"] as Vector3).distance_to(from)
				if d < best_d:
					best_d = d
					best = h
		if not best.is_empty():
			return best
	return {}


func _update_grapple_target(delta: float) -> void:
	_target_timer -= delta
	if _target_timer > 0.0:
		return
	_target_timer = 0.1
	var ok: bool = state != State.GRAPPLE and not dead and not _find_grapple_point().is_empty()
	if ok != _target_valid:
		_target_valid = ok
		grapple_target_changed.emit(ok)


func _try_start_grapple() -> void:
	var pressed: bool = want_grapple and not _prev_grapple
	_prev_grapple = want_grapple
	if not pressed or _grapple_cd > 0.0 or state == State.GRAPPLE:
		return
	var hit: Dictionary = _find_grapple_point()
	if hit.is_empty():
		return
	if state == State.SLIDE:
		_exit_slide()
	_grapple_point = hit["position"]
	_grapple_node = null
	var col: Object = hit.get("collider")
	if col is Area3D and (col as Area3D).collision_layer & Global.L_TITAN != 0:
		_grapple_node = (col as Area3D).get_parent() as Node3D   # móc lên Titan: điểm móc đi theo thân
		_grapple_local = _grapple_node.to_local(_grapple_point)
	_grapple_time = 0.0
	_grapple_len = head.global_position.distance_to(_grapple_point)
	_grapple_taut = false
	_set_state(State.GRAPPLE)
	grapple_started.emit(_grapple_point)


func _end_grapple() -> void:
	var cfg: Dictionary = Global.PLAYER
	_grapple_chain += 1.0
	var extra: float = clampf((_grapple_chain - float(cfg["grapple_chain_free"])) * float(cfg["grapple_chain_cd"]), 0.0, float(cfg["grapple_chain_cd_max"]))
	_grapple_cd = float(cfg["grapple_cooldown"]) + extra
	_set_state(State.NORMAL)
	grapple_ended.emit()


func _move_grapple(delta: float) -> void:
	var cfg: Dictionary = Global.PLAYER
	_grapple_time += delta
	if _grapple_node != null:
		if is_instance_valid(_grapple_node) and not bool(_grapple_node.get("dead")):
			_grapple_point = _grapple_node.to_global(_grapple_local)
			rope.set_target(_grapple_point)
		else:
			_grapple_node = null
			_end_grapple() # Titan chết / biến mất: thả móc
			return
	var to: Vector3 = _grapple_point - head.global_position
	var dist: float = to.length()
	if not want_grapple:
		_release_redirect() # tự nhả: xoay vận tốc theo hướng nhìn thay vì giữ nguyên hướng kéo
		_end_grapple()
		return
	if _grapple_time > float(cfg["grapple_max_time"]) or dist < 0.05:
		_end_grapple() # thả ra: giữ nguyên quán tính hiện tại
		return
	var dir: Vector3 = to / dist
	# Lực kéo tăng dần theo đường cong mượt (smoothstep) rồi dừng kéo khi tới gần điểm móc (vẫn bám).
	var t: float = clampf(_grapple_time / float(cfg["grapple_ramp"]), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var pull: float = lerpf(float(cfg["grapple_pull_start"]), float(cfg["grapple_pull_max"]), t)
	var reeling: bool = dist >= float(cfg["grapple_stop_dist"])
	if reeling and velocity.dot(dir) < float(cfg["grapple_max_speed"]):
		velocity += dir * pull * delta
	# Dây căng: dây chỉ ngắn lại; vượt độ dài dây thì bỏ phần vận tốc hướng ra xa (đu như con lắc).
	_grapple_len = minf(_grapple_len, dist)
	_grapple_taut = false
	if float(cfg["grapple_swing"]) > 0.5 and dist >= _grapple_len - 0.05:
		var out: float = -velocity.dot(dir)
		if out > 0.0:
			velocity += dir * out
			_grapple_taut = true
	rope.set_tension(pull / float(cfg["grapple_pull_max"]) if reeling else 0.3)
	velocity.y -= float(cfg["gravity"]) * 0.4 * delta
	_accelerate(_wish_dir(), float(cfg["walk_speed"]) * speed_mult * combat.move_mult, cfg["air_accel"], delta)


## M33: tốc độ ngang vượt trần mềm bị hãm dần (hàm mũ), không chặn cứng. Chạy trong _physics_process, trước move_and_slide.
func _apply_speed_cap(delta: float) -> void:
	var cap: float = float(Global.PLAYER["grapple_soft_cap"])
	var h: float = horizontal_speed()
	if h <= cap:
		return
	var k: float = (cap + (h - cap) * exp(-float(Global.PLAYER["grapple_cap_drag"]) * delta)) / h
	velocity.x *= k
	velocity.z *= k
	if _redirect_left > 0.0:
		_redirect_target.x *= k
		_redirect_target.z *= k


## Nhả móc chủ động: xoay vận tốc về hướng nhìn (giữ độ lớn) + cộng một chút dọc hướng nhìn.
func _release_redirect() -> void:
	var cfg: Dictionary = Global.PLAYER
	var speed: float = velocity.length()
	if speed < 8.0:
		return
	var look: Vector3 = -head.global_transform.basis.z
	# M33: boost/snap giảm dần theo tốc độ hiện có, về 0 tại trần mềm (chống cộng dồn khi spam móc)
	var room: float = clampf(1.0 - horizontal_speed() / float(cfg["grapple_soft_cap"]), 0.0, 1.0)
	if _grapple_taut: # nhả lúc dây căng: bắn ra thêm theo hướng nhìn
		speed += float(cfg["grapple_release_snap"]) * room
	var blended: Vector3 = velocity.lerp(look * speed, float(cfg["grapple_redirect_blend"]))
	var target_v: Vector3 = blended.normalized() * speed + look * float(cfg["grapple_release_boost"]) * room
	var t_red: float = float(cfg["grapple_redirect_time"])
	if t_red <= 0.001:
		velocity = target_v
		return
	# Xoay dần vận tốc sang hướng mới thay vì đổi trong một khung hình (liền mạch với cú kéo trước đó).
	_redirect_target = target_v
	_redirect_left = t_red
	_redirect_rate = velocity.distance_to(target_v) / t_red


## Nhả móc: đưa vận tốc về vận tốc đích đều đặn trong `grapple_redirect_time`; dừng khi vào trạng thái khác.
func _step_redirect(delta: float) -> void:
	if _redirect_left <= 0.0:
		return
	if state != State.NORMAL or dead:
		_redirect_left = 0.0
		return
	_redirect_left -= delta
	velocity = velocity.move_toward(_redirect_target, _redirect_rate * delta)


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
