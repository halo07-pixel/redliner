extends Node
## Autoload "Global": hằng số layer vật lý, BẢNG SỐ CÂN BẰNG (chỉnh tại đây), input map tạo bằng code.

# Bit collision layer (khớp [layer_names] trong project.godot)
const L_WORLD: int = 1
const L_PLAYER: int = 2
const L_ENEMY: int = 4
const L_PROJECTILE: int = 8

## Số di chuyển của người chơi. Không có trần tốc độ: chỉ có "wish speed" (tốc độ đi bộ)
## và ma sát mặt đất — động lượng vượt quá wish speed được giữ nguyên trên không.
const PLAYER: Dictionary = {
	"walk_speed": 9.0,       # m/s, tốc độ đích khi đi bộ
	"ground_accel": 100.0,   # m/s² trên mặt đất (đủ lớn để đạt đúng walk_speed dù có ma sát)
	"ground_friction": 8.0,  # hệ số hãm trên mặt đất
	"stop_speed": 3.0,       # dưới ngưỡng này ma sát hãm tuyến tính, dừng dứt khoát
	"air_accel": 18.0,       # m/s² trên không (cho phép air-strafe cộng thêm tốc độ)
	"gravity": 24.0,         # m/s²
	"jump_velocity": 9.0,    # m/s, nhảy cao ~1.7m
	"mouse_sens": 0.0022,    # rad/pixel
}


func _ready() -> void:
	_setup_input()


func _setup_input() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_forward", KEY_UP)
	_add_key("move_back", KEY_S)
	_add_key("move_back", KEY_DOWN)
	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT)
	_add_key("jump", KEY_SPACE)


func _add_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
