extends Area3D
## Cổng ra tầng (chế độ Vô Tận). Khoá: vòng + cột đỏ mờ (vẫn thấy từ xa để biết hướng). Mở: xanh sáng, cột to và cao hơn,
## đèn toả sáng, nhịp thở nhẹ. Chỉ phát Signal `entered` khi đang mở và người chơi bước vào; không biết gì về tầng,
## điểm hay HUD (main.gd nối). Mọi con số chỉnh ở LOOK.

signal entered

const LOOK: Dictionary = {
	"locked_color": Color(1.0, 0.2, 0.2, 0.25), "open_color": Color(0.2, 1.0, 0.5, 0.55),
	"locked_radius": 1.2, "open_radius": 1.8,
	"locked_height": 80.0, "open_height": 140.0,
	"pulse_amount": 0.12, "pulse_speed": 3.0,
	"light_energy": 2.0, "light_range": 16.0,
}

var is_open: bool = false
var _mat: StandardMaterial3D
var _beam_mat: StandardMaterial3D
var _beam: MeshInstance3D
var _beam_mesh: CylinderMesh
var _light: OmniLight3D
var _t: float = 0.0


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
	_mat = _make_mat()
	_beam_mat = _make_mat()
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
	_beam_mesh = CylinderMesh.new()
	_beam_mesh.material = _beam_mat
	_beam = MeshInstance3D.new()
	_beam.mesh = _beam_mesh
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.2, 1.0, 0.5)
	_light.light_energy = float(LOOK["light_energy"])
	_light.omni_range = float(LOOK["light_range"])
	_light.position = Vector3(0.0, 2.0, 0.0)
	_light.shadow_enabled = false
	add_child(_light)
	body_entered.connect(_on_body_entered)
	set_open(false)


func _make_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func set_open(on: bool) -> void:
	is_open = on
	var c: Color = LOOK["open_color"] if on else LOOK["locked_color"]
	var rad: float = float(LOOK["open_radius"] if on else LOOK["locked_radius"])
	var h: float = float(LOOK["open_height"] if on else LOOK["locked_height"])
	if _mat != null:
		_mat.albedo_color = c
	if _beam_mat != null:
		_beam_mat.albedo_color = c
	if _beam_mesh != null:
		_beam_mesh.top_radius = rad
		_beam_mesh.bottom_radius = rad
		_beam_mesh.height = h
		_beam.position = Vector3(0.0, h * 0.5, 0.0)
		_beam.scale = Vector3.ONE
	if _light != null:
		_light.visible = on


func _process(delta: float) -> void:
	if not is_open or _beam == null or Global.reduced_fx:
		return
	_t += delta
	var k: float = 1.0 + sin(_t * float(LOOK["pulse_speed"])) * float(LOOK["pulse_amount"])
	_beam.scale = Vector3(k, 1.0, k)


func _on_body_entered(body: Node3D) -> void:
	if is_open and body.is_in_group("player"):
		entered.emit()
