extends Node3D
## MeleeHitboxComponent: một đòn kiếm gồm windup -> active -> recovery. Hộp sát thương nằm
## phía trước node này (-Z). Trong pha active mỗi frame quét hurtbox của phe đối diện (mỗi
## mục tiêu chỉ trúng 1 lần / đòn). Hai kiếm cùng active và quay mặt vào nhau thì CLASH.

signal swing_started(windup: float, active: float, recovery: float)
signal hit_landed(hurtbox: Area3D, landed: bool)
signal clashed(direction: Vector3)
signal staggered(duration: float)
signal got_parried # đòn của mình bị đối phương parry
signal rebounded(direction: Vector3)   # M39: chém trúng bot đang đỡ -> kiếm bị dội (hướng đẩy người chơi)

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

var team: int = 0
var body: Node3D
var phase: Phase = Phase.IDLE
var windup_override: float = -1.0 # > 0: thời gian báo đòn riêng (bot báo đòn lâu hơn để người chơi kịp phản ứng)

var _t: float = 0.0
var _stagger_t: float = 0.0
var _armed: bool = false
var _hit_list: Array = []
var heavy: bool = false # đòn đang đánh là chém rộng
var _active_time: float = 0.0
var _recovery_time: float = 0.0
var _reach: float = 0.0
var _shape := BoxShape3D.new()
var _sphere := SphereShape3D.new()
# M39: các hệ số của kiếm người chơi (combat đặt mỗi frame; mặc định tắt nên bot không bị ảnh hưởng)
var guard_rebound: float = 0.0     # > 0: khựng thêm bấy nhiêu giây khi chém trúng đối thủ đang đỡ (lỗi Phá thế đỡ)
var pierce_guard: float = 0.0      # tỉ lệ sát thương vẫn gây lên đối thủ đang đỡ (Mũi nhọn xuyên giáp)
var riposte_t: float = 0.0         # còn bao lâu cú chém kế được thưởng phản đòn
var riposte_mult: float = 1.0
var whirl_next: bool = false       # cú chém tới là vòng chém 360 độ (Vòng chém)
var _whirl: bool = false
var _riposte_swing: bool = false


func setup(p_team: int, p_body: Node3D) -> void:
	team = p_team
	body = p_body
	_shape.size = Vector3(1.8, 1.6, Global.COMBAT["sword_reach"])
	_active_time = Global.COMBAT["sword_active"]
	_recovery_time = Global.COMBAT["sword_recovery"]
	_reach = Global.COMBAT["sword_reach"]


func is_staggered() -> bool:
	return _stagger_t > 0.0


func is_active() -> bool:
	return phase == Phase.ACTIVE


func can_swing() -> bool:
	return phase == Phase.IDLE and _stagger_t <= 0.0


func try_swing(wide: bool = false) -> bool:
	if not can_swing():
		return false
	var C: Dictionary = Global.COMBAT
	var H: Dictionary = Global.HEAVY_SLASH
	var windup: float = windup_override if windup_override > 0.0 else C["sword_windup"]
	_active_time = C["sword_active"]
	_recovery_time = C["sword_recovery"]
	_reach = C["sword_reach"]
	var width: float = 1.8
	heavy = wide
	if wide:
		windup *= float(H["windup_mult"])
		_active_time *= float(H["active_mult"])
		_recovery_time *= float(H["recovery_mult"])
		_reach *= float(H["reach_mult"])
		width *= float(H["width_mult"])
	_shape.size = Vector3(width, 1.6, _reach)
	_whirl = whirl_next
	whirl_next = false
	_riposte_swing = riposte_t > 0.0
	if _riposte_swing:
		riposte_t = 0.0
	phase = Phase.WINDUP
	_t = windup
	_hit_list.clear()
	swing_started.emit(windup, _active_time, _recovery_time)
	return true


## Bị parry hoặc bị choáng: huỷ đòn đang đánh và không đánh được trong `duration` giây.
func stagger(duration: float) -> void:
	_leave_active()
	phase = Phase.IDLE
	_stagger_t = maxf(_stagger_t, duration)
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
	riposte_t = maxf(riposte_t - delta, 0.0)
	match phase:
		Phase.WINDUP:
			_t -= delta
			if _t <= 0.0:
				phase = Phase.ACTIVE
				_t = _active_time
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
				_t = _recovery_time
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
	var reach: float = _reach
	var q := PhysicsShapeQueryParameters3D.new()
	if _whirl:
		_sphere.radius = float(Global.PERKS["whirl_radius"])
		q.shape = _sphere
		q.transform = Transform3D(Basis.IDENTITY, (body.global_position if body != null else global_position) + Vector3(0.0, 0.95, 0.0))
	else:
		q.shape = _shape
		q.transform = Transform3D(global_transform.basis, global_position + _forward() * (reach * 0.5 + 0.2))
	q.collision_mask = Global.hurt_layer(1 - team)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var dmg_mult: float = (float(Global.HEAVY_SLASH["damage_mult"]) if heavy else 1.0)
	if _whirl:
		dmg_mult *= float(Global.PERKS["whirl_damage"])
	if _riposte_swing:
		dmg_mult *= riposte_mult
	for r in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var hb: Object = r["collider"]
		if hb in _hit_list or not hb.has_method("take_hit"):
			continue
		_hit_list.append(hb)
		var hit := {
			"damage": float(Global.COMBAT["sword_damage"]) * dmg_mult,
			"kind": "melee",
			"source": body,
			"direction": _forward(),
			"on_parried": _on_parried,
		}
		var guarded: bool = "parry" in hb and hb.parry != null and hb.parry.is_active()
		var landed: bool = hb.take_hit(hit)
		hit_landed.emit(hb, landed)
		if guarded and not landed:
			_on_guard_hit(hb, hit)
		elif landed and _whirl:
			_whirl_push(hb)


## Chém trúng đối thủ đang đỡ (đòn đã bị parry): xuyên giáp gây phần sát thương còn lại, lỗi Phá thế đỡ dội kiếm lại.
func _on_guard_hit(hb: Object, hit: Dictionary) -> void:
	if pierce_guard > 0.0 and not hb.dead:
		var through: Dictionary = hit.duplicate()
		through["damage"] = float(hit["damage"]) * pierce_guard
		through["on_parried"] = func(): pass
		hb.take_hit(through)   # parry đã bị tiêu hao nên đòn này trúng thật
	if guard_rebound > 0.0 and not _riposte_swing:
		stagger(float(Global.COMBAT["sword_stagger_when_parried"]) + guard_rebound)
		rebounded.emit(-_forward())


func _whirl_push(hb: Object) -> void:
	var tb: Node3D = hb.get_parent() as Node3D
	if tb == null or tb == body or not tb.has_method("apply_knockback"):
		return
	var away: Vector3 = tb.global_position - (body.global_position if body != null else global_position)
	away.y = 0.0
	tb.apply_knockback(away.normalized() * float(Global.PERKS["whirl_push"]) + Vector3(0.0, 2.0, 0.0))


func _on_parried() -> void:
	got_parried.emit()
	stagger(Global.COMBAT["sword_stagger_when_parried"])
