extends Control
## Cửa hàng (menu chính): mua súng bằng vàng giữ lại giữa các lượt. Chỉ đọc/ghi Global (gold, owned_guns,
## buy_gun); phát `closed` khi bấm Quay lại. Chạy được cả khi game đang pause.

signal closed

const UIKit = preload("res://scripts/ui_kit.gd")

var gold_label: Label
var buy_buttons: Dictionary = {}   # id súng -> Button
var back_button: Button
var _msg: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.03, 0.04, 1.0)
	add_child(bg)
	var box := UIKit.center_box(self, 6)
	box.add_child(UIKit.title("CỬA HÀNG", 48))
	gold_label = UIKit.label("", 28)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box.add_child(gold_label)
	var hint := UIKit.label("Mua súng để chọn làm súng khởi đầu ở chế độ Vô Tận. Mỗi súng có một lỗi riêng.", 18)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(700.0, 0.0)
	box.add_child(hint)
	for id in Global.WEAPON_ORDER:
		if not Global.GOLD["prices"].has(id):
			continue
		var fid: String = String(Global.WEAPONS[id].get("flaw", ""))
		var info := UIKit.label("%s   -   LỖI: %s" % [Global.WEAPONS[id]["name"], Global.FLAWS[fid]["name"] if Global.FLAWS.has(fid) else "-"], 22)
		box.add_child(info)
		var sub := UIKit.label(String(Global.FLAWS[fid]["hint"]) if Global.FLAWS.has(fid) else "", 16)
		sub.modulate = Color(1, 1, 1, 0.65)
		box.add_child(sub)
		var b := UIKit.button("")
		b.pressed.connect(_on_buy.bind(id))
		box.add_child(b)
		buy_buttons[id] = b
	_msg = UIKit.label("", 18)
	box.add_child(_msg)
	back_button = UIKit.button("Quay lại")
	back_button.pressed.connect(func(): closed.emit())
	box.add_child(back_button)
	Global.gold_changed.connect(func(_g): refresh())
	refresh()


func refresh() -> void:
	gold_label.text = "Vàng: %d" % Global.gold
	for id in buy_buttons:
		var b: Button = buy_buttons[id]
		var price: int = int(Global.GOLD["prices"][id])
		if Global.owns_gun(id):
			b.text = "Đã sở hữu"
			b.disabled = true
		else:
			b.text = "Mua - %d vàng" % price
			b.disabled = Global.gold < price


func _on_buy(id: String) -> void:
	if Global.buy_gun(id):
		_msg.text = "Đã mua %s. Chọn làm súng khởi đầu ở màn Chuẩn bị." % Global.WEAPONS[id]["name"]
	else:
		_msg.text = "Không đủ vàng."
	refresh()
