extends CanvasLayer
## HUD: tâm ngắm, tốc độ, trạng thái, dash, thanh máu, đạn, thông báo. KHÔNG tự đi tìm Player —
## main.gd nối Signal của Player/Combat -> các hàm set_*/flash (call down, signal up).

var _speed_label: Label
var _state_label: Label
var _dash_label: Label
var _health_bar: ProgressBar
var _health_label: Label
var _ammo_label: Label
var _flash_label: Label
var _death_label: Label
var _score_label: Label
var _wave_label: Label
var _inst_bar: ProgressBar
var _inst_label: Label
var _inst_fill: StyleBoxFlat
var _vignette_red: TextureRect
var _vignette_orange: TextureRect
var _hit_marker: Control
var _parry_ring: Control
var _damage_tween: Tween
var _marker_tween: Tween
var _low_health: bool = false
var _redline: bool = false
var _reloading: bool = false
var _ammo_cur: int = 0
var _ammo_max: int = 0
var _flash_tween: Tween


func _ready() -> void:
	_vignette_red = _make_vignette(Color(0.9, 0.05, 0.05))
	_vignette_orange = _make_vignette(Color(1.0, 0.5, 0.05))
	add_child(_vignette_red)
	add_child(_vignette_orange)

	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline(cross, 22)
	add_child(cross)

	_speed_label = _make_label(Vector2(20.0, 16.0))
	_state_label = _make_label(Vector2(20.0, 44.0))
	_dash_label = _make_label(Vector2(20.0, 72.0))

	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_health_bar.anchor_top = 1.0
	_health_bar.anchor_bottom = 1.0
	_health_bar.offset_left = 20.0
	_health_bar.offset_right = 340.0
	_health_bar.offset_top = -52.0
	_health_bar.offset_bottom = -26.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.15, 0.15)
	_health_bar.add_theme_stylebox_override("fill", fill)
	add_child(_health_bar)
	_health_label = Label.new()
	_health_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(_health_label, 16)
	_health_bar.add_child(_health_label)

	_ammo_label = Label.new()
	_ammo_label.anchor_left = 1.0
	_ammo_label.anchor_right = 1.0
	_ammo_label.anchor_top = 1.0
	_ammo_label.anchor_bottom = 1.0
	_ammo_label.offset_left = -240.0
	_ammo_label.offset_right = -24.0
	_ammo_label.offset_top = -56.0
	_ammo_label.offset_bottom = -20.0
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_outline(_ammo_label, 26)
	add_child(_ammo_label)

	_flash_label = Label.new()
	_flash_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_label.offset_top = -120.0
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_flash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_label.modulate.a = 0.0
	_outline(_flash_label, 40)
	add_child(_flash_label)

	_death_label = Label.new()
	_death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_label.text = "BẠN ĐÃ CHẾT"
	_death_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	_outline(_death_label, 64)
	_death_label.visible = false
	add_child(_death_label)

	_score_label = Label.new()
	_score_label.anchor_left = 1.0
	_score_label.anchor_right = 1.0
	_score_label.offset_left = -360.0
	_score_label.offset_right = -24.0
	_score_label.offset_top = 16.0
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_outline(_score_label, 22)
	add_child(_score_label)

	_wave_label = Label.new()
	_wave_label.anchor_left = 0.5
	_wave_label.anchor_right = 0.5
	_wave_label.offset_left = -200.0
	_wave_label.offset_right = 200.0
	_wave_label.offset_top = 16.0
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(_wave_label, 22)
	add_child(_wave_label)

	_inst_bar = ProgressBar.new()
	_inst_bar.show_percentage = false
	_inst_bar.anchor_top = 1.0
	_inst_bar.anchor_bottom = 1.0
	_inst_bar.offset_left = 20.0
	_inst_bar.offset_right = 340.0
	_inst_bar.offset_top = -82.0
	_inst_bar.offset_bottom = -60.0
	_inst_fill = StyleBoxFlat.new()
	_inst_fill.bg_color = Color(0.95, 0.7, 0.1)
	_inst_bar.add_theme_stylebox_override("fill", _inst_fill)
	add_child(_inst_bar)
	_inst_label = Label.new()
	_inst_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inst_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inst_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(_inst_label, 14)
	_inst_bar.add_child(_inst_label)

	_hit_marker = HitMarker.new()
	_hit_marker.set_anchors_preset(Control.PRESET_CENTER)
	_hit_marker.offset_left = -150.0
	_hit_marker.offset_right = 150.0
	_hit_marker.offset_top = -150.0
	_hit_marker.offset_bottom = 150.0
	_hit_marker.pivot_offset = Vector2(150.0, 150.0)
	_hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_marker.modulate.a = 0.0
	add_child(_hit_marker)

	_parry_ring = ParryRing.new()
	_parry_ring.set_anchors_preset(Control.PRESET_CENTER)
	_parry_ring.offset_left = -30.0
	_parry_ring.offset_right = 30.0
	_parry_ring.offset_top = -30.0
	_parry_ring.offset_bottom = 30.0
	_parry_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_parry_ring)

	set_instability(0.0, 100.0)
	set_score(0, 0, 0)
	set_wave(0, 0)
	set_speed(0.0)
	set_state("NORMAL")
	set_dash(2, 2)
	set_health(100.0, 100.0)
	set_ammo(6, 6)


func set_speed(speed: float) -> void:
	_speed_label.text = "Speed: %.1f m/s" % speed


func set_state(state_name: String) -> void:
	_state_label.text = "State: %s" % state_name


func set_dash(charges: int, max_charges: int) -> void:
	_dash_label.text = "Dash: " + "[#]".repeat(charges) + "[ ]".repeat(max_charges - charges)


func set_health(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%d / %d" % [roundi(current), roundi(maximum)]
	_low_health = current / maxf(maximum, 1.0) < 0.3 and current > 0.0
	_refresh_vignettes()


func set_ammo(current: int, maximum: int) -> void:
	_ammo_cur = current
	_ammo_max = maximum
	_refresh_ammo()


func set_reloading(on: bool) -> void:
	_reloading = on
	_refresh_ammo()


func _refresh_ammo() -> void:
	_ammo_label.text = "Ammo %d / %d" % [_ammo_cur, _ammo_max] + ("  (nạp...)" if _reloading else "")


func set_instability(value: float, maximum: float) -> void:
	_inst_bar.max_value = maximum
	_inst_bar.value = value
	_inst_label.text = "REDLINE!" if _redline else "INSTABILITY"


func set_redline(on: bool) -> void:
	_redline = on
	_inst_fill.bg_color = Color(1.0, 0.25, 0.1) if on else Color(0.95, 0.7, 0.1)
	_inst_label.text = "REDLINE!" if on else "INSTABILITY"
	_refresh_vignettes()


func set_parry(ratio: float) -> void:
	_parry_ring.ratio = ratio
	_parry_ring.queue_redraw()


## Nháy đỏ viền màn hình khi bị đánh.
func flash_damage() -> void:
	_vignette_red.modulate.a = 0.9
	if _damage_tween != null and _damage_tween.is_valid():
		_damage_tween.kill()
	_damage_tween = create_tween()
	_damage_tween.tween_property(_vignette_red, "modulate:a", 0.45 if _low_health else 0.0, 0.5)


## Mũi tên đỏ chỉ hướng nguồn đòn: angle = 0 phía trước, dương = bên phải (radian).
func show_hit_indicator(angle: float) -> void:
	_hit_marker.rotation = angle
	_hit_marker.modulate.a = 1.0
	if _marker_tween != null and _marker_tween.is_valid():
		_marker_tween.kill()
	_marker_tween = create_tween()
	_marker_tween.tween_interval(0.3)
	_marker_tween.tween_property(_hit_marker, "modulate:a", 0.0, 0.6)


func _refresh_vignettes() -> void:
	_vignette_red.modulate.a = 0.45 if _low_health else 0.0
	_vignette_orange.modulate.a = 0.4 if _redline else 0.0


func _make_vignette(color: Color) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.55, 1.0])
	g.colors = PackedColorArray([Color(color, 0.0), Color(color, 0.9)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate.a = 0.0
	return tr


func set_score(score: int, combo: int, best: int) -> void:
	var t: String = "Điểm: %d" % score
	if combo > 1:
		t += "   Combo x%d" % combo
	t += "\nCao nhất: %d" % best
	_score_label.text = t


func set_wave(wave: int, left: int) -> void:
	_wave_label.text = "WAVE %d  -  còn %d bot" % [wave, left] if wave > 0 else "Chuẩn bị..."


func show_death(on: bool) -> void:
	_death_label.visible = on


## Dòng chữ lớn giữa màn hình, mờ dần (ví dụ "PARRY!").
func flash(text: String, color: Color = Color.WHITE) -> void:
	_flash_label.text = text
	_flash_label.add_theme_color_override("font_color", color)
	_flash_label.modulate.a = 1.0
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.25)
	_flash_tween.tween_property(_flash_label, "modulate:a", 0.0, 0.4)


func _make_label(pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	_outline(l, 18)
	add_child(l)
	return l


func _outline(l: Label, font_size: int) -> void:
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)


## Mũi tên chỉ hướng nguồn sát thương, vẽ ở vòng quanh tâm ngắm.
class HitMarker extends Control:
	func _draw() -> void:
		var c := Vector2(150.0, 150.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -130.0), c + Vector2(-16.0, -100.0), c + Vector2(16.0, -100.0)]), Color(1.0, 0.1, 0.1))


## Vòng parry quanh tâm ngắm: đầy = sẵn sàng, đang hồi thì vẽ phần đã hồi.
class ParryRing extends Control:
	var ratio: float = 1.0

	func _draw() -> void:
		var c := size * 0.5
		if ratio >= 1.0:
			draw_arc(c, 24.0, 0.0, TAU, 48, Color(0.4, 0.85, 1.0, 0.55), 2.0)
		else:
			draw_arc(c, 24.0, 0.0, TAU, 48, Color(0.4, 0.4, 0.4, 0.35), 2.0)
			draw_arc(c, 24.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 48, Color(0.9, 0.3, 0.3, 0.9), 3.0)
