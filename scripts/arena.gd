extends Node3D
## Đấu trường thử nghiệm dựng bằng code: sàn, 4 tường, cột đỏ, vài bục cao để tập nhảy,
## ánh sáng + bầu trời, và 1 hình nhân làm bia. Các cột/tường cao sẽ là chỗ wallrun/grapple
## ở mốc sau.

const DummyScript = preload("res://scripts/enemy_dummy.gd")

const HALF: float = 30.0
const WALL_H: float = 12.0

var spawn_point: Vector3 = Vector3(0.0, 0.1, 18.0)
var dummies: Array = []
## Điểm sinh bot (rải quanh đấu trường, tránh cột/bục/dốc).
var bot_spawns: Array = [
	Vector3(-25.0, 0.1, -26.0), Vector3(25.0, 0.1, -26.0), Vector3(0.0, 0.1, -27.0),
	Vector3(-27.0, 0.1, 20.0), Vector3(27.0, 0.1, 26.0), Vector3(-14.0, 0.1, -5.0),
]


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
	# Tường để chạy tường (dài 30m, cao 8m) + bục cao để móc lên
	_box(Vector3(1.0, 8.0, 30.0), Vector3(-22.0, 4.0, -5.0), Color(0.25, 0.4, 0.7))
	_box(Vector3(6.0, 0.5, 6.0), Vector3(0.0, 8.0, -22.0), Color(0.9, 0.7, 0.2))
	# Dốc 20° để tập trượt (cao dần về phía -Z, trượt xuống phía +Z)
	_box(Vector3(10.0, 1.0, 20.0), Vector3(22.0, 2.0, -10.0), Color(0.35, 0.55, 0.35), Vector3(20.0, 0.0, 0.0))
	_spawn_dummy(Vector3(0.0, 0.0, -12.0), Color(0.85, 0.2, 0.2)) # bia tập kiếm/súng


func _box(size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Global.L_WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees = rot_deg
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


func _spawn_dummy(pos: Vector3, color: Color) -> void:
	var d: StaticBody3D = DummyScript.new()
	d.color = color
	d.position = pos
	d.rotation.y = PI # quay mặt về phía điểm spawn
	add_child(d)
	dummies.append(d)


func _build_environment() -> void:
	var e: Dictionary = Global.ENV
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = e["sun_rotation_deg"]
	sun.light_color = e["sun_color"]
	sun.light_energy = e["sun_energy"]
	sun.shadow_enabled = true
	sun.shadow_bias = e["shadow_bias"]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = e["shadow_max_distance"]
	sun.directional_shadow_split_1 = e["shadow_split_1"]
	sun.directional_shadow_split_2 = e["shadow_split_2"]
	sun.directional_shadow_split_3 = e["shadow_split_3"]
	add_child(sun)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = e["sky_top"]
	sky_mat.sky_horizon_color = e["sky_horizon"]
	sky_mat.ground_horizon_color = e["ground_horizon"]
	sky_mat.ground_bottom_color = e["ground_bottom"]
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = e["ambient_energy"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = e["tonemap_exposure"]
	env.tonemap_white = e["tonemap_white"]
	env.fog_enabled = true
	env.fog_light_color = e["fog_color"]
	env.fog_density = e["fog_density"]
	env.fog_sky_affect = e["fog_sky_affect"]
	env.glow_enabled = true
	env.glow_intensity = e["glow_intensity"]
	env.glow_bloom = e["glow_bloom"]
	env.glow_hdr_threshold = e["glow_hdr_threshold"]

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
