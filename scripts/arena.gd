extends Node3D
## Đấu trường thử nghiệm dựng bằng code: sàn, 4 tường, cột đỏ, vài bục cao để tập nhảy,
## ánh sáng + bầu trời, và 1 hình nhân làm bia. Các cột/tường cao sẽ là chỗ wallrun/grapple
## ở mốc sau.

const DummyScript = preload("res://scripts/enemy_dummy.gd")
const Materials = preload("res://scripts/materials.gd")
const Quality = preload("res://scripts/quality.gd")

const Maps = preload("res://scripts/maps.gd")
const BreakableScript = preload("res://scripts/breakable.gd")

signal map_loaded(map_id: String)
signal explosion(position: Vector3, radius: float) # thùng nổ phát nổ
signal prop_broken(position: Vector3, kind: String) # thùng/barrel vỡ (để rơi đồ)

var map_id: String = ""
var half: Vector2 = Vector2(30.0, 30.0)
var wall_h: float = 12.0
var void_y: float = -30.0
var spawn_point: Vector3 = Vector3(0.0, 0.1, 18.0)
var dummies: Array = []
var sun: DirectionalLight3D
var world_env: Environment
## Điểm sinh bot (do map quy định, tránh cột/bục/dốc).
var bot_spawns: Array = []
var props: Array = []
var nav_region: NavigationRegion3D
var bake_nav: bool = true # tắt được cho test cần dựng nhanh


func _ready() -> void:
	if map_id == "":
		map_id = Global.selected_map
	_build_environment()
	_build_map(map_id)


## Dựng đấu trường từ dữ liệu Maps (sàn, 4 tường, các khối, bia tập). Phát map_loaded khi xong.
func _build_map(id: String) -> void:
	var m: Dictionary = Maps.get_map(id)
	map_id = id
	half = m["half"]
	wall_h = float(m["wall_h"])
	void_y = float(m["void_y"])
	spawn_point = m["spawn"]
	bot_spawns = m["bot_spawns"]
	_box(Vector3(half.x * 2.0, 1.0, half.y * 2.0), Vector3(0.0, -0.5, 0.0), "floor")
	_box(Vector3(half.x * 2.0, wall_h, 1.0), Vector3(0.0, wall_h * 0.5, -half.y - 0.5), "wall")
	_box(Vector3(half.x * 2.0, wall_h, 1.0), Vector3(0.0, wall_h * 0.5, half.y + 0.5), "wall")
	_box(Vector3(1.0, wall_h, half.y * 2.0), Vector3(half.x + 0.5, wall_h * 0.5, 0.0), "wall")
	_box(Vector3(1.0, wall_h, half.y * 2.0), Vector3(-half.x - 0.5, wall_h * 0.5, 0.0), "wall")
	for bx in m["boxes"]:
		_box(bx["size"], bx["pos"], bx["role"], bx["rot"])
	_build_trim()
	for dp in m["dummies"]:
		_spawn_dummy(dp, Color(0.85, 0.2, 0.2))
	for bp in m["barrels"]:
		_spawn_prop(bp, "barrel")
	for cp in m["crates"]:
		_spawn_prop(cp, "crate")
	if bake_nav:
		_build_nav()
	map_loaded.emit(id)


## Navmesh cho bot, bake từ collider tĩnh của map (tầng L_WORLD). Bệ cao hơn bước leo (0.5 m) không nằm
## trong navmesh nên bot không kẹt dưới chân tường; dốc thoải thì đi được. Thùng/cột là chướng ngại.
func _build_nav() -> void:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 40.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Global.L_WORLD
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, self)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	nav_region = NavigationRegion3D.new()
	nav_region.navigation_mesh = nm
	add_child(nav_region)
	NavigationServer3D.map_force_update(nav_region.get_navigation_map())


## Đường đi (điểm ngoặt) trên navmesh từ a tới b; rỗng nếu chưa có navmesh.
func nav_path(a: Vector3, b: Vector3) -> PackedVector3Array:
	if nav_region == null:
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(nav_region.get_navigation_map(), a, b, true)


func _spawn_prop(pos: Vector3, kind: String) -> void:
	var b: StaticBody3D = BreakableScript.new()
	b.kind = kind
	b.position = pos
	add_child(b)
	props.append(b)
	b.exploded.connect(func(p: Vector3, r: float): explosion.emit(p, r))
	b.broken.connect(func(p: Vector3, k: String): prop_broken.emit(p, k))


func _box(size: Vector3, pos: Vector3, role: String, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Global.L_WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees = rot_deg
	body.set_meta("surface", String(Global.SURFACES.get(role, "stone")))
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = Materials.make(role)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	body.add_child(mi)
	add_child(body)


## Vạch sáng mỏng ở chân 4 tường (chỉ hình ảnh, không va chạm) để nhìn ra biên đấu trường.
func _build_trim() -> void:
	var t: float = 0.15
	var specs: Array = [
		[Vector3(half.x * 2.0, t, t), Vector3(0.0, t * 0.5, -half.y)],
		[Vector3(half.x * 2.0, t, t), Vector3(0.0, t * 0.5, half.y)],
		[Vector3(t, t, half.y * 2.0), Vector3(half.x, t * 0.5, 0.0)],
		[Vector3(t, t, half.y * 2.0), Vector3(-half.x, t * 0.5, 0.0)],
	]
	for sp in specs:
		var bm := BoxMesh.new()
		bm.size = sp[0]
		bm.material = Materials.make("trim")
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.position = sp[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _spawn_dummy(pos: Vector3, color: Color) -> void:
	var d: StaticBody3D = DummyScript.new()
	d.color = color
	d.position = pos
	d.rotation.y = PI # quay mặt về phía điểm spawn
	add_child(d)
	dummies.append(d)


func _build_environment() -> void:
	var e: Dictionary = Global.ENV
	sun = DirectionalLight3D.new()
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
	world_env = env
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
	Global.quality_changed.connect(_on_quality_changed)
	_apply_quality()


func _apply_quality() -> void:
	Quality.apply(Global.quality, world_env, sun, get_viewport())


func _on_quality_changed(_level: int) -> void:
	_apply_quality()
