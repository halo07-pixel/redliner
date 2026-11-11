extends Node3D
## Dây móc (chỉ là hiệu ứng hình ảnh). Player emit grapple_started/grapple_ended,
## Player nối Signal này tới show_to()/hide_rope().

var _target: Vector3 = Vector3.ZERO
var _mesh := ImmediateMesh.new()
var _mi := MeshInstance3D.new()


func _ready() -> void:
	top_level = true # vẽ theo toạ độ thế giới
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.35, 0.2)
	_mi.mesh = _mesh
	_mi.material_override = mat
	_mi.visible = false
	add_child(_mi)
	set_process(false)


func show_to(point: Vector3) -> void:
	_target = point
	_mi.visible = true
	set_process(true)


func hide_rope() -> void:
	_mi.visible = false
	_mesh.clear_surfaces()
	set_process(false)


func _process(_delta: float) -> void:
	var parent := get_parent() as Node3D
	var start: Vector3 = parent.global_position + parent.global_transform.basis * Vector3(0.25, -0.25, -0.5)
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_mesh.surface_add_vertex(start)
	_mesh.surface_add_vertex(_target)
	_mesh.surface_end()
