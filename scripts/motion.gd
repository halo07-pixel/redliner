extends RefCounted
## Hàm chuyển động mượt dùng chung (M26): lò xo tắt dần tới hạn (smooth damp) giữ vận tốc liên tục.
## Khác lerp mũ: khi đích đổi đột ngột thì vận tốc đổi từ từ, không "giật" ở khung đầu tiên.


## Trả về Vector2(giá trị mới, vận tốc mới). smooth_time ~ thời gian gần tới đích (giây).
static func damp(cur: float, target: float, vel: float, smooth_time: float, dt: float) -> Vector2:
	var st: float = maxf(smooth_time, 0.0001)
	var omega: float = 2.0 / st
	var x: float = omega * dt
	var e: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: float = cur - target
	var temp: float = (vel + omega * change) * dt
	var v: float = (vel - omega * temp) * e
	return Vector2(target + (change + temp) * e, v)


## Số khung có gia tốc đổi đột ngột (|sai phân bậc hai| > ngưỡng) trong một chuỗi mẫu; dùng để đo "độ giật".
static func pops(samples: PackedFloat32Array, threshold: float) -> int:
	var n: int = 0
	for i in range(2, samples.size()):
		var d2: float = samples[i] - 2.0 * samples[i - 1] + samples[i - 2]
		if absf(d2) > threshold:
			n += 1
	return n
