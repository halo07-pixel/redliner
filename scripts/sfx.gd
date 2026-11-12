extends Node
## Autoload "Sfx": âm thanh tạo hoàn toàn bằng code (không cần file âm thanh).
## Chỉ được gọi từ main.gd (nối Signal) — logic game không gọi trực tiếp.

const RATE: int = 22050

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	_streams["slash"] = _noise_burst(0.18, 0.6, 0.08, 0.0, 0.0)
	_streams["shot"] = _noise_burst(0.16, 0.7, 0.2, 150.0, 0.5)
	_streams["hit"] = _noise_burst(0.12, 0.4, 0.15, 90.0, 0.9)
	_streams["clash"] = _noise_burst(0.28, 0.9, 0.5, 880.0, 0.5)
	_streams["parry"] = _ping(0.4, 1320.0, 1980.0)
	_streams["hurt"] = _noise_burst(0.2, 0.3, 0.1, 140.0, 0.8)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound_name: String, volume_db: float = -6.0) -> void:
	if not _streams.has(sound_name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound_name]
	p.volume_db = volume_db
	p.play()


func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Nhiễu lọc thông thấp (alpha_start -> alpha_end) + sóng sin tuỳ chọn, phủ envelope giảm dần.
func _noise_burst(dur: float, alpha_start: float, alpha_end: float, tone_hz: float, tone_mix: float) -> AudioStreamWAV:
	var n: int = int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		lp += ((randf() * 2.0 - 1.0) - lp) * lerpf(alpha_start, alpha_end, t)
		var env: float = pow(1.0 - t, 2.0)
		var s: float = lp * (1.0 - tone_mix)
		if tone_hz > 0.0:
			s += sin(TAU * tone_hz * (1.0 - 0.4 * t) * float(i) / RATE) * tone_mix
		out[i] = s * env
	return _to_stream(out)


func _ping(dur: float, hz1: float, hz2: float) -> AudioStreamWAV:
	var n: int = int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / float(n)
		var ph: float = float(i) / RATE
		out[i] = (sin(TAU * hz1 * ph) + 0.5 * sin(TAU * hz2 * ph)) * exp(-6.0 * t) * 0.5
	return _to_stream(out)
