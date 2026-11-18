extends Node3D
## Đạn pháo của người chơi: bay theo đường cong nhẹ, dò raycast mỗi bước (không xuyên tường),
## chạm là nổ. Vụ nổ là hàm tĩnh Rocket.explode() để test và nguồn khác dùng chung.
## Giao tiếp: phát tín hiệu `exploded`, không gọi lên node cha (call down, signal up).

signal exploded(position: Vector3, radius: float)

var velocity: Vector3 = Vector3.ZERO
var source: Node3D
var cfg: Dictionary = {}
var _life: float = 0.0


func setup(p_source: Node3D, p_cfg: Dictionary, dir: Vector3) -> void:
	source = p_source
	cfg = p_cfg
	velocity = dir.normalized() * float(cfg["projectile_speed"])


func _ready() -> void:
	var m := SphereMesh.new()
	m.radius = 0.14
	m.height = 0.28
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.75, 0.2)
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	add_child(mi)


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > float(cfg["life"]):
		queue_free()
		return
	velocity.y -= float(cfg["gravity"]) * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, int(cfg.get("hit_mask", Global.L_WORLD | Global.L_ENEMY_HURT)))
	q.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	var pos: Vector3 = hit["position"]
	explode(get_world_3d(), pos, cfg, source)
	exploded.emit(pos, float(cfg["blast_radius"]))
	queue_free()


## Nổ tại `pos`: sát thương giảm dần theo khoảng cách, đẩy lùi và làm choáng kẻ địch trong bán kính.
## Người bắn cũng bị đẩy (rocket-jump) và chịu một phần nhỏ sát thương.
static func explode(world: World3D, pos: Vector3, cfg: Dictionary, source: Node3D) -> void:
	var radius: float = float(cfg["blast_radius"])
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, pos)
	q.collision_mask = Global.L_ENEMY_HURT | Global.L_PLAYER_HURT
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var seen: Array = []
	for r in world.direct_space_state.intersect_shape(q, 32):
		var hb: Object = r["collider"]
		if hb in seen or not hb.has_method("take_hit"):
			continue
		if cfg.has("skip_team") and "team" in hb and hb.team == int(cfg["skip_team"]):
			continue # đạn nổ của bot không hại phe bot
		seen.append(hb)
		var body: Node3D = hb.get_parent() as Node3D
		var center: Vector3 = body.global_position + Vector3(0.0, 0.95, 0.0)
		var dist: float = center.distance_to(pos)
		var k: float = clampf(1.0 - dist / radius, 0.0, 1.0)
		var scale: float = lerpf(float(cfg["min_falloff"]), 1.0, k)
		var dir: Vector3 = (center - pos).normalized() if dist > 0.01 else Vector3.UP
		var push: Vector3 = dir * float(cfg["knockback"]) * scale
		if body == source:
			if body.has_method("apply_blast"):
				body.apply_blast(push)
			hb.take_hit({"damage": float(cfg["damage"]) * scale * float(cfg["self_damage_mult"]),
				"kind": "explosion", "source": source, "direction": dir})
			continue
		var landed: bool = hb.take_hit({"damage": float(cfg["damage"]) * scale,
			"kind": "explosion", "source": source, "direction": dir})
		if landed:
			if body.has_method("apply_knockback"):
				body.apply_knockback(push)
			elif body.has_method("apply_blast"):
				body.apply_blast(push)
			if "melee" in body and body.melee != null:
				body.melee.stagger(float(cfg["stagger"]))
