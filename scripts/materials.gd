extends RefCounted
## Tạo vật liệu theo vai trò (xem Global.PALETTE / Global.MATERIAL_PARAMS). Họa tiết lưới sinh bằng
## code, dùng triplanar nên không bị giãn dù khối to nhỏ khác nhau. Không dùng asset ngoài.

static var _grid_tex: ImageTexture
static var _cache: Dictionary = {}


static func _grid_texture() -> ImageTexture:
	if _grid_tex == null:
		var n: int = 64
		var img := Image.create(n, n, false, Image.FORMAT_RGB8)
		for y in n:
			for x in n:
				var line: bool = x < 2 or y < 2
				var v: float = 0.78 if line else 1.0
				img.set_pixel(x, y, Color(v, v, v))
		img.generate_mipmaps()
		_grid_tex = ImageTexture.create_from_image(img)
	return _grid_tex


## Vai trò hợp lệ: các khóa của Global.PALETTE.
static func make(role: String) -> StandardMaterial3D:
	if _cache.has(role):
		return _cache[role]
	var color: Color = Global.PALETTE[role]
	var params: Dictionary = Global.MATERIAL_PARAMS[role]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = params["metallic"]
	m.roughness = params["roughness"]
	if role != "trim":
		m.albedo_texture = _grid_texture()
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / float(params["tile"])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var e: float = params["emission"]
	if e > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = e
	_cache[role] = m
	return m
