extends CanvasLayer
## Màn hình tổng kết khi người chơi chết: tầng đạt được, điểm, số bot hạ + Chơi lại / Về menu.

signal restart_requested
signal menu_requested

const UIKit = preload("res://scripts/ui_kit.gd")

var restart_button: Button
var menu_button: Button
var title_label: Label
var summary_label: Label
var record_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.1, 0.0, 0.0, 0.8)
	add_child(dim)
	var box := UIKit.center_box(dim, 14)
	title_label = UIKit.title("BẠN ĐÃ GỤC", 72)
	box.add_child(title_label)
	summary_label = UIKit.label("", 28)
	box.add_child(summary_label)
	record_label = UIKit.label("", 26)
	record_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box.add_child(record_label)
	restart_button = UIKit.button("Chơi lại")
	menu_button = UIKit.button("Về menu")
	box.add_child(restart_button)
	box.add_child(menu_button)
	restart_button.pressed.connect(func(): restart_requested.emit())
	menu_button.pressed.connect(func(): menu_requested.emit())


## Tổng kết đầy đủ. d: title, lines (Array[String]), record (String, rỗng nếu không có).
func show_result(d: Dictionary) -> void:
	title_label.text = String(d.get("title", "KẾT THÚC"))
	title_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.15))
	summary_label.text = "\n".join(PackedStringArray(d.get("lines", [])))
	record_label.text = String(d.get("record", ""))
	visible = true
