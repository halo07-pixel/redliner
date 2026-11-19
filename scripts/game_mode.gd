extends Node
## Luật chế độ chơi: Sinh tồn / Thử thách thời gian / Tập luyện. Không biết gì về HUD hay người chơi:
## chỉ nhận `on_kill()` / `start()` / `stop()` và phát Signal (main.gd nối vào HUD).

signal objective_changed(text: String)
signal time_changed(left: float)            # chế độ thời gian: phát mỗi khi đổi 0.1 s
signal finished(won: bool, info: Dictionary) # chỉ chế độ thời gian tự kết thúc (thắng / hết giờ)

var mode: String = "survival"
var time_left: float = 0.0
var kills: int = 0
var target: int = 0
var active: bool = false
var done: bool = false

var _last_tick: int = -1


func setup(p_mode: String) -> void:
	mode = p_mode if p_mode in Global.MODES else "survival"
	kills = 0
	done = false
	active = false
	target = int(Global.TIMED["target_kills"]) if mode == "timed" else 0
	time_left = float(Global.TIMED["start_time"]) if mode == "timed" else 0.0
	_last_tick = -1


func start() -> void:
	active = true
	objective_changed.emit(objective_text())
	if mode == "timed":
		time_changed.emit(time_left)


func stop() -> void:
	active = false


func objective_text() -> String:
	match mode:
		"timed":
			return "Hạ %d bot:  %d / %d" % [target, kills, target]
		"training":
			return "TẬP LUYỆN - không tính điểm"
	return "Sống sót qua các wave"


## Gọi mỗi khi người chơi hạ một bot. Trả về số giây được cộng (chế độ thời gian).
func on_kill() -> float:
	if not active or done:
		return 0.0
	kills += 1
	var gained: float = 0.0
	if mode == "timed":
		var before: float = time_left
		time_left = minf(time_left + float(Global.TIMED["kill_bonus"]), float(Global.TIMED["max_time"]))
		gained = time_left - before
		time_changed.emit(time_left)
		objective_changed.emit(objective_text())
		if kills >= target:
			_finish(true)
	else:
		objective_changed.emit(objective_text())
	return gained


## Điểm cuối ván từ điểm cơ bản (điểm bot hạ + combo): chế độ thời gian cộng thưởng thời gian còn lại khi thắng.
func result_score(base_score: int, won: bool = false) -> int:
	match mode:
		"training":
			return 0
		"timed":
			if won:
				return base_score + roundi(time_left) * int(Global.TIMED["win_bonus_per_sec"])
	return base_score


func _physics_process(delta: float) -> void:
	if not active or done or mode != "timed":
		return
	time_left = maxf(time_left - delta, 0.0)
	var tick: int = int(time_left * 10.0)
	if tick != _last_tick:
		_last_tick = tick
		time_changed.emit(time_left)
	if time_left <= 0.0:
		_finish(false)


func _finish(won: bool) -> void:
	done = true
	active = false
	finished.emit(won, {"mode": mode, "time_left": time_left, "kills": kills, "target": target})
