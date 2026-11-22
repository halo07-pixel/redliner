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
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4 and visible:
		Global.anim_debug = not Global.anim_debug   # F4 (khi F3 đang mở): hiện pha/clip hoạt ảnh viewmodel


## Dòng thông tin cho map lớn / Titan: số bot, Titan gần nhất, thời gian bake navmesh, tuning đang áp dụng.
func _game_stats() -> String:
	var tree := get_tree()
	var bots: int = tree.get_nodes_in_group("bots").size()
	var text: String = "bot %d" % bots
	var player := tree.get_first_node_in_group("player") as Node3D
	var nearest: float = INF
	for b in tree.get_nodes_in_group("bots"):
		if "is_titan" in b and not b.dead and player != null:
			nearest = minf(nearest, (b as Node3D).global_position.distance_to(player.global_position))
	if nearest < INF:
		text += " | Titan %d m" % int(nearest)
	var scene: Node = tree.current_scene
	var arena: Variant = scene.get("arena") if scene != null else null
	if arena != null and "nav_bake_ms" in arena:
		text += " | navmesh %d ms" % int(arena.nav_bake_ms)
	var n: int = Global.live_changed().size()
	if n > 0:
		text += " | tuning %d giá trị đổi" % n
	return text


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
	label.text += "\n" + _game_stats()
	if Global.anim_debug:
		label.text += "\n" + Global.anim_debug_text
