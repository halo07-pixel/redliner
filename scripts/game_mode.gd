extends Node
## Luật chế độ chơi: Sinh tồn / Thử thách thời gian / Tập luyện. Không biết gì về HUD hay người chơi:
## chỉ nhận `on_kill()` / `start()` / `stop()` và phát Signal (main.gd nối vào HUD).

signal objective_changed(text: String)
signal time_changed(left: float)            # chế độ thời gian: phát mỗi khi đổi 0.1 s
signal finished(won: bool, info: Dictionary) # chỉ chế độ thời gian tự kết thúc (thắng / hết giờ)
signal floor_changed(floor_n: int, quota: int)   # Vô Tận: sang tầng mới
signal portal_opened(floor_n: int)               # Vô Tận: đủ chỉ tiêu, cổng mở

var mode: String = "survival"
var time_left: float = 0.0
var kills: int = 0
var target: int = 0
var active: bool = false
var done: bool = false
## Vô Tận: tầng, số bot đã hạ ở tầng này, chỉ tiêu, cổng đã mở, Titan (nếu có) đã hạ chưa.
var floor_n: int = 1
var floor_kills: int = 0
var quota: int = 0
var portal_open: bool = false
var boss_pending: bool = false

var _last_tick: int = -1


func setup(p_mode: String) -> void:
	mode = p_mode if p_mode in Global.MODES else "survival"
	kills = 0
	done = false
	active = false
	target = int(Global.TIMED["target_kills"]) if mode == "timed" else 0
	time_left = float(Global.TIMED["start_time"]) if mode == "timed" else 0.0
	_last_tick = -1
	if mode == "endless":
		floor_n = 1
		_begin_floor()


## Chỉ tiêu hạ bot của tầng n.
static func quota_for(n: int) -> int:
	return int(Global.ENDLESS["quota_base"]) + int(Global.ENDLESS["quota_per_floor"]) * (maxi(n, 1) - 1)


## Tầng n có Titan không (cứ `titan_every` tầng).
static func has_boss(n: int) -> bool:
	return n >= int(Global.ENDLESS["titan_every"]) and n % int(Global.ENDLESS["titan_every"]) == 0


func _begin_floor() -> void:
	floor_kills = 0
	quota = quota_for(floor_n)
	portal_open = false
	boss_pending = has_boss(floor_n)


## Sang tầng kế (main gọi khi người chơi vào cổng đã mở).
func next_floor() -> void:
	if mode != "endless" or not portal_open:
		return
	floor_n += 1
	_begin_floor()
	floor_changed.emit(floor_n, quota)
	objective_changed.emit(objective_text())


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
		"endless":
			if portal_open:
				return "TẦNG %d: CỔNG ĐÃ MỞ - chạy tới cột sáng xanh" % floor_n
			if floor_kills >= quota and boss_pending:
				return "TẦNG %d: hạ Titan để mở cổng" % floor_n
			return "TẦNG %d: hạ %d / %d bot%s" % [floor_n, floor_kills, quota, " + Titan" if boss_pending else ""]
	return "Sống sót qua các wave"


## Gọi mỗi khi người chơi hạ một bot. Trả về số giây được cộng (chế độ thời gian).
func on_kill(type_name: String = "") -> float:
	if not active or done:
		return 0.0
	kills += 1
	if mode == "endless":
		if type_name == "titan":
			boss_pending = false
		else:
			floor_kills += 1
		if not portal_open and floor_kills >= quota and not boss_pending:
			portal_open = true
			portal_opened.emit(floor_n)
		objective_changed.emit(objective_text())
		return 0.0
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
