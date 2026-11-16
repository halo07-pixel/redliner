extends Node
## Instability "mất thế". Thanh tăng khi mất thế trong giao đấu; đầy thì Destabilized: kẻ bị mất thế không
## tấn công/parry được và stamina dash về 0 trong vài giây, rồi thanh về 0 và có khoảng miễn nhiễm ngắn.
## Dùng chung cho người chơi và bot. Chỉ phát Signal; chủ nhân nối hiệu ứng (call down, signal up).

signal changed(value: float, maximum: float)
signal destabilized_changed(active: bool)

var value: float = 0.0
var destabilized: bool = false

var _t: float = 0.0          # còn lại của trạng thái Destabilized
var _immune_t: float = 0.0
var _since_gain: float = 0.0


func maximum() -> float:
	return Global.INSTABILITY["max"]


func ratio() -> float:
	return value / maximum()


func time_left() -> float:
	return _t if destabilized else 0.0


func is_immune() -> bool:
	return _immune_t > 0.0


func add(amount: float) -> void:
	if destabilized or _immune_t > 0.0 or amount <= 0.0:
		return
	value = minf(value + amount, maximum())
	_since_gain = 0.0
	changed.emit(value, maximum())
	if value >= maximum():
		_start_destabilized()


## Bớt mất thế (parry thành công, đòn kiếm trúng). Không tác dụng khi đang Destabilized.
func lose(amount: float) -> void:
	if destabilized:
		return
	value = maxf(value - amount, 0.0)
	changed.emit(value, maximum())


## Thua clash: càng mất thế (thanh cao) càng chịu nhiều.
func clash_penalty() -> void:
	add(float(Global.INSTABILITY["clash_loss"]) * (0.6 + 0.8 * ratio()))


func reset() -> void:
	value = 0.0
	_t = 0.0
	_immune_t = 0.0
	_since_gain = 0.0
	if destabilized:
		destabilized = false
		destabilized_changed.emit(false)
	changed.emit(value, maximum())


## Gọi mỗi bước vật lý.
func tick(delta: float) -> void:
	if destabilized:
		_t -= delta
		value = maximum() * maxf(_t, 0.0) / float(Global.INSTABILITY["destabilized_time"])
		if _t <= 0.0:
			destabilized = false
			value = 0.0
			_immune_t = Global.INSTABILITY["immunity_time"]
			destabilized_changed.emit(false)
		changed.emit(value, maximum())
		return
	_immune_t = maxf(_immune_t - delta, 0.0)
	_since_gain += delta
	if value > 0.0 and _since_gain >= float(Global.INSTABILITY["decay_delay"]):
		value = maxf(value - float(Global.INSTABILITY["decay"]) * delta, 0.0)
		changed.emit(value, maximum())


func _start_destabilized() -> void:
	destabilized = true
	_t = Global.INSTABILITY["destabilized_time"]
	destabilized_changed.emit(true)
