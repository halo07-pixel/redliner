extends RefCounted
## Chỉ cho test: sân phẳng 60x60 (bản đồ "Sân tập" cũ, đã bỏ khỏi game ở M41) để các test cơ chế dùng hình học nhỏ, dễ tính.
## Dùng: arena.map_override = Fixture.yard() (hoặc load("res://tools/tests/fixtures/flat_arena.gd").new()).

static func _b(size: Vector3, pos: Vector3, role: String, rot := Vector3.ZERO) -> Dictionary:
	return {"size": size, "pos": pos, "role": role, "rot": rot}


## Sân tập: đấu trường gốc (giữ nguyên bố cục từ M2).
static func yard() -> Dictionary:
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
		"id": "yard", "name": "Sân tập", "desc": "Đấu trường gốc: cột, bục, dốc, tường chạy",
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
