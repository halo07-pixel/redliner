extends RefCounted
## Dữ liệu 3 đấu trường (chỉ là dữ liệu, không tạo node nên test được không cần cảnh).
## Mỗi map: half (nửa kích thước sàn x,z), wall_h, boxes [{size,pos,role,rot}], spawn, bot_spawns,
## dummies (bia tập), barrels/crates (vật phá được), void_y (rơi dưới mức này thì hồi sinh). Arena đọc dữ liệu và dựng.
## Quy tắc: lối đi chính của bot là mặt sàn phẳng. Map lớn (`district`) sinh bố cục bằng code với hạt giống cố định (cùng kết quả mỗi lần).

const IDS: Array = ["yard", "alley", "tower", "district"]


static func get_map(id: String) -> Dictionary:
	match id:
		"alley":
			return _alley()
		"tower":
			return _tower()
		"district":
			return _district()
		_:
			return _yard()


static func _b(size: Vector3, pos: Vector3, role: String, rot := Vector3.ZERO) -> Dictionary:
	return {"size": size, "pos": pos, "role": role, "rot": rot}


## Sân tập: đấu trường gốc (giữ nguyên bố cục từ M2).
static func _yard() -> Dictionary:
	var boxes: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			boxes.append(_b(Vector3(2.5, 10.0, 2.5), Vector3(14.0 * sx, 5.0, 14.0 * sz), "pillar"))
	boxes.append(_b(Vector3(8.0, 1.0, 8.0), Vector3(8.0, 0.5, 10.0), "platform"))
	boxes.append(_b(Vector3(6.0, 2.5, 6.0), Vector3(14.5, 1.25, 10.0), "platform"))
	boxes.append(_b(Vector3(1.0, 8.0, 30.0), Vector3(-22.0, 4.0, -5.0), "runwall"))
	boxes.append(_b(Vector3(6.0, 0.5, 6.0), Vector3(0.0, 8.0, -22.0), "grapple"))
	boxes.append(_b(Vector3(10.0, 1.0, 20.0), Vector3(22.0, 2.0, -10.0), "ramp", Vector3(20.0, 0.0, 0.0)))
	return {
		"name": "Sân tập", "desc": "Đấu trường gốc: cột, bục, dốc, tường chạy",
		"half": Vector2(30.0, 30.0), "wall_h": 12.0, "void_y": -30.0,
		"boxes": boxes,
		"spawn": Vector3(0.0, 0.1, 18.0),
		"bot_spawns": [
			Vector3(-25.0, 0.1, -26.0), Vector3(25.0, 0.1, -26.0), Vector3(0.0, 0.1, -27.0),
			Vector3(-27.0, 0.1, 20.0), Vector3(27.0, 0.1, 26.0), Vector3(-14.0, 0.1, -5.0),
		],
		"dummies": [Vector3(0.0, 0.0, -12.0)],
		"barrels": [Vector3(-8.0, 0.0, -4.0), Vector3(6.0, 0.0, -18.0), Vector3(-20.0, 0.0, 12.0)],
		"crates": [Vector3(4.0, 0.0, 4.0), Vector3(-6.0, 0.0, 14.0), Vector3(20.0, 0.0, 20.0)],
	}


## Hẻm tường: sàn dài 90 m; hai dãy tường chạy song song dọc giữa, chừa khe ở giữa để sang hai làn bên.
static func _alley() -> Dictionary:
	var boxes: Array = []
	for sx in [-1.0, 1.0]:
		# hai đoạn tường chạy mỗi bên (z -38..-8 và 8..38), cao 8 m
		boxes.append(_b(Vector3(1.0, 8.0, 30.0), Vector3(10.0 * sx, 4.0, -23.0), "runwall"))
		boxes.append(_b(Vector3(1.0, 8.0, 30.0), Vector3(10.0 * sx, 4.0, 23.0), "runwall"))
		# bệ móc trên cao ở đầu mỗi khe
		boxes.append(_b(Vector3(5.0, 0.5, 5.0), Vector3(13.5 * sx, 9.0, 0.0), "grapple"))
		# dốc ở làn bên để trượt xuống
		boxes.append(_b(Vector3(6.0, 1.0, 14.0), Vector3(13.5 * sx, 1.2, -22.0), "ramp", Vector3(18.0, 0.0, 0.0)))
	# vật cản thấp giữa hành lang để nhảy / slide
	for z in [-14.0, 0.0, 14.0]:
		boxes.append(_b(Vector3(3.0, 1.2, 1.5), Vector3(0.0, 0.6, z), "platform"))
	boxes.append(_b(Vector3(4.0, 7.0, 4.0), Vector3(0.0, 3.5, -30.0), "pillar"))
	return {
		"name": "Hẻm tường", "desc": "Hành lang dài, tường chạy song song, nhiều đường móc",
		"half": Vector2(17.0, 45.0), "wall_h": 12.0, "void_y": -30.0,
		"boxes": boxes,
		"spawn": Vector3(0.0, 0.1, 40.0),
		"bot_spawns": [
			Vector3(-6.0, 0.1, -40.0), Vector3(6.0, 0.1, -40.0), Vector3(0.0, 0.1, -36.0),
			Vector3(-14.0, 0.1, 0.0), Vector3(14.0, 0.1, 0.0), Vector3(0.0, 0.1, -8.0),
		],
		"dummies": [Vector3(0.0, 0.0, 20.0)],
		"barrels": [Vector3(-4.0, 0.0, -20.0), Vector3(4.0, 0.0, 8.0), Vector3(-14.0, 0.0, 14.0)],
		"crates": [Vector3(-3.0, 0.0, 30.0), Vector3(14.0, 0.0, -10.0), Vector3(-14.0, 0.0, -30.0)],
	}


## Tháp: tháp ba tầng ở giữa (cao 2 / 5 / 9 m) có bệ móc ở đỉnh, 4 dốc leo, cột góc; tường cao 18 m.
static func _tower() -> Dictionary:
	var boxes: Array = []
	boxes.append(_b(Vector3(16.0, 2.0, 16.0), Vector3(0.0, 1.0, 0.0), "platform"))
	boxes.append(_b(Vector3(10.0, 3.0, 10.0), Vector3(0.0, 3.5, 0.0), "platform"))
	boxes.append(_b(Vector3(5.0, 4.0, 5.0), Vector3(0.0, 7.0, 0.0), "platform"))
	boxes.append(_b(Vector3(7.0, 0.5, 7.0), Vector3(0.0, 15.0, 0.0), "grapple"))
	# 2 dốc leo lên tầng 1 (bắc và nam)
	boxes.append(_b(Vector3(6.0, 1.0, 12.0), Vector3(0.0, 0.5, -12.5), "ramp", Vector3(-9.0, 0.0, 0.0)))
	boxes.append(_b(Vector3(6.0, 1.0, 12.0), Vector3(0.0, 0.5, 12.5), "ramp", Vector3(9.0, 0.0, 0.0)))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			boxes.append(_b(Vector3(2.5, 14.0, 2.5), Vector3(20.0 * sx, 7.0, 20.0 * sz), "pillar"))
	boxes.append(_b(Vector3(1.0, 9.0, 24.0), Vector3(-22.0, 4.5, 0.0), "runwall"))
	boxes.append(_b(Vector3(1.0, 9.0, 24.0), Vector3(22.0, 4.5, 0.0), "runwall"))
	return {
		"name": "Tháp", "desc": "Tháp nhiều tầng giữa sân: chênh cao lớn, hợp slam và rocket-jump",
		"half": Vector2(28.0, 28.0), "wall_h": 18.0, "void_y": -30.0,
		"boxes": boxes,
		"spawn": Vector3(0.0, 0.1, 25.0),
		"bot_spawns": [
			Vector3(-25.0, 0.1, -25.0), Vector3(25.0, 0.1, -25.0), Vector3(0.0, 0.1, -25.0),
			Vector3(-25.0, 0.1, 10.0), Vector3(25.0, 0.1, 10.0), Vector3(-12.0, 0.1, -18.0),
		],
		"dummies": [Vector3(-10.0, 0.0, 20.0)],
		"barrels": [Vector3(-14.0, 0.0, 6.0), Vector3(14.0, 0.0, -6.0), Vector3(10.0, 0.0, 22.0)],
		"crates": [Vector3(-16.0, 0.0, -10.0), Vector3(16.0, 0.0, 14.0), Vector3(6.0, 0.0, -22.0)],
	}


# ------------------------------------------------------------------ Khu phố (map lớn, M21)

## Kích thước Khu phố (m). Diện tích gấp 5 lần Sân tập (60x60). Đổi để thu/phóng; bố cục tự tính lại theo `DISTRICT_HALF`.
const DISTRICT_HALF: float = 67.0
const DISTRICT_SEED: int = 21


## Hình chữ nhật (x0, z0, x1, z1) của một hộp (bỏ qua xoay: đủ để tránh chồng lấn).
static func _rect(b: Dictionary) -> Rect2:
	var sz: Vector3 = b["size"]
	var p: Vector3 = b["pos"]
	return Rect2(p.x - sz.x * 0.5, p.z - sz.z * 0.5, sz.x, sz.z)


static func _clear(rects: Array, c: Vector2, margin: float) -> bool:
	for r in rects:
		if (r as Rect2).grow(margin).has_point(c):
			return false
	return true


static func _overlaps(rects: Array, rc: Rect2, margin: float) -> bool:
	for r in rects:
		if (r as Rect2).grow(margin).intersects(rc):
			return true
	return false


## Khu phố: quảng trường trung tâm, tháp (NW), hẻm tường (NE), đồi dốc (SW), cánh đồng (SE) và các toà nhà ở giữa
## nối bằng phố rộng >= 6 m. Hộp tính bằng code, hạt giống cố định. Điểm sinh bot, thùng, bia chọn ở chỗ trống.
static func _district() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = DISTRICT_SEED
	var h: float = DISTRICT_HALF
	var boxes: Array = []
	var zones: Array = []   # vùng cấm cho toà nhà (khu chơi đặc biệt)
	# 1. Quảng trường trung tâm: cột cao có bệ móc, vòng chỗ nấp thấp.
	boxes.append(_b(Vector3(3.0, 14.0, 3.0), Vector3(0.0, 7.0, 0.0), "pillar"))
	boxes.append(_b(Vector3(6.0, 0.5, 6.0), Vector3(0.0, 15.0, 0.0), "grapple"))
	for sx in [-1.0, 1.0]:
		boxes.append(_b(Vector3(1.5, 1.4, 5.0), Vector3(10.0 * sx, 0.7, 0.0), "platform"))
		boxes.append(_b(Vector3(5.0, 1.4, 1.5), Vector3(0.0, 0.7, 10.0 * sx), "platform"))
	zones.append(Rect2(-13.0, -13.0, 26.0, 26.0))
	# 2. Tháp ba tầng (tây bắc), có bệ móc ở đỉnh và hai dốc leo.
	var tc := Vector3(-42.0, 0.0, -42.0)
	boxes.append(_b(Vector3(16.0, 2.0, 16.0), tc + Vector3(0.0, 1.0, 0.0), "platform"))
	boxes.append(_b(Vector3(10.0, 3.0, 10.0), tc + Vector3(0.0, 3.5, 0.0), "platform"))
	boxes.append(_b(Vector3(5.0, 4.0, 5.0), tc + Vector3(0.0, 7.0, 0.0), "platform"))
	boxes.append(_b(Vector3(7.0, 0.5, 7.0), tc + Vector3(0.0, 15.0, 0.0), "grapple"))
	boxes.append(_b(Vector3(6.0, 1.0, 12.0), tc + Vector3(0.0, 0.5, -12.5), "ramp", Vector3(-9.0, 0.0, 0.0)))
	boxes.append(_b(Vector3(6.0, 1.0, 12.0), tc + Vector3(0.0, 0.5, 12.5), "ramp", Vector3(9.0, 0.0, 0.0)))
	zones.append(Rect2(-52.0, -62.0, 20.0, 40.0))
	# 3. Hẻm tường (đông bắc): hai tường chạy dài + bệ móc + vật cản thấp.
	var ac := Vector3(42.0, 0.0, -42.0)
	for sx in [-1.0, 1.0]:
		boxes.append(_b(Vector3(1.0, 8.0, 30.0), ac + Vector3(8.0 * sx, 4.0, 0.0), "runwall"))
		boxes.append(_b(Vector3(5.0, 0.5, 5.0), ac + Vector3(11.5 * sx, 9.0, -18.0), "grapple"))
	for dz in [-10.0, 0.0, 10.0]:
		boxes.append(_b(Vector3(3.0, 1.2, 1.5), ac + Vector3(0.0, 0.6, dz), "platform"))
	zones.append(Rect2(30.0, -60.0, 24.0, 36.0))
	# 4. Đồi dốc (tây nam): ba dốc lướt xuống, bục cao ở đỉnh.
	var sc := Vector3(-42.0, 0.0, 40.0)
	for i in 3:
		boxes.append(_b(Vector3(10.0, 1.0, 20.0), sc + Vector3(-12.0 + 12.0 * i, 2.0, 0.0), "ramp", Vector3(20.0 if i % 2 == 0 else -20.0, 0.0, 0.0)))
	boxes.append(_b(Vector3(8.0, 2.5, 6.0), sc + Vector3(0.0, 1.25, 18.0), "platform"))
	zones.append(Rect2(-58.0, 28.0, 32.0, 26.0))
	# 5. Cánh đồng (đông nam): chỗ nấp rải rác cho xạ thủ, một tường chạy ở rìa.
	var fc := Vector2(42.0, 40.0)
	var field_rects: Array = []
	for i in 9:
		var sz := Vector3(rng.randf_range(2.0, 4.0), rng.randf_range(1.4, 3.0), rng.randf_range(2.0, 4.0))
		var pos := Vector3(fc.x + rng.randf_range(-14.0, 14.0), sz.y * 0.5, fc.y + rng.randf_range(-12.0, 12.0))
		var cand: Dictionary = _b(sz, pos, "platform" if i % 3 else "pillar")
		if _overlaps(field_rects, _rect(cand), 4.0):
			continue
		field_rects.append(_rect(cand))
		boxes.append(cand)
	boxes.append(_b(Vector3(1.0, 8.0, 22.0), Vector3(h - 6.0, 4.0, 40.0), "runwall"))
	zones.append(Rect2(26.0, 26.0, 36.0, 30.0))
	# 6. Toà nhà: lưới 20 m có xê dịch, bỏ những ô đè lên khu chơi, vùng xuất phát hoặc nhau.
	var spawn_zone := Rect2(-10.0, 48.0, 20.0, h - 48.0 + 1.0)
	zones.append(spawn_zone)
	var b_rects: Array = []
	var gz: float = -h + 9.0
	while gz <= h - 8.0:
		var gx: float = -h + 9.0
		while gx <= h - 8.0:
			var w: float = rng.randf_range(8.0, 12.0)
			var d: float = rng.randf_range(8.0, 12.0)
			var hh: float = rng.randf_range(10.0, 26.0)
			var cx: float = gx + rng.randf_range(-2.0, 2.0)
			var cz: float = gz + rng.randf_range(-2.0, 2.0)
			var keep: bool = rng.randf() > 0.15
			var rc := Rect2(cx - w * 0.5, cz - d * 0.5, w, d)
			if keep and not _overlaps(zones, rc, 1.0) and not _overlaps(b_rects, rc, 2.0) and absf(cx) < h - w * 0.5 - 1.0 and absf(cz) < h - d * 0.5 - 1.0:
				boxes.append(_b(Vector3(w, hh, d), Vector3(cx, hh * 0.5, cz), "wall"))
				b_rects.append(rc)
				if hh > 20.0:
					boxes.append(_b(Vector3(4.0, 0.5, 4.0), Vector3(cx, hh + 0.25, cz), "grapple"))   # bệ đánh dấu trên nóc
			gx += 20.0
		gz += 20.0
	# Chỗ trống cho điểm sinh / vật phá được: lưới 6 m, cách mọi hộp >= 2.5 m và cách biên >= 4 m.
	var all_rects: Array = []
	for bx in boxes:
		all_rects.append(_rect(bx))
	var free: Array = []
	var gx2: float = -h + 4.0
	while gx2 <= h - 4.0:
		var gz2: float = -h + 4.0
		while gz2 <= h - 4.0:
			if _clear(all_rects, Vector2(gx2, gz2), 2.5):
				free.append(Vector3(gx2, 0.1, gz2))
			gz2 += 6.0
		gx2 += 6.0
	var spawn_pos := Vector3(0.0, 0.1, 58.0)
	var picks: Array = []
	var pool: Array = free.duplicate()
	# xáo trộn xác định rồi chọn, mỗi điểm cách nhau >= 14 m và cách chỗ xuất phát >= 30 m
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for p in pool:
		if (p as Vector3).distance_to(spawn_pos) < 30.0:
			continue
		var ok: bool = true
		for q in picks:
			if (p as Vector3).distance_to(q) < 14.0:
				ok = false
				break
		if ok:
			picks.append(p)
		if picks.size() >= 28:
			break
	var barrels: Array = []
	var crates: Array = []
	for p in pool:
		if barrels.size() >= 12 and crates.size() >= 12:
			break
		if (p as Vector3).distance_to(spawn_pos) < 12.0 or p in picks:
			continue
		var q3 := Vector3((p as Vector3).x + 1.5, 0.0, (p as Vector3).z + 1.5)
		if not _clear(all_rects, Vector2(q3.x, q3.z), 1.5):
			continue
		if barrels.size() < 12 and (barrels.size() <= crates.size()):
			barrels.append(q3)
		elif crates.size() < 12:
			crates.append(q3)
	return {
		"name": "Khu phố", "desc": "Bản đồ lớn gấp 5 lần: quảng trường, tháp, hẻm tường, đồi dốc, cánh đồng và các toà nhà để móc",
		"half": Vector2(h, h), "wall_h": 32.0, "void_y": -40.0,
		"boxes": boxes,
		"spawn": spawn_pos,
		"bot_spawns": picks,
		"dummies": [Vector3(-6.0, 0.0, 51.0), Vector3(6.0, 0.0, 51.0)],
		"barrels": barrels,
		"crates": crates,
		# map lớn: bot sinh trong vòng 35..60 m quanh người chơi (không sinh ở đầu kia bản đồ), có la bàn kẻ địch, navmesh ô thô hơn
		"big": true, "titans": true, "spawn_band": Vector2(35.0, 60.0), "compass": true, "nav_cell": 0.25,
	}


# ------------------------------------------------------------------ Vô Tận (M34)

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
