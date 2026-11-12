extends Node3D
## Hình ảnh thanh kiếm cầm tay (chỉ là hiệu ứng, không ảnh hưởng vật lý). Player nối Signal của
## MeleeHitbox/Parry tới play_swing()/raise().

const REST := Vector3(-15.0, 10.0, -25.0)

var _tween: Tween


func _ready() -> void:
	rotation_degrees = REST


func play_swing(windup: float, active: float, recovery: float) -> void:
	_restart()
	_tween.tween_property(self, "rotation_degrees", Vector3(-70.0, 40.0, -25.0), windup)
	_tween.tween_property(self, "rotation_degrees", Vector3(20.0, -60.0, -25.0), active)
	_tween.tween_property(self, "rotation_degrees", REST, recovery)


func raise() -> void:
	_restart()
	_tween.tween_property(self, "rotation_degrees", Vector3(-85.0, 0.0, 0.0), 0.05)
	_tween.tween_interval(Global.COMBAT["parry_window"])
	_tween.tween_property(self, "rotation_degrees", REST, 0.15)


func _restart() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
