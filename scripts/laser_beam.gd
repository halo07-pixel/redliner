extends Node3D
## Tia laser đỏ của lỗi "nạp ngắm" (bắn tỉa, Vô Tận). Chỉ hiển thị: main nối Signal charge_changed vào set_charging;
## mỗi khung hình đọc đoạn laser từ combat của người chơi (laser_segment) để căn tia. Không có logic chơi.

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _on: bool = false
var _combat: Node


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(1.0, 0.1, 0.1, 0.5)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.03, 1.0)
	bm.material = _mat
	_mesh = MeshInstance3D.new()
	_mesh.mesh = bm
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.visible = false
	add_child(_mesh)


## ratio 0..1: càng gần nổ càng đậm và dày.
func set_charging(on: bool, ratio: float) -> void:
	_on = on
	if _mat != null:
		_mat.albedo_color = Color(1.0, 0.1, 0.1, 0.35 + 0.6 * ratio)
		_mesh.scale = Vector3(1.0 + 2.0 * ratio, 1.0 + 2.0 * ratio, 1.0)
		_mesh.visible = on


func _process(_delta: float) -> void:
	if not _on:
		return
	if _combat == null:
		var pl := get_tree().get_first_node_in_group("player")
		_combat = pl.get("combat") if pl != null else null
		if _combat == null:
			return
	var seg: PackedVector3Array = _combat.laser_segment()
	var len: float = seg[0].distance_to(seg[1])
	if len < 0.01:
		return
	_mesh.global_position = (seg[0] + seg[1]) * 0.5
	_mesh.look_at(seg[1], Vector3.UP)
	_mesh.scale.z = len
