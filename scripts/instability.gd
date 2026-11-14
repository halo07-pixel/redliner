extends Node
## Instability / Redline. Thanh đầy dần khi chạy nhanh, đánh trúng, parry thành công; đầy thì vào
## Redline (sát thương tăng, dash hồi nhanh) rồi cạn dần về 0. Chỉ phát Signal; Player nối hiệu ứng.

signal changed(value: float, maximum: float)
signal redline_changed(active: bool)

var value: float = 0.0
var redline: bool = false

var _t: float = 0.0


func maximum() -> float:
	return Global.INSTABILITY["max"]


func add(amount: float) -> void:
	if redline:
		return # đang Redline thì không tích thêm
	value = minf(value + amount, maximum())
	changed.emit(value, maximum())
	if value >= maximum():
		_start_redline()


func lose(amount: float) -> void:
	if redline:
		return
	value = maxf(value - amount, 0.0)
	changed.emit(value, maximum())


func reset() -> void:
	value = 0.0
	if redline:
		redline = false
		redline_changed.emit(false)
	changed.emit(value, maximum())


## Gọi mỗi bước vật lý từ Player kèm tốc độ ngang hiện tại.
func tick(delta: float, speed: float) -> void:
	if redline:
		_t -= delta
		value = maximum() * maxf(_t, 0.0) / float(Global.INSTABILITY["redline_time"])
		changed.emit(value, maximum())
		if _t <= 0.0:
			redline = false
			value = 0.0
			redline_changed.emit(false)
			changed.emit(value, maximum())
	elif speed > float(Global.INSTABILITY["speed_threshold"]):
		add(float(Global.INSTABILITY["speed_gain"]) * delta)
	elif value > 0.0:
		value = maxf(value - float(Global.INSTABILITY["idle_decay"]) * delta, 0.0)
		changed.emit(value, maximum())


func _start_redline() -> void:
	redline = true
	_t = Global.INSTABILITY["redline_time"]
	redline_changed.emit(true)
