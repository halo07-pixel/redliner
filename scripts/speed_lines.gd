extends CanvasLayer
## Vệt tốc độ ở rìa màn hình khi chạy/lướt/dash/đu móc nhanh. Chỉ là hiển thị: main.gd nối Signal
## speed_changed của Player tới set_speed(). Giảm hiệu ứng thì không vẽ.

const SHADER: String = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float r = length(uv) * 1.414;
	float a = atan(uv.y, uv.x);
	float lines = hash(vec2(floor(a * 60.0), floor(TIME * 18.0)));
	float streak = step(0.72, lines) * smoothstep(0.45, 1.0, r);
	COLOR = vec4(1.0, 1.0, 1.0, streak * intensity * 0.55);
}
"""

const MIN_SPEED: float = 12.0
const MAX_SPEED: float = 26.0

var rect: ColorRect
var _mat := ShaderMaterial.new()
var intensity: float = 0.0
var _target: float = 0.0


func _ready() -> void:
	layer = 5
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	rect = ColorRect.new()
	rect.material = _mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	rect.visible = false


func set_speed(speed: float) -> void:
	_target = 0.0 if Global.reduced_fx else clampf((speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED), 0.0, 1.0)


func _process(delta: float) -> void:
	intensity = lerpf(intensity, _target, minf(1.0, 6.0 * delta))
	rect.visible = intensity > 0.02
	_mat.set_shader_parameter("intensity", intensity)
