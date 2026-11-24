extends Node
## Mục tiêu giả cho test_m35: ghi lại sát thương nhận được.
var hits: Array = []


func take_hit(h: Dictionary) -> bool:
	hits.append(float(h["damage"]))
	return true
