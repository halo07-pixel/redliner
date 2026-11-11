extends CharacterBody3D
## Người chơi FPS. Vật lý di chuyển (kiểu Quake: gia tốc theo wish direction + ma sát mặt đất,
## KHÔNG có trần tốc độ) nằm hoàn toàn trong _physics_process. Đọc input tách riêng thành
## 2 field (move_input, want_jump) để test headless có thể tự điền (use_input = false).
## HUD/âm thanh KHÔNG được gọi trực tiếp từ đây — chỉ nghe Signal "speed_changed".

signal speed_changed(speed: float)

var move_input: Vector2 = Vector2.ZERO # Input.get_vector: x phải(+)/trái(-), y lùi(+)/tiến(-)
var want_jump: bool = false
var use_input: bool = true

var _pitch: float = 0.0
var _last_speed: float = -1.0

@onready var head: Node3D = $Head


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = Global.PLAYER["mouse_sens"]
		rotate_y(-event.relative.x * sens)
		_pitch = clampf(_pitch - event.relative.y * sens, -PI * 0.49, PI * 0.49)
		head.rotation.x = _pitch


func _read_input() -> void:
	move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	want_jump = Input.is_action_pressed("jump")


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _physics_process(delta: float) -> void:
	if use_input:
		_read_input()

	var cfg: Dictionary = Global.PLAYER
	var wish_dir: Vector3 = (global_transform.basis * Vector3(move_input.x, 0.0, move_input.y)).normalized()

	if is_on_floor():
		if want_jump:
			# Frame nhảy KHÔNG bị ma sát -> giữ được động lượng khi nhảy liên tục (bunny hop).
			velocity.y = cfg["jump_velocity"]
			_accelerate(wish_dir, cfg["walk_speed"], cfg["air_accel"], delta)
		else:
			_apply_friction(delta)
			_accelerate(wish_dir, cfg["walk_speed"], cfg["ground_accel"], delta)
	else:
		velocity.y -= float(cfg["gravity"]) * delta
		_accelerate(wish_dir, cfg["walk_speed"], cfg["air_accel"], delta)

	move_and_slide()

	var speed: float = horizontal_speed()
	if absf(speed - _last_speed) > 0.05:
		_last_speed = speed
		speed_changed.emit(speed)


## Cộng tốc độ theo wish_dir, nhưng chỉ tới khi thành phần vận tốc dọc wish_dir đạt wish_speed.
## Nhờ vậy vận tốc đã vượt wish_speed không bị cắt, và đi vuông góc với vận tốc hiện tại
## (air-strafe) vẫn cộng thêm được tốc độ.
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
