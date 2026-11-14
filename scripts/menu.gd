extends Control
## Menu chính: Chơi / Hướng dẫn / Thoát.

const UIKit = preload("res://scripts/ui_kit.gd")
const GAME_SCENE := "res://scenes/main.tscn"

var play_button: Button
var help_button: Button
var quality_button: Button
var quit_button: Button
var help_panel: Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.04, 0.05)
	add_child(bg)
	var stripe := ColorRect.new() # vệt đỏ "redline"
	stripe.anchor_right = 1.0
	stripe.anchor_top = 0.5
	stripe.anchor_bottom = 0.5
	stripe.offset_top = -4.0
	stripe.offset_bottom = 4.0
	stripe.color = Color(0.9, 0.1, 0.1, 0.8)
	add_child(stripe)

	var box := UIKit.center_box(self, 16)
	box.add_child(UIKit.title("REDLINER", 96))
	box.add_child(UIKit.label("Đấu trường FPS tốc độ cao - kiếm, súng và parry", 22))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 24.0)
	box.add_child(spacer)
	play_button = UIKit.button("Chơi")
	help_button = UIKit.button("Hướng dẫn")
	quality_button = UIKit.quality_button()
	quit_button = UIKit.button("Thoát")
	for b in [play_button, help_button, quality_button, quit_button]:
		box.add_child(b)
	box.add_child(UIKit.label("Điểm cao nhất: %d" % Global.high_score, 20))
	play_button.pressed.connect(_on_play)
	help_button.pressed.connect(show_help)
	quit_button.pressed.connect(func(): get_tree().quit())

	_build_help()


func _build_help() -> void:
	help_panel = Control.new()
	help_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_panel.visible = false
	add_child(help_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.03, 1.0)
	help_panel.add_child(dim)
	var box := UIKit.center_box(help_panel, 8)
	box.add_child(UIKit.title("HƯỚNG DẪN", 56))
	var lines: Array = [
		"W A S D  -  di chuyển        Chuột  -  nhìn",
		"Space  -  nhảy (nhảy liên tục giữ được tốc độ)",
		"Ctrl  -  trượt (chạy nhanh + Ctrl; xuống dốc càng nhanh)",
		"Shift  -  dash (2 lần, tự hồi)",
		"Chạy sát tường khi đang trên không  -  bám tường (Space để bật ra)",
		"Chuột phải  -  móc (grapple) vào bề mặt, giữ để kéo",
		"Chuột trái  -  chém kiếm        E  -  bắn súng        R  -  nạp đạn",
		"F  -  PARRY: đúng lúc thì phản đạn về người bắn, đòn kiếm làm địch choáng",
		"Hai kiếm chạm nhau  -  CLASH: cả hai bị đẩy lùi",
		"Chạy nhanh, đánh trúng, parry  -  đầy thanh Instability  -  REDLINE",
		"Esc  -  tạm dừng",
	]
	for t in lines:
		box.add_child(UIKit.label(t, 22))
	var back := UIKit.button("Quay lại")
	back.pressed.connect(func(): help_panel.visible = false)
	box.add_child(back)


func show_help() -> void:
	help_panel.visible = true


func _on_play() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
