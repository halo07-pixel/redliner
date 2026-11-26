extends Node
## Luật chế độ chơi: Vô Tận / Tập luyện. Không biết gì về HUD hay người chơi:
## chỉ nhận `on_kill()` / `start()` / `stop()` và phát Signal (main.gd nối vào HUD).

signal objective_changed(text: String)
signal floor_changed(floor_n: int, quota: int)   # Vô Tận: sang tầng mới
signal portal_opened(floor_n: int)               # Vô Tận: đủ chỉ tiêu, cổng mở

var mode: String = "endless"
var kills: int = 0
var active: bool = false
## Vô Tận: tầng, số bot đã hạ ở tầng này, chỉ tiêu, cổng đã mở, Titan (nếu có) đã hạ chưa.
var floor_n: int = 1
var floor_kills: int = 0
var quota: int = 0
var portal_open: bool = false
var boss_pending: bool = false


func setup(p_mode: String) -> void:
	mode = p_mode if p_mode in Global.MODES else "endless"
	kills = 0
	active = false
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


func stop() -> void:
	active = false


func objective_text() -> String:
	match mode:
		"training":
			return "TẬP LUYỆN - không tính điểm"
		"endless":
			if portal_open:
				return "TẦNG %d: CỔNG ĐÃ MỞ - chạy tới cột sáng xanh" % floor_n
			if floor_kills >= quota and boss_pending:
				return "TẦNG %d: hạ Titan để mở cổng" % floor_n
			return "TẦNG %d: hạ %d / %d bot%s" % [floor_n, floor_kills, quota, " + Titan" if boss_pending else ""]
	return ""


## Gọi mỗi khi người chơi hạ một bot (Vô Tận: tính chỉ tiêu tầng, mở cổng khi đủ). Tập luyện chỉ đếm.
func on_kill(type_name: String = "") -> void:
	if not active:
		return
	kills += 1
	if mode != "endless":
		return
	if type_name == "titan":
		boss_pending = false
	else:
		floor_kills += 1
	if not portal_open and floor_kills >= quota and not boss_pending:
		portal_open = true
		portal_opened.emit(floor_n)
	objective_changed.emit(objective_text())


## Điểm cuối ván: tập luyện không tính điểm.
func result_score(base_score: int) -> int:
	return 0 if mode == "training" else base_score
