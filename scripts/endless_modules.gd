extends RefCounted
## Module bản đồ Vô Tận low poly (M45). CHỈ hình ảnh: va chạm / navmesh vẫn là hộp của Maps.endless (không đổi).
## Mỗi hộp "wall" (toà nhà), "pillar", "platform" (bệ / bức che) được phủ một mesh .glb nằm trong khối đơn vị, co giãn đúng bằng
## kích thước hộp va chạm. Hộp gốc chỉ ẩn đi (vẫn còn trong cây node). Thiếu file / tắt LOWPOLY -> giữ nguyên hộp cũ.
## Vật liệu trong .glb đặt tên theo vai trò (mod_wall, mod_trim, mod_glow) và được tô lúc chạy; mesh dùng chung giữa các thể hiện.

const EndlessLook = preload("res://scripts/endless_look.gd")
const Materials = preload("res://scripts/materials.gd")

const BUILDING_KINDS: Array = ["building_block", "building_fins", "building_slab"]

static var _scenes: Dictionary = {}
static var _mats: Dictionary = {}


## Loại module cho một hộp ("" = không có).
static func kind_for(bx: Dictionary) -> String:
	var s: Vector3 = bx["size"]
	match String(bx["role"]):
		"wall":
			return BUILDING_KINDS[posmod(roundi(float((bx["pos"] as Vector3).x) * 0.61) + roundi(float((bx["pos"] as Vector3).z) * 0.43), BUILDING_KINDS.size())]
		"pillar":
			return "pillar"
		"platform":
			return "stage" if s.y >= 1.8 and s.x >= 10.0 else "cover"
	return ""


static func path_of(kind: String) -> String:
	return String(Global.LOWPOLY["map"].get(kind, ""))


static func has_asset(kind: String) -> bool:
	if not bool(Global.LOWPOLY["enabled"]) or kind == "":
		return false
	var p: String = path_of(kind)
	return p != "" and ResourceLoader.exists(p)


static func _scene(kind: String) -> PackedScene:
	if not _scenes.has(kind):
		_scenes[kind] = load(path_of(kind))
	return _scenes[kind]


## Vật liệu theo (loại, vai trò mod_*, biến thể, chủ đề). Thân toà nhà dùng mặt tiền của EndlessLook (cùng tông / họa tiết lưới).
static func _material(kind: String, role: String, variant: int, theme: int) -> Material:
	var key: String = "%s|%s|%d|%d" % [kind.substr(0, 5), role, variant, theme]
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D
	match role:
		"mod_wall":
			if kind.begins_with("building"):
				m = EndlessLook.facade(variant)
			elif kind == "pillar":
				m = Materials.make("pillar")
			else:
				m = Materials.make("platform")
		"mod_trim":
			m = StandardMaterial3D.new()
			var c: Color = Global.PALETTE["wall"] * 0.42
			m.albedo_color = Color(c.r, c.g, c.b, 1.0)
			m.metallic = 0.5
			m.roughness = 0.55
		_:
			m = StandardMaterial3D.new()
			var a: Color = EndlessLook.theme_accent(theme)
			m.albedo_color = a * 0.5
			m.emission_enabled = true
			m.emission = a
			m.emission_energy_multiplier = EndlessLook.theme_window_energy(theme)
	_mats[key] = m
	return m


## Phủ module lên thân vừa dựng. Trả về true nếu đã dùng module (hộp cũ bị ẩn).
static func apply(body: Node, bx: Dictionary, theme: int = 0) -> bool:
	var kind: String = kind_for(bx)
	if not has_asset(kind):
		return false
	var root: Node3D = _scene(kind).instantiate()
	root.name = "Module"
	root.scale = bx["size"]
	var variant: int = EndlessLook.facade_variant(bx["pos"])
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		for i in inst.mesh.get_surface_count():
			var role: String = String(inst.mesh.surface_get_material(i).resource_name)
			inst.set_surface_override_material(i, _material(kind, role, variant, theme))
	for ch in body.get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).visible = false
	body.add_child(root)
	return true


## Số tam giác của một cây node (đếm theo mesh).
static func tri_count(n: Node) -> int:
	var t: int = 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh == null or not inst.visible:
			continue
		for s in inst.mesh.get_surface_count():
			var arr: Array = inst.mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx != null and idx.size() > 0 else arr[Mesh.ARRAY_VERTEX].size()) / 3
	return t
