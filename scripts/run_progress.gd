extends Node
## Tiến trình trong một lượt Vô Tận: XP, cấp, các nâng cấp đã lấy. Chỉ logic + Signal; không biết UI hay người chơi
## (main nghe Signal rồi áp thống kê). XP/cấp/nâng cấp mất khi lượt kết thúc (vàng meta-currency mới được giữ, M37).

signal xp_changed(level: int, xp: int, need: int)
signal leveled_up(level: int)               # mỗi cấp một lần (nhiều cấp liền nhau phát lần lượt)
signal upgrade_chosen(id: String, tier: int)

const UpgradesScript = preload("res://scripts/upgrades.gd")

var level: int = 0
var xp: int = 0
var taken: Dictionary = {}
var pools: Array = ["shared", "gun:pistol"]   # + kho của súng đang cầm (set_weapon_pool); M39 thêm "sword"
var pending: int = 0            # số lần lên cấp đang chờ chọn
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


## XP cần để từ cấp `lv` lên cấp kế.
static func need_for(lv: int) -> int:
	return int(Global.XP["need_base"]) + int(Global.XP["need_per_level"]) * lv


## XP một bot loại `type_name` rơi (chưa nhân hệ số học nhanh).
static func orb_value(type_name: String) -> int:
	var orb: Dictionary = Global.XP["orb"]
	return int(orb.get(type_name, orb["default"]))


func stat(stat_name: String) -> float:
	return UpgradesScript.stat(taken, stat_name)


## Cộng XP (đã nhân hệ số xp_gain, làm tròn). Mỗi lần đủ XP lên một cấp và phát leveled_up.
func add_xp(amount: int) -> void:
	xp += maxi(roundi(amount * stat("xp_gain")), 0)
	while xp >= need_for(level):
		xp -= need_for(level)
		level += 1
		pending += 1
		leveled_up.emit(level)
	xp_changed.emit(level, xp, need_for(level))


## Đổi kho thẻ riêng theo súng đang cầm (không có kho thì chỉ còn kho dùng chung và kho kiếm nếu có).
func set_weapon_pool(weapon_id: String) -> void:
	pools = pools.filter(func(p): return not String(p).begins_with("gun:"))
	if Global.UPGRADES.has("gun:" + weapon_id):
		pools.append("gun:" + weapon_id)


## Rút các thẻ cho lần chọn hiện tại.
func draw_choices() -> Array:
	return UpgradesScript.draw(pools, taken, int(Global.XP["choices"]), rng)


## Lấy thẻ `id` (bậc kế). Trả false nếu id không hợp lệ / đã tối đa / không có lần chọn chờ.
func choose(id: String) -> bool:
	if pending <= 0:
		return false
	for c in UpgradesScript.available(pools, taken):
		if c["id"] == id:
			taken[id] = int(c["tier"])
			pending -= 1
			upgrade_chosen.emit(id, int(c["tier"]))
			return true
	return false


## Bỏ qua lần chọn (nhận hồi máu do main xử lý). Trả false nếu không có lần chọn chờ.
func skip() -> bool:
	if pending <= 0:
		return false
	pending -= 1
	return true
