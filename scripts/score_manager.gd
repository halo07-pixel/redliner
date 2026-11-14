extends Node
## Tính điểm: điểm cơ bản theo loại bot, thưởng combo (hạ liên tiếp trong cửa sổ thời gian),
## thưởng phản đạn (x2) và thưởng hạ bot đang bị choáng do parry/clash (x1.5).

signal score_changed(score: int, combo: int, best: int)
signal bonus(text: String)

const COMBO_WINDOW: float = 4.0
const MAX_MULT: float = 2.0

var score: int = 0
var combo: int = 0
var best: int = 0

var _combo_t: float = 0.0


func register_kill(base: int, info: Dictionary) -> int:
	combo = combo + 1 if _combo_t > 0.0 else 1
	_combo_t = COMBO_WINDOW
	var mult: float = minf(1.0 + 0.1 * float(combo - 1), MAX_MULT)
	var text: String = ""
	if info.get("reflected", false):
		mult *= 2.0
		text = "PHẢN ĐẠN x2"
	elif info.get("staggered", false):
		mult *= 1.5
		text = "PARRY x1.5"
	var gained: int = roundi(float(base) * mult)
	score += gained
	best = maxi(best, score)
	score_changed.emit(score, combo, best)
	if text != "":
		bonus.emit(text)
	return gained


func reset() -> void:
	score = 0
	combo = 0
	_combo_t = 0.0
	score_changed.emit(score, combo, best)


func _physics_process(delta: float) -> void:
	if _combo_t > 0.0:
		_combo_t -= delta
		if _combo_t <= 0.0:
			combo = 0
			score_changed.emit(score, combo, best)
