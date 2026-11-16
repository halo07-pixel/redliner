extends RefCounted
## Dữ liệu 3 đấu trường (chỉ là dữ liệu, không tạo node nên test được không cần cảnh).
## Mỗi map: half (nửa kích thước sàn x,z), wall_h, boxes [{size,pos,role,rot}], spawn, bot_spawns,
## dummies (bia tập), void_y (rơi dưới mức này thì hồi sinh). Arena đọc dữ liệu và dựng.
## Quy tắc: lối đi chính của bot là mặt sàn phẳng (bot chưa có navmesh, để M14).

const IDS: Array = ["yard", "alley", "tower"]


static func get_map(id: String) -> Dictionary:
	match id:
		"alley":
			return _alley()
		"tower":
			return _tower()
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
	}
