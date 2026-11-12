extends CanvasLayer
## HUD: tâm ngắm, tốc độ, trạng thái, dash, thanh máu, đạn, thông báo. KHÔNG tự đi tìm Player —
## main.gd nối Signal của Player/Combat -> các hàm set_*/flash (call down, signal up).

var _speed_label: Label
var _state_label: Label
var _dash_label: Label
var _health_bar: ProgressBar
var _health_label: Label
var _ammo_label: Label
var _flash_label: Label
var _death_label: Label
var _flash_tween: Tween


func _ready() -> void:
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline(cross, 22)
	add_child(cross)

	_speed_label = _make_label(Vector2(20.0, 16.0))
	_state_label = _make_label(Vector2(20.0, 44.0))
	_dash_label = _make_label(Vector2(20.0, 72.0))

	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_health_bar.anchor_top = 1.0
	_health_bar.anchor_bottom = 1.0
	_health_bar.offset_left = 20.0
	_health_bar.offset_right = 340.0
	_health_bar.offset_top = -52.0
	_health_bar.offset_bottom = -26.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.15, 0.15)
	_health_bar.add_theme_stylebox_override("fill", fill)
	add_child(_health_bar)
	_health_label = Label.new()
	_health_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(_health_label, 16)
	_health_bar.add_child(_health_label)

	_ammo_label = Label.new()
	_ammo_label.anchor_left = 1.0
	_ammo_label.anchor_right = 1.0
	_ammo_label.anchor_top = 1.0
	_ammo_label.anchor_bottom = 1.0
	_ammo_label.offset_left = -240.0
	_ammo_label.offset_right = -24.0
	_ammo_label.offset_top = -56.0
	_ammo_label.offset_bottom = -20.0
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_outline(_ammo_label, 26)
	add_child(_ammo_label)

	_flash_label = Label.new()
	_flash_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_label.offset_top = -120.0
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_flash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_label.modulate.a = 0.0
	_outline(_flash_label, 40)
	add_child(_flash_label)

	_death_label = Label.new()
	_death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_label.text = "BẠN ĐÃ CHẾT"
	_death_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	_outline(_death_label, 64)
	_death_label.visible = false
	add_child(_death_label)

	set_speed(0.0)
	set_state("NORMAL")
	set_dash(2, 2)
	set_health(100.0, 100.0)
	set_ammo(6, 6)


func set_speed(speed: float) -> void:
	_speed_label.text = "Speed: %.1f m/s" % speed


func set_state(state_name: String) -> void:
	_state_label.text = "State: %s" % state_name


func set_dash(charges: int, max_charges: int) -> void:
	_dash_label.text = "Dash: " + "[#]".repeat(charges) + "[ ]".repeat(max_charges - charges)


func set_health(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%d / %d" % [roundi(current), roundi(maximum)]


func set_ammo(current: int, maximum: int) -> void:
	_ammo_label.text = "Ammo %d / %d" % [current, maximum]


func show_death(on: bool) -> void:
	_death_label.visible = on


## Dòng chữ lớn giữa màn hình, mờ dần (ví dụ "PARRY!").
func flash(text: String, color: Color = Color.WHITE) -> void:
	_flash_label.text = text
	_flash_label.add_theme_color_override("font_color", color)
	_flash_label.modulate.a = 1.0
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.25)
	_flash_tween.tween_property(_flash_label, "modulate:a", 0.0, 0.4)


func _make_label(pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	_outline(l, 18)
	add_child(l)
	return l


func _outline(l: Label, font_size: int) -> void:
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
