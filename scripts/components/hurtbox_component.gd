extends Area3D
## HurtboxComponent: vùng nhận sát thương + máu. Mọi nguồn sát thương (kiếm, đạn, súng) gọi
## take_hit(hit). Nếu có ParryComponent đang trong cửa sổ parry thì đòn bị đỡ trước khi trừ máu.
## hit là Dictionary: {damage, kind: "melee"|"bullet"|"hitscan", source, direction, bullet?, on_parried?}

signal hurt(hit: Dictionary, health_left: float)
signal health_changed(current: float, maximum: float)
signal died

var team: int = 0
var max_health: float = 100.0
var health: float = 100.0
var dead: bool = false
var parry: Node = null


## Tiêm phụ thuộc (setup injection): phe, máu tối đa, và parry (nếu có).
func setup(p_team: int, p_max_health: float, p_parry: Node = null) -> void:
	team = p_team
	max_health = p_max_health
	health = p_max_health
	parry = p_parry
	dead = false
	collision_layer = Global.hurt_layer(team)
	collision_mask = 0
	monitoring = false
	health_changed.emit(health, max_health)


## Trả về true nếu đòn thật sự gây sát thương (false nếu bị parry hoặc đã chết).
func take_hit(hit: Dictionary) -> bool:
	if dead:
		return false
	if parry != null and parry.try_parry(hit):
		return false
	health = maxf(health - float(hit["damage"]), 0.0)
	hurt.emit(hit, health)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		dead = true
		died.emit()
	return true


func revive() -> void:
	dead = false
	health = max_health
	collision_layer = Global.hurt_layer(team)
	health_changed.emit(health, max_health)
