extends Control
## Màn Cài đặt: độ nhạy chuột, đảo trục Y, FOV, lắc đầu, tay cầm, đổi phím. Chỉ đọc/ghi Global
## (settings, rebind) và phát `closed` khi bấm Quay lại. Chạy được cả khi game đang pause.

signal closed

const UIKit = preload("res://scripts/ui_kit.gd")

var _listening: String = ""     # action đang chờ phím mới
var _key_buttons: Dictionary = {}
var _msg: Label
var _sliders: Dictionary = {}
var _invert: CheckButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.03, 0.04, 0.96)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60.0
	scroll.offset_right = -60.0
	scroll.offset_top = 20.0
	scroll.offset_bottom = -20.0
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	box.add_child(UIKit.title("CÀI ĐẶT", 56))

	_add_slider(box, "mouse_mult", "Độ nhạy chuột", 0.2, 3.0, 0.05)
	_add_slider(box, "fov", "Góc nhìn (FOV)", 70.0, 110.0, 1.0)
	_add_slider(box, "bob", "Lắc đầu khi chạy", 0.0, 1.0, 0.05)
	_add_slider(box, "pad_sens", "Độ nhạy tay cầm", 0.3, 3.0, 0.05)
	_add_slider(box, "pad_deadzone", "Vùng chết cần analog", 0.05, 0.5, 0.01)
	_add_slider(box, "vol_master", "Âm lượng tổng", 0.0, 1.0, 0.05)
	_add_slider(box, "vol_sfx", "Âm lượng hiệu ứng", 0.0, 1.0, 0.05)
	_add_slider(box, "vol_music", "Âm lượng nhạc", 0.0, 1.0, 0.05)
	_invert = CheckButton.new()
	_invert.text = "Đảo trục Y"
	_invert.add_theme_font_size_override("font_size", 22)
	_invert.button_pressed = bool(Global.settings["invert_y"])
	_invert.toggled.connect(func(on: bool): Global.set_setting("invert_y", on))
	box.add_child(_invert)

	box.add_child(UIKit.label("Phím (bấm vào ô rồi nhấn phím hoặc nút chuột mới, Esc để huỷ)", 20))
	_msg = UIKit.label("", 20)
	_msg.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	box.add_child(_msg)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for r in Global.REMAPPABLE:
		grid.add_child(UIKit.label(r[1], 22, HORIZONTAL_ALIGNMENT_LEFT))
		var b := Button.new()
		b.custom_minimum_size = Vector2(300.0, 40.0)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_start_listen.bind(r[0]))
		grid.add_child(b)
		_key_buttons[r[0]] = b
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var reset := UIKit.button("Mặc định")
	reset.pressed.connect(_on_reset)
	var back := UIKit.button("Quay lại")
	back.pressed.connect(func(): closed.emit())
	row.add_child(reset)
	row.add_child(back)
	box.add_child(row)
	Global.bindings_changed.connect(_refresh)
	_refresh()


func _add_slider(parent: Control, key: String, text: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var name_l := UIKit.label(text, 22, HORIZONTAL_ALIGNMENT_LEFT)
	name_l.custom_minimum_size = Vector2(320.0, 0.0)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = float(Global.settings[key])
	sl.custom_minimum_size = Vector2(420.0, 30.0)
	var val_l := UIKit.label("%.2f" % sl.value, 22, HORIZONTAL_ALIGNMENT_LEFT)
	sl.value_changed.connect(func(v: float):
		Global.set_setting(key, v)
		val_l.text = "%.2f" % v)
	row.add_child(name_l)
	row.add_child(sl)
	row.add_child(val_l)
	parent.add_child(row)
	_sliders[key] = [sl, val_l]


func _refresh() -> void:
	for action in _key_buttons:
		(_key_buttons[action] as Button).text = "..." if action == _listening else Global.binding_text(action)


func _start_listen(action: String) -> void:
	_listening = action
	_msg.text = "Nhấn phím mới cho \"%s\"..." % _name_of(action)
	_refresh()


func _name_of(action: String) -> String:
	for r in Global.REMAPPABLE:
		if r[0] == action:
			return r[1]
	return action


func _on_reset() -> void:
	_listening = ""
	Global.reset_bindings()
	Global.reset_settings()
	for key in _sliders:
		_sliders[key][0].value = float(Global.settings[key])
	_invert.button_pressed = bool(Global.settings["invert_y"])
	_msg.text = "Đã đặt lại mặc định"
	_refresh()


func _input(event: InputEvent) -> void:
	if _listening == "" or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			_listening = ""
			_msg.text = ""
		else:
			_try_bind(event)
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		_try_bind(event)


func _try_bind(event: InputEvent) -> void:
	var clash: String = Global.binding_conflict(_listening, event)
	if clash != "":
		_msg.text = "Phím này đang dùng cho \"%s\"" % _name_of(clash)
	elif Global.rebind(_listening, event):
		_msg.text = "Đã gán \"%s\" = %s" % [_name_of(_listening), Global.binding_text(_listening)]
	_listening = ""
	_refresh()
