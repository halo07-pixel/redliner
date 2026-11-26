extends "res://scripts/arena.gd"
## Chỉ cho test: Arena dựng sân phẳng 60x60 (`map_fixture.gd`) thay vì bản đồ lưới Vô Tận.

func _init() -> void:
	map_override = load("res://tools/tests/fixtures/map_fixture.gd").yard()
