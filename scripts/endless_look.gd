extends RefCounted
## Diện mạo bản đồ Vô Tận (P1). CHỈ hình ảnh: không va chạm, không đổi bố cục / navmesh (đọc dữ liệu từ Maps.endless).
## - Mặt tiền toà nhà đổi sắc độ theo vị trí (vài tông trung tính, cùng bộ vật liệu "wall") để từ xa phân biệt từng khối.
## - Dải sáng mảnh ở mép nóc (nhận ra độ cao), dải mờ theo từng tầng lầu (cảm giác tỉ lệ), vòng sáng ở đỉnh cột.
## - 3 cột ăng-ten sáng trên nóc 3 toà cao nhất làm mốc định hướng trên bản đồ 300 m.
## - Vạch đứt giữa các phố (cảm giác tốc độ) và khung sáng quanh chỗ xuất phát (xanh lam) / cổng ra (xanh lá).
## Mọi dải sáng gộp vào vài MultiMesh (mỗi loại 1 draw call). Mọi con số chỉnh ở LOOK, không có menu / F4.

const Materials = preload("res://scripts/materials.gd")

const LOOK: Dictionary = {
	# Nhân với màu "wall" (Global.PALETTE) -> 5 tông: thép, bê tông ấm, xanh lạnh, đá phiến tối, cát sáng.
	"facade_tints": [Color(1.0, 1.0, 1.0), Color(1.2, 1.1, 0.95), Color(0.85, 1.05, 1.2), Color(0.7, 0.72, 0.8), Color(1.3, 1.22, 1.08)],
	"roof_color": Color(0.25, 0.85, 1.0), "roof_energy": 2.4, "roof_thick": 0.35,
	"band_color": Color(0.25, 0.85, 1.0), "band_energy": 0.7, "band_thick": 0.12, "band_spacing": 7.0, "band_top_gap": 1.5,
	"ring_color": Color(1.0, 0.75, 0.3), "ring_energy": 2.0, "ring_thick": 0.2, "ring_drop": 0.6,
	"mast_count": 3, "mast_height": 16.0, "mast_size": 0.5, "mast_color": Color(1.0, 0.95, 0.85), "mast_energy": 3.2,
	"dash_len": 5.0, "dash_gap": 5.0, "dash_w": 0.35, "dash_clear": 9.0, "dash_y": 0.03, "dash_color": Color(0.85, 0.9, 1.0), "dash_energy": 0.8,
	"pad_half": 12.0, "pad_thick": 0.5, "pad_start_color": Color(0.25, 0.85, 1.0), "pad_exit_color": Color(0.2, 1.0, 0.5), "pad_energy": 2.0,
}

## Chủ đề theo tầng (P2). Khoá thiếu = giữ nguyên Global.ENV. *_mul nhân lên giá trị gốc. accent = màu viền nóc / dải tầng lầu.
## Đêm vẫn đủ sáng: sun_energy và ambient_energy không bao giờ thấp hơn MIN_SUN / MIN_AMBIENT.
const MIN_SUN: float = 0.45
const MIN_AMBIENT: float = 0.5
const THEMES: Array = [
	{"name": "ngày", "accent": Color(0.25, 0.85, 1.0)},
	{"name": "bình minh", "sun_rotation_deg": Vector3(-14.0, 70.0, 0.0), "sun_color": Color(1.0, 0.68, 0.42), "sun_energy_mul": 1.0,
		"sky_top": Color(0.35, 0.42, 0.68), "sky_horizon": Color(0.98, 0.7, 0.52), "fog_color": Color(0.95, 0.72, 0.58), "fog_density_mul": 1.4,
		"accent": Color(1.0, 0.7, 0.3)},
	{"name": "hoàng hôn", "sun_rotation_deg": Vector3(-9.0, -60.0, 0.0), "sun_color": Color(1.0, 0.45, 0.3), "sun_energy_mul": 0.9,
		"sky_top": Color(0.28, 0.2, 0.45), "sky_horizon": Color(0.95, 0.42, 0.32), "fog_color": Color(0.85, 0.45, 0.4), "fog_density_mul": 1.3,
		"ambient_energy_mul": 0.9, "accent": Color(1.0, 0.45, 0.35)},
	{"name": "đêm", "sun_rotation_deg": Vector3(-60.0, 20.0, 0.0), "sun_color": Color(0.55, 0.65, 1.0), "sun_energy_mul": 0.4,
		"sky_top": Color(0.04, 0.06, 0.16), "sky_horizon": Color(0.16, 0.22, 0.4), "fog_color": Color(0.1, 0.14, 0.26), "fog_density_mul": 1.2,
		"ambient_energy_mul": 0.7, "accent": Color(0.4, 1.0, 0.9)},
	{"name": "mưa bụi", "sun_color": Color(0.85, 0.9, 1.0), "sun_energy_mul": 0.6,
		"sky_top": Color(0.35, 0.4, 0.46), "sky_horizon": Color(0.6, 0.64, 0.68), "fog_color": Color(0.55, 0.6, 0.65), "fog_density_mul": 2.4,
		"accent": Color(0.7, 0.9, 1.0)},
	{"name": "sương tím", "sun_rotation_deg": Vector3(-35.0, 140.0, 0.0), "sun_color": Color(0.9, 0.75, 1.0), "sun_energy_mul": 0.8,
		"sky_top": Color(0.3, 0.22, 0.5), "sky_horizon": Color(0.7, 0.58, 0.85), "fog_color": Color(0.6, 0.5, 0.75), "fog_density_mul": 1.8,
		"accent": Color(0.85, 0.55, 1.0)},
]
const THEME_BLEND_SEC: float = 1.2

static var _facades: Dictionary = {}


## Chủ đề của tầng n (tầng 1 = [0], lặp vòng).
static func theme_index(floor_n: int) -> int:
	return posmod(floor_n - 1, THEMES.size())


## Giá trị môi trường đích của chủ đề: gốc Global.ENV, đè bằng khoá của chủ đề, có sàn độ sáng.
static func theme_env(idx: int) -> Dictionary:
	var base: Dictionary = Global.ENV
	var t: Dictionary = THEMES[posmod(idx, THEMES.size())]
	var out: Dictionary = {}
	for k in ["sun_rotation_deg", "sun_color", "sky_top", "sky_horizon", "fog_color"]:
		out[k] = t.get(k, base[k])
	out["sun_energy"] = maxf(MIN_SUN, float(base["sun_energy"]) * float(t.get("sun_energy_mul", 1.0)))
	out["ambient_energy"] = maxf(MIN_AMBIENT, float(base["ambient_energy"]) * float(t.get("ambient_energy_mul", 1.0)))
	out["fog_density"] = float(base["fog_density"]) * float(t.get("fog_density_mul", 1.0))
	return out


static func theme_accent(idx: int) -> Color:
	return THEMES[posmod(idx, THEMES.size())].get("accent", LOOK["roof_color"])


## Giá trị hiện tại của môi trường (để chuyển mượt từ đó).
static func read_env(sun: DirectionalLight3D, env: Environment) -> Dictionary:
	var sm: ProceduralSkyMaterial = env.sky.sky_material
	return {"sun_rotation_deg": sun.rotation_degrees, "sun_color": sun.light_color, "sun_energy": sun.light_energy,
		"sky_top": sm.sky_top_color, "sky_horizon": sm.sky_horizon_color, "fog_color": env.fog_light_color,
		"fog_density": env.fog_density, "ambient_energy": env.ambient_light_energy}


## Đặt môi trường = lerp(from, to, k). k = 1 là đích.
static func blend_env(sun: DirectionalLight3D, env: Environment, from: Dictionary, to: Dictionary, k: float) -> void:
	var sm: ProceduralSkyMaterial = env.sky.sky_material
	sun.rotation_degrees = (from["sun_rotation_deg"] as Vector3).lerp(to["sun_rotation_deg"], k)
	sun.light_color = (from["sun_color"] as Color).lerp(to["sun_color"], k)
	sun.light_energy = lerpf(float(from["sun_energy"]), float(to["sun_energy"]), k)
	sm.sky_top_color = (from["sky_top"] as Color).lerp(to["sky_top"], k)
	sm.sky_horizon_color = (from["sky_horizon"] as Color).lerp(to["sky_horizon"], k)
	env.fog_light_color = (from["fog_color"] as Color).lerp(to["fog_color"], k)
	env.fog_density = lerpf(float(from["fog_density"]), float(to["fog_density"]), k)
	env.ambient_light_energy = lerpf(float(from["ambient_energy"]), float(to["ambient_energy"]), k)


## Tông mặt tiền theo vị trí (xác định, không dùng số ngẫu nhiên nên không đổi bố cục của Maps).
static func facade_variant(pos: Vector3) -> int:
	var n: int = (LOOK["facade_tints"] as Array).size()
	return posmod(roundi(pos.x * 0.37) * 31 + roundi(pos.z * 0.53) * 17, n)


## Vật liệu mặt tiền: bản sao của "wall" (cùng họa tiết lưới triplanar) nhân thêm tông màu. Dùng chung theo tông.
static func facade(variant: int) -> StandardMaterial3D:
	if _facades.has(variant):
		return _facades[variant]
	var m: StandardMaterial3D = Materials.make("wall").duplicate()
	var t: Color = (LOOK["facade_tints"] as Array)[variant]
	var c: Color = Global.PALETTE["wall"]
	m.albedo_color = Color(clampf(c.r * t.r, 0.0, 1.0), clampf(c.g * t.g, 0.0, 1.0), clampf(c.b * t.b, 0.0, 1.0), 1.0)
	_facades[variant] = m
	return m


## Đổi vật liệu của khối vừa dựng (chỉ toà nhà "wall"; cột / bệ móc giữ màu vai trò gốc để còn đọc được chức năng).
static func style_box(body: Node, bx: Dictionary) -> void:
	if String(bx["role"]) != "wall":
		return
	for ch in body.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is BoxMesh:
			((ch as MeshInstance3D).mesh as BoxMesh).material = facade(facade_variant(bx["pos"]))


## Dựng các lớp trang trí cho một bản đồ Vô Tận (dữ liệu của Maps.endless). Trả về mảng MultiMeshInstance3D để Arena thêm vào cảnh.
static func dress(m: Dictionary, theme: int = 0) -> Array:
	var E: Dictionary = Global.ENDLESS
	var half: Vector2 = m["half"]
	var cell: float = float(E["cell"])
	var n: int = int(E["grid"])
	var roofs: Array = []
	var bands: Array = []
	var rings: Array = []
	var masts: Array = []
	var dashes: Array = []
	var pads_start: Array = []
	var pads_exit: Array = []
	var towers: Array = []   # [chiều cao, tâm, kích thước] của các toà nhà
	var rt: float = float(LOOK["roof_thick"])
	var bt: float = float(LOOK["band_thick"])
	var gt: float = float(LOOK["ring_thick"])
	for bx in m["boxes"]:
		var p: Vector3 = bx["pos"]
		var s: Vector3 = bx["size"]
		match String(bx["role"]):
			"wall":
				towers.append([s.y, p, s])
				var top: float = p.y + s.y * 0.5
				_frame(roofs, p.x, p.z, s.x, s.z, top - rt * 0.5, rt)
				var y: float = float(LOOK["band_spacing"])
				while y < s.y - float(LOOK["band_top_gap"]):
					_frame(bands, p.x, p.z, s.x, s.z, p.y - s.y * 0.5 + y, bt)
					y += float(LOOK["band_spacing"])
			"pillar":
				var top_p: float = p.y + s.y * 0.5
				_frame(rings, p.x, p.z, s.x, s.z, top_p - float(LOOK["ring_drop"]), gt)
	towers.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	var ms: float = float(LOOK["mast_size"])
	var mh: float = float(LOOK["mast_height"])
	for i in mini(int(LOOK["mast_count"]), towers.size()):
		var tp: Vector3 = towers[i][1]
		var ts: Vector3 = towers[i][2]
		# lệch về một góc nóc: tránh bệ móc 4x4 ở tâm nóc những toà cao
		var cx: float = tp.x + ts.x * 0.5 - 1.5
		var cz: float = tp.z + ts.z * 0.5 - 1.5
		masts.append(_xf(Vector3(ms, mh, ms), Vector3(cx, tp.y + ts.y * 0.5 + mh * 0.5, cz)))
	# Vạch đứt giữa các phố (đường biên ô), bỏ chỗ giao nhau.
	var dl: float = float(LOOK["dash_len"])
	var step: float = dl + float(LOOK["dash_gap"])
	var dw: float = float(LOOK["dash_w"])
	var dy: float = float(LOOK["dash_y"])
	var clear: float = float(LOOK["dash_clear"])
	for k in range(1, n):
		var line: float = -half.x + cell * k
		var t: float = -half.x + dl
		while t < half.x - dl:
			var near_cross: bool = false
			for j in range(1, n):
				if absf(t - (-half.x + cell * j)) < clear:
					near_cross = true
					break
			if not near_cross:
				dashes.append(_xf(Vector3(dw, 0.04, dl), Vector3(line, dy, t)))
				dashes.append(_xf(Vector3(dl, 0.04, dw), Vector3(t, dy, line)))
			t += step
	var ph: float = float(LOOK["pad_half"])
	var pt: float = float(LOOK["pad_thick"])
	var sp: Vector3 = m["spawn"]
	var ex: Vector3 = m.get("exit", Vector3.ZERO)
	_frame(pads_start, sp.x, sp.z, ph * 2.0, ph * 2.0, dy, pt)
	_frame(pads_exit, ex.x, ex.z, ph * 2.0, ph * 2.0, dy, pt)
	var out: Array = []
	var accent: Color = theme_accent(theme)
	for spec in [
		[roofs, accent, LOOK["roof_energy"]],
		[bands, accent, LOOK["band_energy"]],
		[rings, LOOK["ring_color"], LOOK["ring_energy"]],
		[masts, LOOK["mast_color"], LOOK["mast_energy"]],
		[dashes, LOOK["dash_color"], LOOK["dash_energy"]],
		[pads_start, LOOK["pad_start_color"], LOOK["pad_energy"]],
		[pads_exit, LOOK["pad_exit_color"], LOOK["pad_energy"]],
	]:
		var inst: MultiMeshInstance3D = _batch(spec[0], spec[1], float(spec[2]))
		if inst != null:
			out.append(inst)
	return out


static func _xf(size: Vector3, pos: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), pos)


## 4 thanh viền hình chữ nhật (w x d) tại độ cao y, dày t, tâm (cx, cz).
static func _frame(into: Array, cx: float, cz: float, w: float, d: float, y: float, t: float) -> void:
	for sz in [-1.0, 1.0]:
		into.append(_xf(Vector3(w + t, t, t), Vector3(cx, y, cz + sz * d * 0.5)))
	for sx in [-1.0, 1.0]:
		into.append(_xf(Vector3(t, t, d + t), Vector3(cx + sx * w * 0.5, y, cz)))


## Một MultiMesh các hộp đơn vị (đã co giãn theo từng thể hiện), phát sáng không đổ bóng, không va chạm. Rỗng thì trả null.
static func _batch(xf: Array, color: Color, energy: float) -> MultiMeshInstance3D:
	if xf.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	bm.material = mat
	mm.mesh = bm
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
