extends RefCounted
## Dữ liệu bản đồ duy nhất của game (M41): lưới Vô Tận (chỉ là dữ liệu, không tạo node nên test được không cần cảnh).
## Mỗi map: half (nửa kích thước sàn x,z), wall_h, boxes [{size,pos,role,rot}], spawn, bot_spawns, exit, void_y.
## Cùng số tầng thì cùng bản đồ (hạt giống theo tầng). Tập luyện dùng đúng một tầng cố định (`Global.TRAINING["floor"]`).


static func _b(size: Vector3, pos: Vector3, role: String, rot := Vector3.ZERO) -> Dictionary:
	return {"size": size, "pos": pos, "role": role, "rot": rot}


## Hình chữ nhật (x0, z0, x1, z1) của một hộp (bỏ qua xoay: đủ để tránh chồng lấn).
static func _rect(b: Dictionary) -> Rect2:
	var sz: Vector3 = b["size"]
	var p: Vector3 = b["pos"]
	return Rect2(p.x - sz.x * 0.5, p.z - sz.z * 0.5, sz.x, sz.z)


static func _overlaps(rects: Array, rc: Rect2, margin: float) -> bool:
	for r in rects:
		if (r as Rect2).grow(margin).intersects(rc):
			return true
	return false


# ------------------------------------------------------------------ Vô Tận (M34)

## Địa hình thêm (P3): "sân khấu" = bệ thấp + 2 dốc lên + 2 bức che thấp, đặt vào các ô trống. Cấp từ một bộ số ngẫu nhiên RIÊNG
## (hạt giống lệch) và chỉ dựng SAU toà nhà / cột: bố cục cũ, chỗ xuất phát và cổng không đổi. Mọi khối nằm trong chỗ xây của ô.
const TERRAIN: Dictionary = {
	"seed_offset": 101, "stage_max": 3, "stage_half": 8.0, "stage_h": 2.0, "ramp_run": 8.0, "ramp_w": 7.0, "ramp_t": 0.4,
	"cover_len": 8.0, "cover_h": 1.4, "cover_t": 0.8, "cover_dist": 11.0,
}

## Bản đồ một tầng chế độ Vô Tận: lưới ô vuông, mỗi ô một mẫu ngẫu nhiên (hạt giống theo số tầng, cùng tầng cùng bản đồ).
## Công trình luôn lùi vào `inset` m trong ô nên phố giữa các ô rộng >= 2*inset: mọi ô thông nhau, không cần kiểm tra thêm.
## Xuất phát ở một góc (ô trống), cổng ra ở góc đối diện (ô trống). Ít vật thể: chỉ toà nhà và cột.
static func endless(floor_n: int) -> Dictionary:
	var E: Dictionary = Global.ENDLESS
	var rng := RandomNumberGenerator.new()
	rng.seed = 3400 + floor_n * 7919
	var n: int = int(E["grid"])
	var cell: float = float(E["cell"])
	var half: float = n * cell * 0.5
	var usable: float = cell * 0.5 - float(E["inset"])   # nửa bề rộng chỗ xây trong ô
	var boxes: Array = []
	var empties: Array = []   # tâm các ô trống (P3 đặt sân khấu vào đây); không dùng thêm số ngẫu nhiên
	var corner: int = rng.randi() % 4
	var start_ij := Vector2i(0 if corner % 2 == 0 else n - 1, 0 if corner < 2 else n - 1)
	var exit_ij := Vector2i(n - 1 - start_ij.x, n - 1 - start_ij.y)
	for i in n:
		for j in n:
			var ij := Vector2i(i, j)
			var c := Vector3(-half + cell * (i + 0.5), 0.0, -half + cell * (j + 0.5))
			var roll: float = rng.randf()
			if ij == start_ij or ij == exit_ij:
				continue
			if roll < 0.35:
				_endless_building(boxes, rng, c, c + Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0)), rng.randf_range(14.0, 2.0 * usable - 2.0), rng.randf_range(14.0, 2.0 * usable - 2.0), usable)
			elif roll < 0.60:
				var along_x: bool = rng.randf() < 0.5
				for s in [-1.0, 1.0]:
					var off := Vector3(9.0 * s, 0.0, rng.randf_range(-3.0, 3.0)) if along_x else Vector3(rng.randf_range(-3.0, 3.0), 0.0, 9.0 * s)
					_endless_building(boxes, rng, c, c + off, rng.randf_range(10.0, 14.0), rng.randf_range(10.0, 14.0), usable)
			elif roll < 0.80:
				var placed: Array = []
				for k in rng.randi_range(3, 5):
					var h: float = rng.randf_range(10.0, 20.0)
					var pos := Vector3(c.x + rng.randf_range(-usable + 2.0, usable - 2.0), h * 0.5, c.z + rng.randf_range(-usable + 2.0, usable - 2.0))
					var pb: Dictionary = _b(Vector3(2.5, h, 2.5), pos, "pillar")
					if _overlaps(placed, _rect(pb), 5.0):
						continue
					placed.append(_rect(pb))
					boxes.append(pb)
					if rng.randf() < 0.5:
						boxes.append(_b(Vector3(4.0, 0.5, 4.0), Vector3(pos.x, h + 0.25, pos.z), "grapple"))
			else:
				empties.append(c)
	_endless_stages(boxes, floor_n, empties)
	var start_c := Vector3(-half + cell * (start_ij.x + 0.5), 0.1, -half + cell * (start_ij.y + 0.5))
	var exit_c := Vector3(-half + cell * (exit_ij.x + 0.5), 0.0, -half + cell * (exit_ij.y + 0.5))
	# Điểm sinh bot: dọc các phố (đường biên ô), cách nhau 25 m; bỏ những điểm sát chỗ xuất phát.
	var seen: Dictionary = {}
	var spawns: Array = []
	for k in range(1, n):
		var line: float = -half + cell * k
		var t: float = -half + cell * 0.5
		while t <= half - cell * 0.5 + 0.1:
			for p in [Vector3(line, 0.1, t), Vector3(t, 0.1, line)]:
				var key: Vector2i = Vector2i(roundi(p.x), roundi(p.z))
				if not seen.has(key) and Vector2(p.x - start_c.x, p.z - start_c.z).length() >= float(E["start_clear"]):
					seen[key] = true
					spawns.append(p)
			t += cell * 0.5
	return {
		"name": "Vô Tận - tầng %d" % floor_n, "desc": "Lưới %dx%d ô, mỗi tầng một bản đồ" % [n, n],
		"half": Vector2(half, half), "wall_h": 40.0, "void_y": -40.0,
		"boxes": boxes, "spawn": start_c, "bot_spawns": spawns,
		"dummies": [], "barrels": [], "crates": [],
		"big": true, "titans": true, "spawn_band": E["band"], "compass": true, "nav_cell": float(E["nav_cell"]),
		"exit": exit_c, "endless": true, "floor": floor_n,
	}


## Sân khấu (P3) vào tối đa `stage_max` ô trống, chọn xác định theo tầng. Dốc theo trục x, bức che theo trục z.
static func _endless_stages(boxes: Array, floor_n: int, empties: Array) -> void:
	var T: Dictionary = TERRAIN
	var rng := RandomNumberGenerator.new()
	rng.seed = 3400 + floor_n * 7919 + int(T["seed_offset"])
	var pool: Array = empties.duplicate()
	var sh: float = float(T["stage_half"])
	var h: float = float(T["stage_h"])
	var run: float = float(T["ramp_run"])
	var th: float = float(T["ramp_t"])
	var ang: float = atan2(h, run)
	var rlen: float = sqrt(run * run + h * h)
	for k in mini(int(T["stage_max"]), pool.size()):
		var idx: int = rng.randi() % pool.size()
		var c: Vector3 = pool[idx]
		pool.remove_at(idx)
		boxes.append(_b(Vector3(sh * 2.0, h, sh * 2.0), Vector3(c.x, h * 0.5, c.z), "platform"))
		for sx in [-1.0, 1.0]:
			# bề mặt dốc đi từ (mép bệ, cao h) xuống (cách mép `run`, cao 0); hộp dày th lệch xuống dưới bề mặt
			var rz: float = rad_to_deg(ang) * sx   # +x thấp xuống: xoay z âm; -x: dương
			var rot_rad: float = deg_to_rad(-rz)
			var n := Vector3(-sin(rot_rad), cos(rot_rad), 0.0)   # pháp tuyến mặt trên sau khi xoay quanh z
			var mid := Vector3(c.x + sx * (sh + run * 0.5), h * 0.5, c.z) - n * (th * 0.5)
			boxes.append(_b(Vector3(rlen, th, float(T["ramp_w"])), mid, "ramp", Vector3(0.0, 0.0, -rz)))
		var cl: float = float(T["cover_len"])
		var ch: float = float(T["cover_h"])
		for sz in [-1.0, 1.0]:
			boxes.append(_b(Vector3(cl, ch, float(T["cover_t"])), Vector3(c.x, ch * 0.5, c.z + sz * float(T["cover_dist"])), "platform"))


## Một toà nhà tại `c` (tâm yêu cầu) trong ô có tâm `cc`: tâm bị kẹp để mép toà nhà không vượt `usable` (nửa bề rộng chỗ xây).
static func _endless_building(boxes: Array, rng: RandomNumberGenerator, cc: Vector3, c: Vector3, w: float, d: float, usable: float) -> void:
	var E: Dictionary = Global.ENDLESS
	var hh: float = rng.randf_range(float(E["building_h_min"]), float(E["building_h_max"]))
	var mx: float = maxf(usable - w * 0.5, 0.0)
	var mz: float = maxf(usable - d * 0.5, 0.0)
	var x: float = cc.x + clampf(c.x - cc.x, -mx, mx)
	var z: float = cc.z + clampf(c.z - cc.z, -mz, mz)
	boxes.append(_b(Vector3(w, hh, d), Vector3(x, hh * 0.5, z), "wall"))
	if hh > 20.0:
		boxes.append(_b(Vector3(4.0, 0.5, 4.0), Vector3(x, hh + 0.25, z), "grapple"))
