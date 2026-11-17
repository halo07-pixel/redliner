extends Node3D
## SwordTrail: vệt kiếm. Gắn làm con của node Melee; chỉ nghe signal swing_started (không đụng logic
## sát thương). Trong pha active, mỗi frame ghi một cặp điểm (gốc, mũi) quét ngang trước mặt,
## dựng dải mặt mờ dần theo thời gian rồi tự xoá. Giảm hiệu ứng thì không vẽ.

var _melee: Node3D
var _mesh := ImmediateMesh.new()
var _mi := MeshInstance3D.new()
var _mat := StandardMaterial3D.new()
var _points: Array = [] # [{base, tip, age}]
var _t_wait: float = 0.0
var _t_active: float = 0.0
var _sweep_t: float = 0.0
var _color: Color = Color.WHITE
var _wide: bool = false


static func attach(melee: Node3D) -> Node3D:
	var t: Node3D = load("res://scripts/sword_trail.gd").new()
	melee.add_child(t)
	t._melee = melee
	melee.swing_started.connect(t._on_swing)
	return t


func _ready() -> void:
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.vertex_color_use_as_albedo = true
	_mi.mesh = _mesh
	_mi.material_override = _mat
	_mi.top_level = true # toạ độ thế giới: vệt ở lại khi kiếm đã quay đi
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)


func is_drawing() -> bool:
	return _t_active > 0.0 or not _points.is_empty()


func point_count() -> int:
	return _points.size()


func _on_swing(windup: float, active: float, _recovery: float) -> void:
	_points.clear()
	if Global.reduced_fx:
		_t_wait = 0.0
		_t_active = 0.0
		return
	_wide = _melee.heavy
	_color = Global.FX["heavy_trail_color"] if _wide else Global.FX["trail_color"]
	_t_wait = windup
	_t_active = active
	_sweep_t = active


func _process(delta: float) -> void:
	if _t_wait > 0.0:
		_t_wait -= delta
	elif _t_active > 0.0:
		_t_active -= delta
		_record()
	var life: float = float(Global.FX["trail_life"])
	for p in _points:
		p["age"] += delta
	while not _points.is_empty() and _points[0]["age"] > life:
		_points.pop_front()
	_rebuild(life)


## Mũi kiếm quét từ trái sang phải trước mặt trong pha active.
func _record() -> void:
	var k: float = 1.0 - clampf(_t_active / maxf(_sweep_t, 0.001), 0.0, 1.0) # 0..1
	var reach: float = float(Global.COMBAT["sword_reach"]) * (float(Global.HEAVY_SLASH["reach_mult"]) if _wide else 1.0)
	var half_w: float = 0.9 * (float(Global.HEAVY_SLASH["width_mult"]) if _wide else 1.0)
	var b: Basis = _melee.global_transform.basis
	var o: Vector3 = _melee.global_position
	var side: float = lerpf(-half_w, half_w, k)
	var tip: Vector3 = o + b * Vector3(side, -0.1, -reach * 0.9)
	var base: Vector3 = o + b * Vector3(side * 0.35, -0.1, -0.6)
	_points.append({"base": base, "tip": tip, "age": 0.0})
	while _points.size() > int(Global.FX["trail_max_points"]):
		_points.pop_front()


func _rebuild(life: float) -> void:
	_mesh.clear_surfaces()
	if _points.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p in _points:
		var c: Color = _color
		c.a *= clampf(1.0 - p["age"] / life, 0.0, 1.0)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(p["tip"])
		_mesh.surface_set_color(Color(c.r, c.g, c.b, c.a * 0.4))
		_mesh.surface_add_vertex(p["base"])
	_mesh.surface_end()
