extends RefCounted
## Thống kê một ván: bot hạ theo loại, số phát bắn trúng / tổng, thời gian sống. Dữ liệu thuần (không phụ thuộc scene).

var kills_by_type: Dictionary = {}
var shots: int = 0
var hits: int = 0
var time_alive: float = 0.0


func record_kill(type_name: String) -> void:
	kills_by_type[type_name] = int(kills_by_type.get(type_name, 0)) + 1


func record_shot() -> void:
	shots += 1


func record_hit(landed: bool) -> void:
	if landed:
		hits += 1


func tick(delta: float) -> void:
	time_alive += delta


func kills_total() -> int:
	var n: int = 0
	for k in kills_by_type:
		n += int(kills_by_type[k])
	return n


## Tỉ lệ trúng của súng (0..1); -1 nếu chưa bắn phát nào.
func accuracy() -> float:
	if shots <= 0:
		return -1.0
	return clampf(float(hits) / float(shots), 0.0, 1.0)


static func format_time(seconds: float) -> String:
	var t: int = maxi(int(seconds), 0)
	return "%d:%02d" % [t / 60, t % 60]


## "Lính kiếm 5, Lao nhanh 2" theo thứ tự cố định; rỗng nếu chưa hạ bot nào.
func breakdown_text() -> String:
	var parts: Array = []
	for id in Global.BOT_ORDER:
		if kills_by_type.has(id):
			parts.append("%s %d" % [Global.BOT_NAMES[id], int(kills_by_type[id])])
	return ", ".join(parts)
