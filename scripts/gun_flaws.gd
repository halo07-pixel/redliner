extends RefCounted
## Lỗi riêng của từng súng (M36). Chỉ logic + số; không biết UI/node. Chỉ hoạt động khi `enabled` (Vô Tận), để
## các chế độ khác bắn như cũ. Mỗi súng có "flaw" trong Global.WEAPONS; số liệu ở Global.FLAWS.
## `mods`: hệ số từ nâng cấp (chỉ làm nhẹ lỗi): rhythm_per_shot_mult, rhythm_recover_mult.

var enabled: bool = false
var mods: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _spread: Dictionary = {}   # id súng -> độ lệch hiện tại (độ)


func _init() -> void:
	rng.randomize()


## Id lỗi của súng ("" nếu không có / đang tắt).
func flaw_of(weapon_id: String) -> String:
	if not enabled or not Global.WEAPONS.has(weapon_id):
		return ""
	return String(Global.WEAPONS[weapon_id].get("flaw", ""))


## Độ lệch hiện tại của súng (độ); 0 nếu súng không có lỗi giật theo nhịp.
func spread(weapon_id: String) -> float:
	return float(_spread.get(weapon_id, 0.0)) if flaw_of(weapon_id) == "rhythm_recoil" else 0.0


func max_spread(weapon_id: String) -> float:
	return float(Global.FLAWS["rhythm_recoil"]["max_deg"]) if flaw_of(weapon_id) == "rhythm_recoil" else 0.0


## Hồi dần độ lệch theo thời gian.
func tick(delta: float) -> void:
	var f: Dictionary = Global.FLAWS["rhythm_recoil"]
	var rec: float = float(f["recover_deg_per_s"]) * float(mods.get("rhythm_recover_mult", 1.0))
	for id in _spread.keys():
		_spread[id] = maxf(float(_spread[id]) - rec * delta, 0.0)


## Hướng bắn sau khi tính lỗi: lệch ngẫu nhiên trong hình nón bán kính = độ lệch hiện tại (chưa tính phát này).
func aim(weapon_id: String, dir: Vector3) -> Vector3:
	var deg: float = spread(weapon_id)
	if deg <= 0.0:
		return dir
	var basis := Basis.looking_at(dir, Vector3.UP)
	var ang: float = rng.randf() * TAU
	var rad: float = sqrt(rng.randf()) * deg_to_rad(deg)
	return (basis * Vector3(sin(rad) * cos(ang), sin(rad) * sin(ang), -cos(rad))).normalized()


## Sau mỗi phát bắn: cộng độ lệch (tối đa max_deg).
func on_shot(weapon_id: String) -> void:
	if flaw_of(weapon_id) != "rhythm_recoil":
		return
	var f: Dictionary = Global.FLAWS["rhythm_recoil"]
	_spread[weapon_id] = minf(float(_spread.get(weapon_id, 0.0)) + float(f["per_shot_deg"]) * float(mods.get("rhythm_per_shot_mult", 1.0)), float(f["max_deg"]))


func reset() -> void:
	_spread.clear()
