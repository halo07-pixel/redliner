extends CanvasLayer
## Màn chọn nâng cấp khi lên cấp: 3 thẻ + nút Bỏ qua (hồi máu). Chạy khi game đang pause (process_mode ALWAYS).
## Chỉ phát Signal; không biết người chơi hay tiến trình. Phím 1/2/3 chọn thẻ, 4 bỏ qua.

signal card_chosen(id: String)
signal skipped

const UIKit = preload("res://scripts/ui_kit.gd")

var cards: Array = []
var card_buttons: Array = []
var skip_button: Button
var _title: Label
var _row: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	add_child(dim)
	var box := UIKit.center_box(dim, 22)
	_title = UIKit.title("LÊN CẤP", 64, Color(0.4, 0.9, 1.0))
	box.add_child(_title)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 18)
	box.add_child(_row)
	skip_button = UIKit.button("Bỏ qua (hồi máu)  [4]")
	box.add_child(skip_button)
	skip_button.pressed.connect(func(): skipped.emit())


## Hiện màn với danh sách thẻ (từ Upgrades.draw); `level` để hiện tiêu đề.
func open(level: int, choices: Array) -> void:
	cards = choices
	_title.text = "LÊN CẤP %d" % level
	for b in card_buttons:
		b.queue_free()
	card_buttons.clear()
	for i in choices.size():
		var c: Dictionary = choices[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(250.0, 150.0)
		b.text = "[%d]  %s\nBậc %d / %d\n\n%s" % [i + 1, c["name"], c["tier"], c["max"], c["desc"]]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 20)
		var id: String = c["id"]
		b.pressed.connect(func(): card_chosen.emit(id))
		_row.add_child(b)
		card_buttons.append(b)
	visible = true


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var idx: int = int(event.keycode) - KEY_1
	if idx >= 0 and idx < cards.size():
		card_chosen.emit(String(cards[idx]["id"]))
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_4:
		skipped.emit()
		get_viewport().set_input_as_handled()
