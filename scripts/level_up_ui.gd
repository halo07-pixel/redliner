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


## Màu + nhãn theo nhóm thẻ (viền, thanh trên, chip nhóm).
const CATS: Dictionary = {
	"gun": {"label": "SÚNG", "color": Color(1.0, 0.45, 0.25)},
	"survive": {"label": "SINH TỒN", "color": Color(0.4, 0.9, 0.45)},
	"util": {"label": "TIỆN ÍCH", "color": Color(0.4, 0.8, 1.0)},
	"sword": {"label": "KIẾM", "color": Color(0.85, 0.5, 1.0)},
}
const CARD_SIZE := Vector2(270.0, 360.0)


## Chữ hiệu ứng một bậc: "+12%" (mult) hoặc "+15" (add), theo dữ liệu thẻ.
static func effect_text(c: Dictionary, tier: int) -> String:
	if c.has("effect"):
		return String(c["effect"])
	var v: float = float(c["per"]) * tier
	var sign_s: String = "-" if v < 0.0 else "+"
	v = absf(v)
	if c["kind"] == "mult":
		return "%s%d%%" % [sign_s, roundi(v * 100.0)]
	return sign_s + (str(snappedf(v, 0.1)) if v != floorf(v) else str(int(v)))


## Hiện màn với danh sách thẻ (từ Upgrades.draw); `level` để hiện tiêu đề. Thẻ trượt vào lần lượt; rê chuột thì nở ra.
func open(level: int, choices: Array) -> void:
	cards = choices
	_title.text = "LÊN CẤP %d" % level
	for b in card_buttons:
		b.queue_free()
	card_buttons.clear()
	for i in choices.size():
		var c: Dictionary = choices[i]
		var cat: Dictionary = CATS.get(String(c.get("cat", "util")), CATS["util"])
		var col: Color = cat["color"]
		var b := Button.new()
		b.custom_minimum_size = CARD_SIZE
		b.pivot_offset = CARD_SIZE * 0.5
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 20)
		var tier: int = int(c["tier"])
		var pips: String = "●".repeat(tier) + "○".repeat(int(c["max"]) - tier)
		var gain: String = effect_text(c, tier - 1) + "  →  " + effect_text(c, tier) if tier > 1 else effect_text(c, tier)
		b.text = "%s\n\n%s\n\n%s\nBậc %d / %d\n\n%s\n\n[%d]" % [cat["label"], String(c["name"]).to_upper(), pips, tier, c["max"], gain + "\n" + c["desc"], i + 1]
		b.add_theme_stylebox_override("normal", _card_style(col, 0.0))
		b.add_theme_stylebox_override("hover", _card_style(col, 1.0))
		b.add_theme_stylebox_override("pressed", _card_style(col, 1.0))
		b.add_theme_stylebox_override("focus", _card_style(col, 1.0))
		b.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		var id: String = c["id"]
		b.pressed.connect(func(): card_chosen.emit(id))
		b.mouse_entered.connect(func(): _pop(b, 1.07))
		b.mouse_exited.connect(func(): _pop(b, 1.0))
		b.focus_entered.connect(func(): _pop(b, 1.07))
		b.focus_exited.connect(func(): _pop(b, 1.0))
		_row.add_child(b)
		card_buttons.append(b)
		# Hiện dần + trượt lên, lần lượt từng thẻ (tween chạy cả khi game pause).
		b.modulate.a = 0.0
		b.scale = Vector2(0.9, 0.9)
		var tw := b.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		tw.tween_property(b, "modulate:a", 1.0, 0.25).set_delay(0.08 * i)
		tw.tween_property(b, "scale", Vector2.ONE, 0.25).set_delay(0.08 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	visible = true


func _pop(b: Button, k: float) -> void:
	if not is_instance_valid(b):
		return
	var tw := b.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(b, "scale", Vector2(k, k), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _card_style(col: Color, glow: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.96).lerp(col, 0.08 + 0.12 * glow)
	sb.border_color = col.lerp(Color.WHITE, 0.35 * glow)
	sb.set_border_width_all(3)
	sb.border_width_top = 10
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(col.r, col.g, col.b, 0.55 * glow)
	sb.shadow_size = int(26 * glow)
	return sb


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
