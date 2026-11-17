extends Area3D
## Vật nhặt: khối xoay + nhấp nhô; người chơi chạm vào thì phát `collected(kind)` rồi biến mất.
## Hết hạn sau Global.PICKUPS.lifetime (nhấp nháy ở blink_time cuối). Không tự áp hiệu ứng lên
## người chơi: node nghe signal (main) quyết định (call down, signal up).

signal collected(kind: String)

var kind: String = "health"
var age: float = 0.0
var _mesh: MeshInstance3D
var _taken: bool = false


## Chọn loại theo trọng số; roll trong [0,1) để test được kết quả cố định.
static func pick_kind(roll: float) -> String:
	var kinds: Dictionary = Global.PICKUPS["kinds"]
	var total: float = 0.0
	for k in kinds:
		total += float(kinds[k]["weight"])
	var acc: float = 0.0
	for k in kinds:
		acc += float(kinds[k]["weight"]) / total
		if roll < acc:
			return k
	return kinds.keys()[kinds.size() - 1]


static func spawn(parent: Node, pos: Vector3, p_kind: String) -> Area3D:
	var p: Area3D = load("res://scripts/pickup.gd").new()
	p.kind = p_kind
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = Global.L_PLAYER
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	cs.shape = sh
	add_child(cs)
	var c: Color = Global.PICKUPS["kinds"][kind]["color"]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 0.45, 0.45)
	bm.material = mat
	_mesh = MeshInstance3D.new()
	_mesh.mesh = bm
	_mesh.position.y = 0.8
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	var light := OmniLight3D.new()
	light.light_color = c
	light.light_energy = 0.8
	light.omni_range = 3.0
	light.position.y = 0.8
	light.shadow_enabled = false
	add_child(light)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	age += delta
	_mesh.rotation.y += delta * 2.5
	_mesh.position.y = 0.8 + sin(age * 3.0) * 0.12
	var life: float = float(Global.PICKUPS["lifetime"])
	var blink: float = float(Global.PICKUPS["blink_time"])
	if age > life - blink:
		_mesh.visible = int(age * 8.0) % 2 == 0
	if age >= life and not _taken:
		_taken = true
		queue_free()


func _on_body(body: Node3D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	collected.emit(kind)
	queue_free()
