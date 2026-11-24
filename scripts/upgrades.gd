extends RefCounted
## Dữ liệu + quy tắc rút thẻ nâng cấp (thuần logic, không UI/node). Dữ liệu ở Global.UPGRADES.
## `taken`: {id: số bậc đã lấy}. Id thẻ là duy nhất trong mọi kho (M38/M39 thêm kho riêng từng súng / kiếm).


## Mọi thẻ của các kho `pools` mà chưa đạt bậc tối đa -> mảng {id, pool, tier (bậc kế), ...dữ liệu thẻ}.
static func available(pools: Array, taken: Dictionary) -> Array:
	var out: Array = []
	for pool in pools:
		var cards: Dictionary = Global.UPGRADES.get(pool, {})
		for id in cards:
			var t: int = int(taken.get(id, 0))
			if t >= int(cards[id]["max"]):
				continue
			var c: Dictionary = (cards[id] as Dictionary).duplicate()
			c["id"] = id
			c["pool"] = pool
			c["tier"] = t + 1
			out.append(c)
	return out


## Rút tối đa n thẻ khác nhau (ít hơn nếu còn ít thẻ).
static func draw(pools: Array, taken: Dictionary, n: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = available(pools, taken)
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


## Tổng giá trị thống kê `stat` từ các thẻ đã lấy: "mult" -> hệ số 1 + tổng; "add" -> tổng.
static func stat(taken: Dictionary, stat_name: String) -> float:
	var total: float = 0.0
	var is_mult: bool = false
	for pool in Global.UPGRADES:
		for id in Global.UPGRADES[pool]:
			var c: Dictionary = Global.UPGRADES[pool][id]
			if c["stat"] != stat_name:
				continue
			is_mult = c["kind"] == "mult"
			total += float(c["per"]) * int(taken.get(id, 0))
	return 1.0 + total if is_mult else total
