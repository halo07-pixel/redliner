extends CanvasLayer
## HUD tối thiểu: tâm ngắm, tốc độ, trạng thái di chuyển, số lần dash. KHÔNG tự đi tìm Player — main.gd nối
## Signal của Player -> set_speed()/set_state()/set_dash() (call down, signal up).

var _speed_label: Label
var _state_label: Label
var _dash_label: Label


func _ready() -> void:
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline(cross, 22)
	add_child(cross)

	_speed_label = Label.new()
	_speed_label.position = Vector2(20.0, 16.0)
	_outline(_speed_label, 18)
	add_child(_speed_label)
	_state_label = Label.new()
	_state_label.position = Vector2(20.0, 44.0)
	_outline(_state_label, 18)
	add_child(_state_label)
	_dash_label = Label.new()
	_dash_label.position = Vector2(20.0, 72.0)
	_outline(_dash_label, 18)
	add_child(_dash_label)
	set_speed(0.0)
	set_state("NORMAL")
	set_dash(2, 2)


func set_speed(speed: float) -> void:
	_speed_label.text = "Speed: %.1f m/s" % speed


func set_state(state_name: String) -> void:
	_state_label.text = "State: %s" % state_name


func set_dash(charges: int, max_charges: int) -> void:
	_dash_label.text = "Dash: " + "[#]".repeat(charges) + "[ ]".repeat(max_charges - charges)


func _outline(l: Label, font_size: int) -> void:
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
