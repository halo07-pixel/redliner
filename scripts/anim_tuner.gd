extends CanvasLayer
## Bộ chỉnh cảm giác hoạt ảnh trong game (M20). Mở: F3 (lớp phủ hiệu năng) rồi F4. Thanh trượt đổi tức thì các hằng số
## trong Global.VIEWMODEL / Global.ANIM (qua Global.tune, không sửa hằng số gốc); đường cong kiếm vẽ ở đáy.
## "Xuất" chép các giá trị đã đổi (dạng `khoá = giá trị`) vào clipboard + `user://anim_tuning.txt` để gửi lại và chốt vào Global.
## Chỉ hiển thị khi Global.anim_debug bật; mở thì thả chuột, đóng thì trả lại như cũ.

const OUT_PATH: String = "user://anim_tuning.txt"

var panel: PanelContainer
var graph: Control
var _rows: Dictionary = {}       # khoá đầy đủ ("v.x"/"a.x") -> {slider, label, default}
var _shown: bool = false
var _took_mouse: bool = false
var _prev_mode: int = Input.MOUSE_MODE_CAPTURED
var status: Label


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.custom_minimum_size = Vector2(360.0, 0.0)
	panel.offset_left = -370.0
	panel.offset_top = 40.0
	panel.offset_bottom = -10.0
	add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	var title := Label.new()
	title.text = "CHỈNH HOẠT ẢNH (F4 đóng)"
	col.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_add_header(list, "-- Hoạt ảnh tay / súng --")
	for k in Global.TUNABLE_VM:
		_add_row(list, "v." + String(k), float(Global.VIEWMODEL[k]))
	_add_header(list, "-- Camera / thân --")
	for k in Global.TUNABLE_ANIM:
		_add_row(list, "a." + String(k), float(Global.ANIM[k]))
	var heads: Dictionary = {"m": "-- Chuyển động chung (camera, nghiêng) --", "p": "-- Người chơi / Grapple --", "b": "-- Di chuyển bot --", "t": "-- Titan --"}
	for g in Global.TUNABLE_LIVE:
		_add_header(list, heads[g])
		for k in Global.TUNABLE_LIVE[g]:
			_add_row(list, "%s.%s" % [g, k], Global.live_default(g, k))
	graph = Control.new()
	graph.custom_minimum_size = Vector2(0.0, 110.0)
	graph.draw.connect(_draw_graph)
	col.add_child(graph)
	var btns := HBoxContainer.new()
	col.add_child(btns)
	var export_btn := Button.new()
	export_btn.text = "Xuất"
	export_btn.pressed.connect(export_changes)
	btns.add_child(export_btn)
	var save_btn := Button.new()
	save_btn.text = "Lưu"
	save_btn.pressed.connect(save_live)
	btns.add_child(save_btn)
	for mp in ["smooth", "fast"]:
		var mb := Button.new()
		mb.text = "Chuyển động " + {"smooth": "mượt", "fast": "nhanh"}[mp]
		mb.pressed.connect(func(): apply_motion_preset(mp))
		btns.add_child(mb)
	for pr in ["easy", "normal", "hard"]:
		var pb := Button.new()
		pb.text = "Titan " + {"easy": "dễ", "normal": "thường", "hard": "khó"}[pr]
		pb.pressed.connect(func(): apply_titan_preset(pr))
		btns.add_child(pb)
	var reset_btn := Button.new()
	reset_btn.text = "Đặt lại"
	reset_btn.pressed.connect(reset_all)
	btns.add_child(reset_btn)
	status = Label.new()
	status.text = ""
	col.add_child(status)
	panel.visible = false


func _add_header(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	parent.add_child(l)


func _add_row(parent: Control, key: String, default: float) -> void:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = "%s = %s" % [key, _fmt(default)]
	row.add_child(label)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = maxf(absf(default) * 3.0, 1.0)
	sl.step = maxf(absf(default) / 200.0, 0.001)
	sl.value = default
	sl.custom_minimum_size = Vector2(300.0, 16.0)
	sl.value_changed.connect(func(v: float): set_value(key, v))
	row.add_child(sl)
	parent.add_child(row)
	_rows[key] = {"slider": sl, "label": label, "default": default}


func _fmt(v: float) -> String:
	return "%.3f" % v if absf(v) < 10.0 else "%.1f" % v


## Đổi một giá trị lúc chơi (ghi vào Global.tune). Trả về false nếu khoá không có.
func set_value(key: String, v: float) -> bool:
	if not _rows.has(key):
		return false
	var row: Dictionary = _rows[key]
	var changed: bool = not is_equal_approx(v, float(row["default"]))
	if _is_live(key):
		var parts: PackedStringArray = key.split(".")
		Global.set_live(parts[0], parts[1], v)
	elif not changed:
		Global.tune.erase(key)
	else:
		Global.tune[key] = v
	(row["label"] as Label).text = "%s = %s%s" % [key, _fmt(v), "  *" if changed else ""]
	return true


func _is_live(key: String) -> bool:
	return key.length() > 2 and key[1] == "." and Global.LIVE_GROUPS.has(key[0])


## Đặt thanh trượt theo giá trị hiện tại của Global (sau khi nạp preset / đặt lại).
func _sync_live_rows() -> void:
	for k in _rows:
		if not _is_live(k):
			continue
		var parts: PackedStringArray = (k as String).split(".")
		var v: float = float(Global.live_dict(parts[0])[parts[1]])
		var row: Dictionary = _rows[k]
		(row["slider"] as HSlider).set_value_no_signal(v)
		(row["label"] as Label).text = "%s = %s%s" % [k, _fmt(v), "" if is_equal_approx(v, float(row["default"])) else "  *"]


func apply_titan_preset(preset: String) -> void:
	if Global.apply_titan_preset(preset):
		_sync_live_rows()
		status.text = "Titan: " + preset


func apply_motion_preset(preset: String) -> void:
	if Global.apply_motion_preset(preset):
		_sync_live_rows()
		status.text = "Chuyển động: " + preset


func save_live() -> void:
	var n: int = Global.save_live()
	status.text = "Đã lưu %d giá trị vào %s" % [n, Global.LIVE_PATH]


## Văn bản các giá trị đã đổi so với mặc định, mỗi dòng `khoá = giá trị`.
func export_text() -> String:
	var lines: PackedStringArray = []
	for k in _rows:
		if Global.tune.has(k):
			lines.append("%s = %s" % [k, _fmt(float(Global.tune[k]))])
	var live: Dictionary = Global.live_changed()
	for id in live:
		lines.append("%s = %s" % [id, _fmt(float(live[id]))])
	return "\n".join(lines)


func export_changes() -> void:
	var text: String = export_text()
	if text == "":
		text = "(chưa đổi gì)"
	DisplayServer.clipboard_set(text)
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
	print("[anim_tuner]\n", text)
	status.text = "Đã chép vào clipboard + %s" % OUT_PATH


func reset_all() -> void:
	Global.tune.clear()
	Global.reset_live()
	for k in _rows:
		var row: Dictionary = _rows[k]
		(row["slider"] as HSlider).set_value_no_signal(float(row["default"]))
		(row["label"] as Label).text = "%s = %s" % [k, _fmt(float(row["default"]))]
	status.text = "Đã đặt lại mặc định"


func _draw_graph() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, graph.size)
	graph.draw_rect(r, Color(0.0, 0.0, 0.0, 0.5))
	var smp: PackedFloat32Array = Global.anim_debug_samples
	var n: int = smp.size() / 2
	if n < 2:
		return
	for ch in 2:
		var pts := PackedVector2Array()
		for i in n:
			var v: float = clampf(smp[i * 2 + ch], 0.0, 1.5) / 1.5
			pts.append(Vector2(r.size.x * float(i) / float(n - 1), r.size.y * (1.0 - v)))
		graph.draw_polyline(pts, Color(0.4, 0.9, 1.0) if ch == 0 else Color(1.0, 0.7, 0.3), 1.5)
	graph.draw_string(ThemeDB.fallback_font, Vector2(4.0, 14.0), "kiếm: lệch vị trí (xanh) / góc (cam)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)


func _process(_delta: float) -> void:
	var want: bool = Global.anim_debug
	if want != _shown:
		_shown = want
		panel.visible = want
		if want:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				_prev_mode = Input.mouse_mode
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_took_mouse = true
		elif _took_mouse:
			Input.mouse_mode = _prev_mode
			_took_mouse = false
	if _shown:
		graph.queue_redraw()
