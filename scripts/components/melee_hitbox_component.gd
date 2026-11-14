extends Node3D
## MeleeHitboxComponent: một đòn kiếm gồm windup -> active -> recovery. Hộp sát thương nằm
## phía trước node này (-Z). Trong pha active mỗi frame quét hurtbox của phe đối diện (mỗi
## mục tiêu chỉ trúng 1 lần / đòn). Hai kiếm cùng active và quay mặt vào nhau thì CLASH.

signal swing_started(windup: float, active: float, recovery: float)
signal hit_landed(hurtbox: Area3D, landed: bool)
signal clashed(direction: Vector3)
signal staggered(duration: float)

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

var team: int = 0
var body: Node3D
var phase: Phase = Phase.IDLE
var damage_mult: float = 1.0 # Redline tăng sát thương
var windup_override: float = -1.0 # > 0: thời gian báo đòn riêng (bot báo đòn lâu hơn để người chơi kịp phản ứng)

var _t: float = 0.0
var _stagger_t: float = 0.0
var _armed: bool = false
var _hit_list: Array = []
var _shape := BoxShape3D.new()


func setup(p_team: int, p_body: Node3D) -> void:
	team = p_team
	body = p_body
	_shape.size = Vector3(1.8, 1.6, Global.COMBAT["sword_reach"])


func is_staggered() -> bool:
	return _stagger_t > 0.0


func is_active() -> bool:
	return phase == Phase.ACTIVE


func can_swing() -> bool:
	return phase == Phase.IDLE and _stagger_t <= 0.0


func try_swing() -> bool:
	if not can_swing():
		return false
	var windup: float = windup_override if windup_override > 0.0 else Global.COMBAT["sword_windup"]
	phase = Phase.WINDUP
	_t = windup
	_hit_list.clear()
	swing_started.emit(windup, Global.COMBAT["sword_active"], Global.COMBAT["sword_recovery"])
	return true


## Bị parry hoặc bị choáng: huỷ đòn đang đánh và không đánh được trong `duration` giây.
func stagger(duration: float) -> void:
	_leave_active()
	phase = Phase.IDLE
	_stagger_t = duration
	staggered.emit(duration)


## Hai kiếm chạm nhau: cả hai bị choáng ngắn và bị đẩy ra xa nhau.
func force_clash(other_pos: Vector3) -> void:
	_leave_active()
	phase = Phase.IDLE
	_stagger_t = Global.COMBAT["clash_stagger"]
	var away: Vector3 = global_position - other_pos
	away.y = 0.0
	clashed.emit(away.normalized())


func _forward() -> Vector3:
	return -global_transform.basis.z


func _leave_active() -> void:
	if is_in_group("swords_active"):
		remove_from_group("swords_active")
	_armed = false


func _physics_process(delta: float) -> void:
	_stagger_t = maxf(_stagger_t - delta, 0.0)
	match phase:
		Phase.WINDUP:
			_t -= delta
			if _t <= 0.0:
				phase = Phase.ACTIVE
				_t = Global.COMBAT["sword_active"]
				_armed = false # frame đầu chỉ đăng ký "đang active" để clash không phụ thuộc thứ tự xử lý
				add_to_group("swords_active")
		Phase.ACTIVE:
			if _armed:
				_scan()
			_armed = true
			_t -= delta
			if phase == Phase.ACTIVE and _t <= 0.0:
				_leave_active()
				phase = Phase.RECOVERY
				_t = Global.COMBAT["sword_recovery"]
		Phase.RECOVERY:
			_t -= delta
			if _t <= 0.0:
				phase = Phase.IDLE


func _find_clash() -> Node3D:
	var rng: float = Global.COMBAT["clash_range"]
	for n in get_tree().get_nodes_in_group("swords_active"):
		if n == self or n.team == team:
			continue
		var to_other: Vector3 = n.global_position - global_position
		if to_other.length() > rng:
			continue
		if _forward().dot(to_other) > 0.0 and n._forward().dot(-to_other) > 0.0:
			return n
	return null


func _scan() -> void:
	var other := _find_clash()
	if other != null:
		var my_pos: Vector3 = global_position
		force_clash(other.global_position)
		other.force_clash(my_pos)
		return
	var reach: float = Global.COMBAT["sword_reach"]
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _shape
	q.transform = Transform3D(global_transform.basis, global_position + _forward() * (reach * 0.5 + 0.2))
	q.collision_mask = Global.hurt_layer(1 - team)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for r in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var hb: Object = r["collider"]
		if hb in _hit_list or not hb.has_method("take_hit"):
			continue
		_hit_list.append(hb)
		var hit := {
			"damage": float(Global.COMBAT["sword_damage"]) * damage_mult,
			"kind": "melee",
			"source": body,
			"direction": _forward(),
			"on_parried": _on_parried,
		}
		var landed: bool = hb.take_hit(hit)
		hit_landed.emit(hb, landed)


func _on_parried() -> void:
	stagger(Global.COMBAT["sword_stagger_when_parried"])
