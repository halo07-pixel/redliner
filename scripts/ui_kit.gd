extends RefCounted
## Hàm dựng giao diện dùng chung cho menu / tạm dừng / tổng kết (không cần file theme).


static func title(text: String, size: int = 72, color: Color = Color(0.95, 0.2, 0.15)) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	return l


static func label(text: String, size: int = 22, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280.0, 54.0)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(func(): Sfx.play("ui_click"))
	return b


## Hộp giữa màn hình: trả về VBoxContainer để thêm nội dung vào.
static func center_box(parent: Node, separation: int = 14) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	return box


## Nút bật/tắt giảm hiệu ứng.
static func fx_button() -> Button:
	var b := button("")
	var refresh := func(): b.text = "Hiệu ứng: %s" % ("Giảm" if Global.reduced_fx else "Đầy đủ")
	refresh.call()
	b.pressed.connect(func():
		Global.set_reduced_fx(not Global.reduced_fx)
		refresh.call())
	return b


## Nút xoay vòng chế độ chơi; chữ theo Global.game_mode.
static func mode_button() -> Button:
	var b := button("")
	var refresh := func(): b.text = "Chế độ: %s" % Global.MODE_NAMES[Global.game_mode]
	refresh.call()
	b.pressed.connect(func():
		Global.cycle_mode()
		refresh.call())
	return b


## Nút xoay vòng súng khởi đầu (Vô Tận) qua các súng đã sở hữu.
static func start_gun_button() -> Button:
	var b := button("")
	var refresh := func(): b.text = "Súng khởi đầu: %s" % Global.WEAPONS[Global.start_gun]["name"]
	refresh.call()
	b.pressed.connect(func():
		Global.cycle_start_gun()
		refresh.call())
	Global.start_gun_changed.connect(func(_id):
		if is_instance_valid(b):
			refresh.call())
	return b


## Nút xoay vòng mức độ khó; chữ theo Global.difficulty.
static func difficulty_button() -> Button:
	var b := button("")
	var refresh := func(): b.text = "Độ khó: %s" % Global.DIFFICULTY_NAMES[Global.difficulty]
	refresh.call()
	b.pressed.connect(func():
		Global.cycle_difficulty()
		refresh.call())
	return b


## Nút xoay vòng "bắt đầu từ wave N" (thử Titan / wave cao; không tính kỷ lục khi N > 1).
static func start_wave_button() -> Button:
	var b := button("")
	var refresh := func(): b.text = "Bắt đầu từ wave: %d%s" % [Global.start_wave, "  (không tính kỷ lục)" if Global.start_wave > 1 else ""]
	refresh.call()
	b.pressed.connect(func():
		Global.cycle_start_wave()
		refresh.call())
	return b


## Nút xoay vòng đấu trường; chữ theo Global.selected_map.
static func map_button() -> Button:
	var b := button("")
	var refresh := func(): b.text = "Bản đồ: %s" % Global.MAP_NAMES[Global.selected_map]
	refresh.call()
	b.pressed.connect(func():
		Global.cycle_map()
		refresh.call())
	return b


## Nút xoay vòng mức đồ họa Thấp/Vừa/Cao; chữ tự cập nhật theo Global.quality.
static func quality_button() -> Button:
	var b := button("")
	var refresh := func(): b.text = "Đồ họa: %s" % Global.QUALITY_NAMES[Global.quality]
	refresh.call()
	b.pressed.connect(func():
		Global.cycle_quality()
		refresh.call())
	return b
