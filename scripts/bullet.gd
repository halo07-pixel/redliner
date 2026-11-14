extends Node3D
## Đạn vật thể của địch. Mỗi bước vật lý dò raycast (không xuyên mục tiêu mỏng).
## Khi trúng hurtbox có parry, ParryComponent gọi reflect() -> đạn đổi chủ, bay ngược về
## người bắn với sát thương lớn hơn.

var team: int = Global.TEAM_ENEMY
var shooter: Node3D
var velocity: Vector3 = Vector3.ZERO
var damage: float = 15.0
var reflected: bool = false

var _life: float = 0.0
var _reflect_frame: int = -1
var _mat := StandardMaterial3D.new()


func setup(p_team: int, p_shooter: Node3D, dir: Vector3) -> void:
	team = p_team
	shooter = p_shooter
	velocity = dir.normalized() * float(Global.COMBAT["bullet_speed"])
	damage = Global.COMBAT["bullet_damage"]


func _ready() -> void:
	add_to_group("bullets")
	var m := SphereMesh.new()
	m.radius = 0.12
	m.height = 0.24
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_update_color()
	m.material = _mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	add_child(mi)


func _update_color() -> void:
	_mat.albedo_color = Color(1.0, 0.55, 0.1) if team == Global.TEAM_ENEMY else Color(0.3, 0.8, 1.0)


func _target_mask() -> int:
	return Global.L_WORLD | Global.hurt_layer(1 - team)


## Gọi bởi ParryComponent.
func reflect(by: Node3D, damage_mult: float, speed_mult: float) -> void:
	var speed: float = velocity.length() * speed_mult
	var dir: Vector3 = -velocity.normalized()
	if is_instance_valid(shooter):
		dir = (shooter.global_position + Vector3(0.0, 1.2, 0.0) - global_position).normalized()
	velocity = dir * speed
	damage *= damage_mult
	team = 1 - team
	shooter = by
	reflected = true
	_reflect_frame = Engine.get_physics_frames()
	_update_color()


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > float(Global.COMBAT["bullet_life"]):
		queue_free()
		return
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, _target_mask())
	q.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	var c: Object = hit["collider"]
	if c.has_method("take_hit"):
		c.take_hit({
			"damage": damage,
			"kind": "bullet",
			"source": shooter,
			"direction": velocity.normalized(),
			"bullet": self,
		})
		if _reflect_frame == Engine.get_physics_frames():
			global_position = hit["position"]
			return # vừa bị parry: tiếp tục bay ngược lại
	queue_free()
