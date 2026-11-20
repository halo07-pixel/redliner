extends CanvasLayer
## Hiển thị FPS / thời gian khung / số node. Bật tắt bằng phím F3 (mặc định tắt).

const REFRESH: float = 0.5

var label: Label
var _acc: float = 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	label = Label.new()
	label.position = Vector2(12.0, 120.0)
	label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	visible = false


func toggle() -> void:
	visible = not visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		toggle()


func _process(delta: float) -> void:
	if not visible:
		return
	_acc += delta
	if _acc < REFRESH:
		return
	_acc = 0.0
	label.text = "FPS %d | %.1f ms | node %d | v%s" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		Global.VERSION,
	]
