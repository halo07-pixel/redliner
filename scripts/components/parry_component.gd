extends Node
## ParryComponent: cửa sổ parry ngắn. Trong cửa sổ, đạn bị phản ngược (đổi chủ, đổi hướng,
## tăng sát thương), đòn kiếm làm kẻ tấn công choáng. Parry hụt thì bị phạt thời gian hồi.

signal parry_started
signal parried(hit: Dictionary)
signal parry_missed
signal cooldown_progress(ratio: float) # 0 = vừa phạt, 1 = sẵn sàng

var body: Node3D
var active_t: float = 0.0
var cooldown_t: float = 0.0

var _cd_total: float = 1.0
var _was_cooling: bool = false


func setup(p_body: Node3D) -> void:
	body = p_body


func is_active() -> bool:
	return active_t > 0.0


func can_press() -> bool:
	return active_t <= 0.0 and cooldown_t <= 0.0


func press() -> bool:
	if not can_press():
		return false
	active_t = Global.COMBAT["parry_window"]
	parry_started.emit()
	return true


## Được HurtboxComponent gọi. Trả về true nếu đòn bị parry.
func try_parry(hit: Dictionary) -> bool:
	if active_t <= 0.0:
		return false
	active_t = 0.0
	cooldown_t = Global.COMBAT["parry_hit_cooldown"]
	_cd_total = cooldown_t
	match hit["kind"]:
		"bullet":
			hit["bullet"].reflect(body, Global.COMBAT["reflect_damage_mult"], Global.COMBAT["reflect_speed_mult"])
		"melee":
			hit["on_parried"].call()
		_:
			pass # hitscan: chỉ bị chặn
	parried.emit(hit)
	return true


func _physics_process(delta: float) -> void:
	cooldown_t = maxf(cooldown_t - delta, 0.0)
	if cooldown_t > 0.0 or _was_cooling:
		_was_cooling = cooldown_t > 0.0
		cooldown_progress.emit(1.0 - cooldown_t / _cd_total)
	if active_t > 0.0:
		active_t -= delta
		if active_t <= 0.0:
			active_t = 0.0
			cooldown_t = Global.COMBAT["parry_miss_cooldown"] # phạt khi parry hụt
			_cd_total = cooldown_t
			parry_missed.emit()
