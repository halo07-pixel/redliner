extends Node3D
## Hình nhân người 3D dựng hoàn toàn bằng khối cơ bản (đầu, thân, 2 tay, 2 chân) — không cần
## asset ngoài. Cao ~1.8m, gốc ở chân (khớp với CharacterBody3D của người chơi/bot sau này).
## Bot ở các mốc sau sẽ dùng lại script này (đổi `color` theo phe/loại).

@export var color: Color = Color(0.85, 0.85, 0.9)

var _mat: StandardMaterial3D


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	_mat = mat
	_add_part(_capsule(0.12, 0.85), Vector3(-0.13, 0.425, 0.0), mat) # chân trái
	_add_part(_capsule(0.12, 0.85), Vector3(0.13, 0.425, 0.0), mat)  # chân phải
	_add_part(_box(Vector3(0.5, 0.65, 0.28)), Vector3(0.0, 1.17, 0.0), mat) # thân
	_add_part(_capsule(0.08, 0.7), Vector3(-0.34, 1.15, 0.0), mat)   # tay trái
	_add_part(_capsule(0.08, 0.7), Vector3(0.34, 1.15, 0.0), mat)    # tay phải
	var head := SphereMesh.new()
	head.radius = 0.14
	head.height = 0.28
	_add_part(head, Vector3(0.0, 1.66, 0.0), mat)                    # đầu


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _add_part(mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


## Nháy trắng khi trúng đòn.
func flash() -> void:
	_mat.albedo_color = Color.WHITE
	create_tween().tween_property(_mat, "albedo_color", color, 0.12)


## Mờ dần (khi chết).
func fade_out(duration: float) -> void:
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var c := _mat.albedo_color
	create_tween().tween_property(_mat, "albedo_color", Color(c.r, c.g, c.b, 0.0), duration)
