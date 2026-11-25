extends Node3D
## Đạn pháo của người chơi: bay theo đường cong nhẹ, dò raycast mỗi bước (không xuyên tường),
## chạm là nổ. Vụ nổ là hàm tĩnh Rocket.explode() để test và nguồn khác dùng chung.
## Giao tiếp: phát tín hiệu `exploded`, không gọi lên node cha (call down, signal up).

signal exploded(position: Vector3, radius: float)

var velocity: Vector3 = Vector3.ZERO
var source: Node3D
var cfg: Dictionary = {}
var _life: float = 0.0
var _stuck: Node3D = null        # mìn dính (M38): đang dính vào thân bot này
var _stick_off: Vector3 = Vector3.ZERO
var _fuse: float = 0.0


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
	if _fuse > 0.0:
		_fuse -= delta
		if is_instance_valid(_stuck):
			global_position = _stuck.global_position + _stick_off
		if _fuse <= 0.0:
			_detonate(global_position)
		return
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
	var col: Object = hit["collider"]
	var body: Node3D = col.get_parent() as Node3D if col.has_method("take_hit") else null
	if float(cfg.get("sticky", 0.0)) > 0.0 and body != null and body != source:
		_stuck = body   # mìn dính: bám vào bot rồi nổ sau `sticky` giây
		_stick_off = pos - body.global_position
		global_position = pos
		velocity = Vector3.ZERO
		_fuse = float(cfg["sticky"])
		return
	_detonate(pos)


func _detonate(pos: Vector3) -> void:
	var chains: Array = explode(get_world_3d(), pos, cfg, source if is_instance_valid(source) else null)
	exploded.emit(pos, float(cfg["blast_radius"]))
	for c in chains:
		exploded.emit(c[0], c[1])   # nổ dây chuyền: mỗi vụ nổ thêm phát một Signal để hiệu ứng/âm thanh
	queue_free()


## Nổ tại `pos`: sát thương giảm dần theo khoảng cách, đẩy lùi và làm choáng kẻ địch trong bán kính.
## Người bắn cũng bị đẩy (rocket-jump) và chịu một phần nhỏ sát thương.
## Trả về danh sách vụ nổ dây chuyền đã xảy ra [[vị trí, bán kính], ...] (thẻ Nổ dây chuyền; rỗng nếu không có).
static func explode(world: World3D, pos: Vector3, cfg: Dictionary, source: Node3D) -> Array:
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
	var dead_centers: Array = []
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
			if bool(cfg.get("no_self", false)):
				continue   # nổ dây chuyền không hại người bắn
			if body.has_method("apply_blast"):
				body.apply_blast(push * float(cfg.get("self_push_mult", 1.0)))
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
			if "dead" in hb and hb.dead:
				dead_centers.append(center)
	var out: Array = []
	var depth: int = int(cfg.get("chain_depth", 0))
	if bool(cfg.get("chain", false)) and depth < int(Global.PERKS["chain_depth"]):
		for c in dead_centers:
			var cc: Dictionary = cfg.duplicate()
			cc["damage"] = float(cfg["damage"]) * float(Global.PERKS["chain_damage"])
			cc["blast_radius"] = radius * float(Global.PERKS["chain_radius"])
			cc["chain_depth"] = depth + 1
			cc["no_self"] = true
			out.append([c, cc["blast_radius"]])
			out.append_array(explode(world, c, cc, source))
	return out
