extends CanvasLayer
## Menu tạm dừng. Chạy ngay cả khi game đang pause (process_mode ALWAYS). Chỉ phát Signal.

signal resume_requested
signal menu_requested

const UIKit = preload("res://scripts/ui_kit.gd")

var resume_button: Button
var quality_button: Button
var menu_button: Button
var settings_button: Button
var settings_panel: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	add_child(dim)
	var box := UIKit.center_box(dim, 16)
	box.add_child(UIKit.title("TẠM DỪNG", 72, Color.WHITE))
	resume_button = UIKit.button("Tiếp tục")
	quality_button = UIKit.quality_button()
	settings_button = UIKit.button("Cài đặt")
	menu_button = UIKit.button("Về menu")
	box.add_child(resume_button)
	box.add_child(quality_button)
	box.add_child(settings_button)
	box.add_child(menu_button)
	resume_button.pressed.connect(func(): resume_requested.emit())
	menu_button.pressed.connect(func(): menu_requested.emit())
	settings_panel = load("res://scripts/settings_menu.gd").new()
	settings_panel.visible = false
	dim.add_child(settings_panel)
	settings_panel.closed.connect(func(): settings_panel.visible = false)
	settings_button.pressed.connect(func(): settings_panel.visible = true)


func set_open(on: bool) -> void:
	visible = on
	if not on and settings_panel != null:
		settings_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if settings_panel != null and settings_panel.visible:
			settings_panel.visible = false # Esc trong Cài đặt: quay lại menu tạm dừng
			get_viewport().set_input_as_handled()
			return
		resume_requested.emit()
		get_viewport().set_input_as_handled()
