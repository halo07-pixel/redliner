extends Node3D
## Đấu trường thử nghiệm dựng bằng code: sàn, 4 tường, cột đỏ, vài bục cao để tập nhảy,
## ánh sáng + bầu trời, và 1 hình nhân làm bia. Các cột/tường cao sẽ là chỗ wallrun/grapple
## ở mốc sau.

const DummyScript = preload("res://scripts/enemy_dummy.gd")
const Materials = preload("res://scripts/materials.gd")
const Quality = preload("res://scripts/quality.gd")

const Maps = preload("res://scripts/maps.gd")
const BreakableScript = preload("res://scripts/breakable.gd")
const EndlessLook = preload("res://scripts/endless_look.gd")

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
## Map lớn: vòng sinh bot quanh người chơi (m), có la bàn kẻ địch không, ô navmesh (m), thời gian bake (ms).
var spawn_band: Vector2 = Vector2.ZERO
var compass: bool = false
var nav_cell: float = 0.25
var nav_bake_ms: int = 0
## Map có Titan: navmesh riêng cho thân hình lớn (bán kính lớn), nằm trên một map điều hướng riêng.
var titans: bool = false
var titan_nav_map: RID = RID()
var _titan_region: RID = RID()


## Vô Tận: tầng hiện tại (map_id "endless") và vị trí cổng ra của tầng.
var floor_n: int = 1
var exit_point: Vector3 = Vector3.ZERO
var _map_nodes: Array = []   # mọi node thuộc bản đồ (để dựng lại sang tầng khác)


func _ready() -> void:
	if map_id == "":
		map_id = "endless" if Global.game_mode == "endless" else Global.selected_map
	_build_environment()
	_build_map(map_id)
	if map_id == "endless":
		_apply_theme(false)


## Dựng đấu trường từ dữ liệu Maps (sàn, 4 tường, các khối, bia tập). Phát map_loaded khi xong.
func _add_map_node(n: Node) -> void:
	add_child(n)
	_map_nodes.append(n)


## Vô Tận: xoá bản đồ cũ, dựng bản đồ của tầng `n`. Môi trường (trời, ánh sáng) giữ nguyên. Phát lại map_loaded.
func load_floor(n: int) -> void:
	floor_n = n
	# Tắt vùng điều hướng cũ NGAY (queue_free chỉ xoá cuối khung): nếu không, khung đầu của tầng mới vẫn trả đường đi của tầng cũ.
	if nav_region != null and is_instance_valid(nav_region):
		nav_region.enabled = false
	for node in _map_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_map_nodes.clear()
	props.clear()
	dummies.clear()
	nav_region = null
	_nav_probe_ok = false
	_free_titan_nav()
	_build_map("endless")
	_apply_theme(true)


var _theme_tween: Tween


## Vô Tận (P2): đưa trời / nắng / sương sang chủ đề của tầng hiện tại. smooth = chuyển mượt (không khi giảm hiệu ứng).
func _apply_theme(smooth: bool) -> void:
	if world_env == null or sun == null:
		return
	var to: Dictionary = EndlessLook.theme_env(EndlessLook.theme_index(floor_n))
	to["fog_density"] = float(to["fog_density"]) * (0.6 if spawn_band != Vector2.ZERO else 1.0)   # như _build_environment
	if _theme_tween != null and _theme_tween.is_valid():
		_theme_tween.kill()
	if not smooth or Global.reduced_fx or not is_inside_tree():
		EndlessLook.blend_env(sun, world_env, to, to, 1.0)
		return
	var from: Dictionary = EndlessLook.read_env(sun, world_env)
	_theme_tween = create_tween()
	_theme_tween.tween_method(func(k: float) -> void: EndlessLook.blend_env(sun, world_env, from, to, k), 0.0, 1.0, EndlessLook.THEME_BLEND_SEC)


func _build_map(id: String) -> void:
	var m: Dictionary = Maps.endless(floor_n) if id == "endless" else Maps.get_map(id)
	map_id = id
	exit_point = m.get("exit", Vector3.ZERO)
	half = m["half"]
	wall_h = float(m["wall_h"])
	void_y = float(m["void_y"])
	spawn_point = m["spawn"]
	bot_spawns = m["bot_spawns"]
	spawn_band = m.get("spawn_band", Vector2.ZERO)
	compass = bool(m.get("compass", false))
	nav_cell = float(m.get("nav_cell", 0.25))
	titans = bool(m.get("titans", false))
	_box(Vector3(half.x * 2.0, 1.0, half.y * 2.0), Vector3(0.0, -0.5, 0.0), "floor")
	_box(Vector3(half.x * 2.0, wall_h, 1.0), Vector3(0.0, wall_h * 0.5, -half.y - 0.5), "wall")
	_box(Vector3(half.x * 2.0, wall_h, 1.0), Vector3(0.0, wall_h * 0.5, half.y + 0.5), "wall")
	_box(Vector3(1.0, wall_h, half.y * 2.0), Vector3(half.x + 0.5, wall_h * 0.5, 0.0), "wall")
	_box(Vector3(1.0, wall_h, half.y * 2.0), Vector3(-half.x - 0.5, wall_h * 0.5, 0.0), "wall")
	for bx in m["boxes"]:
		var body: StaticBody3D = _box(bx["size"], bx["pos"], bx["role"], bx["rot"])
		if id == "endless":
			EndlessLook.style_box(body, bx)
	if id == "endless":
		for deco in EndlessLook.dress(m, EndlessLook.theme_index(floor_n)):   # chỉ hình ảnh, không va chạm
			_add_map_node(deco)
	_build_trim()
	for dp in m["dummies"]:
		_spawn_dummy(dp, Color(0.85, 0.2, 0.2))
	for bp in m["barrels"]:
		_spawn_prop(bp, "barrel")
	for cp in m["crates"]:
		_spawn_prop(cp, "crate")
	if bake_nav:
		_build_nav()
		if titans:
			_build_titan_nav()
	map_loaded.emit(id)


## Navmesh cho bot, bake từ collider tĩnh của map (tầng L_WORLD). Bệ cao hơn bước leo (0.5 m) không nằm
## trong navmesh nên bot không kẹt dưới chân tường; dốc thoải thì đi được. Thùng/cột là chướng ngại.
func _build_nav() -> void:
	var nm := NavigationMesh.new()
	nm.cell_size = nav_cell
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 40.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Global.L_WORLD
	var t0: int = Time.get_ticks_msec()
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, self)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	nav_bake_ms = Time.get_ticks_msec() - t0
	nav_region = NavigationRegion3D.new()
	nav_region.navigation_mesh = nm
	_add_map_node(nav_region)
	NavigationServer3D.map_force_update(nav_region.get_navigation_map())


## Navmesh Titan: bake với bán kính/chiều cao lớn, đặt trên map điều hướng riêng (bot thường vẫn dùng navmesh cũ).
func _build_titan_nav() -> void:
	var T: Dictionary = Global.TITAN
	var nm := NavigationMesh.new()
	nm.cell_size = 0.5
	nm.agent_radius = float(T["agent_radius"])
	nm.agent_height = float(T["body_height"]) + 1.0
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 35.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Global.L_WORLD
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, self)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	titan_nav_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(titan_nav_map, true)
	NavigationServer3D.map_set_cell_size(titan_nav_map, 0.5)
	_titan_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_titan_region, titan_nav_map)
	NavigationServer3D.region_set_navigation_mesh(_titan_region, nm)
	NavigationServer3D.map_force_update(titan_nav_map)


func _exit_tree() -> void:
	_free_titan_nav()


func _free_titan_nav() -> void:
	if _titan_region.is_valid():
		NavigationServer3D.free_rid(_titan_region)
	if titan_nav_map.is_valid():
		NavigationServer3D.free_rid(titan_nav_map)
	_titan_region = RID()
	titan_nav_map = RID()


var _nav_probe_ok: bool = false


## Navmesh của map hiện tại đã đồng bộ vào máy chủ điều hướng chưa. Máy chủ gộp vùng mới không đồng thời (đo: 0 tới >10 khung),
## và trong lúc chờ nó trả đường đi sai (của tầng cũ hoặc cụt giữa chừng). Vô Tận: chỉ coi là sẵn sàng khi đường từ chỗ xuất phát tới
## cổng (luôn thông, do bộ sinh bảo đảm) thật sự tới được cổng; kết quả đạt thì nhớ tới lần dựng map kế. Map khác: có vùng là dùng.
func nav_ready() -> bool:
	if nav_region == null or not is_instance_valid(nav_region):
		return false
	if map_id != "endless" or _nav_probe_ok:
		return true
	var p: PackedVector3Array = NavigationServer3D.map_get_path(nav_region.get_navigation_map(), spawn_point, exit_point, true)
	_nav_probe_ok = p.size() >= 2 and p[p.size() - 1].distance_to(exit_point) < 4.0
	return _nav_probe_ok


## Đường đi (điểm ngoặt) trên navmesh từ a tới b; rỗng nếu chưa có navmesh hoặc nó chưa đồng bộ (bot dùng đường thẳng / lách tường).
func nav_path(a: Vector3, b: Vector3) -> PackedVector3Array:
	if not nav_ready():
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(nav_region.get_navigation_map(), a, b, true)


func _spawn_prop(pos: Vector3, kind: String) -> void:
	var b: StaticBody3D = BreakableScript.new()
	b.kind = kind
	b.position = pos
	_add_map_node(b)
	props.append(b)
	b.exploded.connect(func(p: Vector3, r: float): explosion.emit(p, r))
	b.broken.connect(func(p: Vector3, k: String): prop_broken.emit(p, k))


func _box(size: Vector3, pos: Vector3, role: String, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
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
	_add_map_node(body)
	return body


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
		_add_map_node(mi)


func _spawn_dummy(pos: Vector3, color: Color) -> void:
	var d: StaticBody3D = DummyScript.new()
	d.color = color
	d.position = pos
	d.rotation.y = PI # quay mặt về phía điểm spawn
	_add_map_node(d)
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
	env.fog_density = e["fog_density"] * (0.6 if spawn_band != Vector2.ZERO else 1.0)
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
