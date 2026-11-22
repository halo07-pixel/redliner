extends Node3D
## Dây móc (chỉ là hiệu ứng hình ảnh). Player emit grapple_started/grapple_ended,
## Player nối Signal này tới show_to()/hide_rope().
## Dây là dải mặt có độ rộng, phóng ra từ tay tới điểm neo trong `shoot_time`, lúc bay thì lượn sóng
## rồi căng thẳng dần; đầu móc là khối sáng ở điểm neo.

const SEGMENTS: int = 18
const WIDTH: float = 0.05
const SHOOT_TIME: float = 0.12

var _target: Vector3 = Vector3.ZERO
var _mesh := ImmediateMesh.new()
var _mi := MeshInstance3D.new()
var _hook := MeshInstance3D.new()
var _age: float = 0.0
var progress: float = 0.0 # 0..1 độ dài dây đã phóng ra
var tension: float = 0.0  # 0..1 độ căng (dây dày + sáng hơn)


func _ready() -> void:
	top_level = true # vẽ theo toạ độ thế giới
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.15)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mi.mesh = _mesh
	_mi.material_override = mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.visible = false
	add_child(_mi)
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	_hook.mesh = sm
	_hook.material_override = mat
	_hook.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hook.visible = false
	add_child(_hook)
	set_process(false)


func show_to(point: Vector3) -> void:
	_target = point
	_age = 0.0
	progress = 0.0
	tension = 0.0
	_mi.visible = true
	_hook.visible = false
	set_process(true)


func hide_rope() -> void:
	_mi.visible = false
	_hook.visible = false
	_mesh.clear_surfaces()
	set_process(false)


func set_target(p: Vector3) -> void:
	_target = p


func set_tension(t: float) -> void:
	tension = clampf(t, 0.0, 1.0)


func is_attached() -> bool:
	return _hook.visible


func _process(delta: float) -> void:
	var parent := get_parent() as Node3D
	var cam := get_viewport().get_camera_3d()
	var start: Vector3 = parent.global_position + parent.global_transform.basis * Vector3(0.25, -0.25, -0.5)
	_age += delta
	progress = clampf(_age / SHOOT_TIME, 0.0, 1.0)
	var tip: Vector3 = start.lerp(_target, progress)
	_hook.visible = progress >= 1.0
	_hook.global_position = _target
	_hook.scale = Vector3.ONE * (1.0 + 0.5 * maxf(0.0, 1.0 - (_age - SHOOT_TIME) * 6.0))
	var dir: Vector3 = tip - start
	var len: float = dir.length()
	if len < 0.01:
		_mesh.clear_surfaces()
		return
	var view: Vector3 = (cam.global_position - start) if cam != null else Vector3.UP
	var side: Vector3 = dir.cross(view).normalized() * WIDTH * (0.5 + 0.6 * tension)
	var up: Vector3 = side.cross(dir).normalized()
	# Biên độ sóng giảm dần theo thời gian (dây căng dần) và tắt hẳn khi giảm hiệu ứng.
	var wave: float = 0.0 if Global.reduced_fx else 0.35 * maxf(0.0, 1.0 - _age * 3.0) * minf(len * 0.1, 1.0)
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEGMENTS + 1:
		var k: float = float(i) / float(SEGMENTS)
		var p: Vector3 = start.lerp(tip, k)
		p += up * sin(k * PI * 3.0 + _age * 30.0) * wave * sin(k * PI)
		_mesh.surface_add_vertex(p + side)
		_mesh.surface_add_vertex(p - side)
	_mesh.surface_end()
