extends Control
## Menu chính: Chơi / Hướng dẫn / Thoát.

const UIKit = preload("res://scripts/ui_kit.gd")
const GAME_SCENE := "res://scenes/main.tscn"

var play_button: Button
var help_button: Button
var quality_button: Button
var map_button: Button
var difficulty_button: Button
var start_wave_button: Button
var mode_button: Button
var start_button: Button
var setup_back_button: Button
var best_label: Label
var mode_desc_label: Label
var setup_panel: Control
var fx_button: Button
var quit_button: Button
var shop_button: Button
var shop_panel: Control
var start_gun_button: Button
var help_panel: Control
var settings_button: Button
var settings_panel: Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_music("menu")
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

	var box := UIKit.center_box(self, 10)
	box.add_child(UIKit.title("REDLINER", 80))
	box.add_child(UIKit.label("Đấu trường FPS tốc độ cao - kiếm, súng và parry", 22))
	var ver := UIKit.label("Phiên bản %s  |  F3: hiện FPS" % Global.VERSION, 14)
	ver.modulate = Color(1, 1, 1, 0.5)
	box.add_child(ver)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 8.0)
	box.add_child(spacer)
	play_button = UIKit.button("Chơi")
	help_button = UIKit.button("Hướng dẫn")
	shop_button = UIKit.button("Cửa hàng")
	settings_button = UIKit.button("Cài đặt")
	quality_button = UIKit.quality_button()
	fx_button = UIKit.fx_button()
	quit_button = UIKit.button("Thoát")
	for b in [play_button, shop_button, help_button, settings_button, quality_button, fx_button, quit_button]:
		box.add_child(b)
	play_button.pressed.connect(func(): setup_panel.visible = true)
	help_button.pressed.connect(show_help)
	shop_button.pressed.connect(func(): shop_panel.visible = true)
	settings_button.pressed.connect(func(): settings_panel.visible = true)
	quit_button.pressed.connect(func(): get_tree().quit())

	_build_setup()
	_build_help()
	shop_panel = load("res://scripts/shop_menu.gd").new()
	shop_panel.visible = false
	add_child(shop_panel)
	shop_panel.closed.connect(func(): shop_panel.visible = false)
	settings_panel = load("res://scripts/settings_menu.gd").new()
	settings_panel.visible = false
	add_child(settings_panel)
	settings_panel.closed.connect(func(): settings_panel.visible = false)


## Màn "Chuẩn bị": chọn chế độ, bản đồ, độ khó rồi bắt đầu. Hiện kỷ lục của lựa chọn đang chọn.
func _build_setup() -> void:
	setup_panel = Control.new()
	setup_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	setup_panel.visible = false
	add_child(setup_panel)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.03, 0.04, 1.0)
	setup_panel.add_child(dim)
	var box := UIKit.center_box(setup_panel, 14)
	box.add_child(UIKit.title("CHUẨN BỊ", 64))
	mode_button = UIKit.mode_button()
	map_button = UIKit.map_button()
	difficulty_button = UIKit.difficulty_button()
	start_wave_button = UIKit.start_wave_button()
	start_gun_button = UIKit.start_gun_button()
	mode_desc_label = UIKit.label("", 20)
	mode_desc_label.custom_minimum_size = Vector2(640.0, 0.0)
	mode_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	best_label = UIKit.label("", 22)
	best_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	start_button = UIKit.button("Bắt đầu")
	setup_back_button = UIKit.button("Quay lại")
	for c in [mode_button, map_button, difficulty_button, start_wave_button, start_gun_button, mode_desc_label, best_label, start_button, setup_back_button]:
		box.add_child(c)
	map_button.pressed.connect(_refresh_setup)
	start_wave_button.pressed.connect(_refresh_setup)
	Global.difficulty_changed.connect(func(_l): _refresh_setup())
	Global.mode_changed.connect(func(_m): _refresh_setup())
	start_button.pressed.connect(_on_play)
	setup_back_button.pressed.connect(func(): setup_panel.visible = false)
	_refresh_setup()


## Mô tả chế độ + kỷ lục của (chế độ, độ khó) đang chọn.
func _refresh_setup() -> void:
	mode_desc_label.text = String(Global.MODE_DESCRIPTIONS[Global.game_mode])
	if Global.selected_map == "district" and Global.game_mode != "training":
		mode_desc_label.text += " Khu phố có Titan từ wave 5."
	start_wave_button.visible = Global.game_mode in ["survival", "timed"]
	map_button.visible = Global.game_mode != "endless"
	start_gun_button.visible = Global.game_mode == "endless"
	if Global.game_mode == "training":
		best_label.text = "Không tính điểm"
	else:
		best_label.text = "Kỷ lục (%s, %s): %d" % [Global.MODE_NAMES[Global.game_mode], Global.DIFFICULTY_NAMES[Global.difficulty], Global.best_score()]


func _build_help() -> void:
	help_panel = Control.new()
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_panel.visible = false
	add_child(help_panel)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.03, 1.0)
	help_panel.add_child(dim)
	var box := UIKit.center_box(help_panel, 8)
	box.add_child(UIKit.title("HƯỚNG DẪN", 56))
	var k := func(a: String) -> String: return Global.binding_text(a).split(" / ")[0] # phím chính (đủ gọn để đọc)
	var lines: Array = [
		"%s / %s / %s / %s  -  di chuyển        Chuột  -  nhìn" % [k.call("move_forward"), k.call("move_left"), k.call("move_back"), k.call("move_right")],
		"%s  -  nhảy (nhảy liên tục giữ được tốc độ; sát gờ thấp thì tự trèo)" % k.call("jump"),
		"%s  -  trượt (chạy nhanh + trượt; xuống dốc càng nhanh)" % k.call("slide"),
		"%s  -  dash (2 lần, tự hồi)" % k.call("dash"),
		"Chạy sát tường khi đang trên không  -  bám tường (%s để bật ra)" % k.call("jump"),
		"%s  -  móc (grapple) vào bề mặt, giữ để kéo; nhả ra để bẻ hướng theo ống ngắm" % k.call("grapple"),
		"%s (trên không)  -  GROUND SLAM: lao xuống, chạm đất gây sốc và nảy lên" % k.call("slam"),
		"%s  -  chém kiếm        %s  -  CHÉM RỘNG (quét rộng, chậm, đau hơn)" % [k.call("attack"), k.call("heavy")],
		"%s  -  bắn súng        %s  -  nạp đạn        %s / %s / %s / %s  -  đổi súng" % [k.call("shoot"), k.call("reload"), k.call("weapon_1"), k.call("weapon_2"), k.call("weapon_3"), k.call("weapon_4")],
		"Súng 1 lục  2 Shotgun (gần, mạnh, đẩy lùi)  3 Pháo nổ (nổ lan, tự bắn nhảy được)  4 Bắn tỉa (%s ngắm, headshot x2)" % k.call("zoom"),
		"%s  -  PARRY: đúng lúc thì phản đạn về người bắn, đòn kiếm làm địch choáng" % k.call("parry"),
		"Hai kiếm chạm nhau  -  CLASH: cả hai bị đẩy lùi",
		"Thua clash, parry hụt, bị parry  -  đầy thanh Instability  -  MẤT THẾ vài giây (không đánh/parry/dash)",
		"Bot lao nhanh bọc sườn, pháo thủ ném bom nổ từ xa, tối đa 3 bot áp sát cùng lúc; bot đánh mạnh hơn khi bạn mất thế",
		"Chế độ: Sinh tồn (wave vô hạn), Thử thách thời gian (hạ đủ bot trước khi hết giờ), Tập luyện (bất tử, đạn vô hạn)",
		"Esc  -  tạm dừng",
	]
	for t in lines:
		box.add_child(UIKit.label(t, 20))
	var back := UIKit.button("Quay lại")
	back.pressed.connect(func(): help_panel.visible = false)
	box.add_child(back)


func show_help() -> void:
	help_panel.visible = true


func _on_play() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
