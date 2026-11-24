extends Area3D
## Cổng ra tầng (chế độ Vô Tận). Khoá: đỏ mờ. Mở: xanh sáng + cột sáng cao nhìn thấy từ xa. Chỉ phát Signal `entered`
## khi đang mở và người chơi bước vào; không biết gì về tầng, điểm hay HUD (main.gd nối).

signal entered

var is_open: bool = false
var _mat: StandardMaterial3D
var _beam: MeshInstance3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = Global.L_PLAYER
	var r: float = float(Global.ENDLESS["portal_radius"])
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = 6.0
	cs.shape = cyl
	cs.position = Vector3(0.0, 3.0, 0.0)
	add_child(cs)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ring := CylinderMesh.new()
	ring.top_radius = r
	ring.bottom_radius = r
	ring.height = 0.2
	ring.material = _mat
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = ring
	ring_mi.position = Vector3(0.0, 0.1, 0.0)
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring_mi)
	var bm := CylinderMesh.new()
	bm.top_radius = 1.2
	bm.bottom_radius = 1.2
	bm.height = 80.0
	bm.material = _mat
	_beam = MeshInstance3D.new()
	_beam.mesh = bm
	_beam.position = Vector3(0.0, 40.0, 0.0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	body_entered.connect(_on_body_entered)
	set_open(false)


func set_open(on: bool) -> void:
	is_open = on
	if _mat != null:
		_mat.albedo_color = Color(0.2, 1.0, 0.5, 0.55) if on else Color(1.0, 0.2, 0.2, 0.25)
	if _beam != null:
		_beam.visible = on


func _on_body_entered(body: Node3D) -> void:
	if is_open and body.is_in_group("player"):
		entered.emit()
