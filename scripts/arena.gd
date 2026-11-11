extends Node3D
## Đấu trường thử nghiệm dựng bằng code: sàn, 4 tường, cột đỏ, vài bục cao để tập nhảy,
## ánh sáng + bầu trời, và 1 hình nhân làm bia. Các cột/tường cao sẽ là chỗ wallrun/grapple
## ở mốc sau.

const MannequinScript = preload("res://scripts/mannequin.gd")

const HALF: float = 30.0
const WALL_H: float = 12.0

var spawn_point: Vector3 = Vector3(0.0, 0.1, 18.0)


func _ready() -> void:
	_build_environment()
	_box(Vector3(HALF * 2.0, 1.0, HALF * 2.0), Vector3(0.0, -0.5, 0.0), Color(0.18, 0.18, 0.2))
	# 4 tường bao quanh
	_box(Vector3(HALF * 2.0, WALL_H, 1.0), Vector3(0.0, WALL_H * 0.5, -HALF - 0.5), Color(0.3, 0.3, 0.34))
	_box(Vector3(HALF * 2.0, WALL_H, 1.0), Vector3(0.0, WALL_H * 0.5, HALF + 0.5), Color(0.3, 0.3, 0.34))
	_box(Vector3(1.0, WALL_H, HALF * 2.0), Vector3(HALF + 0.5, WALL_H * 0.5, 0.0), Color(0.3, 0.3, 0.34))
	_box(Vector3(1.0, WALL_H, HALF * 2.0), Vector3(-HALF - 0.5, WALL_H * 0.5, 0.0), Color(0.3, 0.3, 0.34))
	# 4 cột đỏ
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(2.5, 10.0, 2.5), Vector3(14.0 * sx, 5.0, 14.0 * sz), Color(0.75, 0.12, 0.12))
	# 2 bục liền nhau (cao 1.0 rồi 2.5): nhảy 2 nhịp là lên tới đỉnh
	_box(Vector3(8.0, 1.0, 8.0), Vector3(8.0, 0.5, 10.0), Color(0.4, 0.4, 0.45))
	_box(Vector3(6.0, 2.5, 6.0), Vector3(14.5, 1.25, 10.0), Color(0.5, 0.5, 0.55))
	_spawn_dummy(Vector3(0.0, 0.0, -12.0))


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Global.L_WORLD
	body.collision_mask = 0
	body.position = pos
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	body.add_child(mi)
	add_child(body)


## Bia hình nhân: có va chạm (layer enemy + world để người chơi không đi xuyên qua).
## Mốc sau sẽ thay bằng bot thật có Hurtbox.
func _spawn_dummy(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Global.L_ENEMY | Global.L_WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = PI # quay mặt về phía điểm spawn
	var shape := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.35
	cs.height = 1.8
	shape.shape = cs
	shape.position = Vector3(0.0, 0.9, 0.0)
	body.add_child(shape)
	var m: Node3D = MannequinScript.new()
	m.color = Color(0.85, 0.2, 0.2)
	body.add_child(m)
	add_child(body)


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
