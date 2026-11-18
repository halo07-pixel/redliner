extends Node
## Autoload "Sfx": âm thanh + nhạc tạo hoàn toàn bằng code (không cần file âm thanh).
## - Bus: Master, SFX, Music, UI (âm lượng theo Global.settings vol_*).
## - `play(tên)`: âm 2D (của người chơi / UI). `play_at(tên, vị trí)`: âm 3D giảm theo khoảng cách.
## - Bảng Global.SOUNDS: âm lượng, độ lệch pitch ngẫu nhiên, số tiếng tối đa cùng lúc.
## - Nhạc 3 lớp (calm / base / intense) chạy đồng bộ, trộn theo cường độ (`set_intensity`).
## Chỉ main.gd và UI gọi (nối Signal) — logic game không gọi trực tiếp.

const RATE: int = 22050
const BEAT: float = 0.4
const BEATS: int = 8
const LAYERS: Array = ["calm", "base", "intense"]
const LAYER_DB: Dictionary = {"calm": -14.0, "base": -12.0, "intense": -13.0}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
var _next: int = 0
var _layer_players: Dictionary = {}   # lớp -> AudioStreamPlayer
var _layer_level: Dictionary = {}     # lớp -> mức hiện tại 0..1 (đang trượt về đích)
var music_mode: String = ""           # "", "menu", "battle"
var intensity: float = 0.0
var plays: Dictionary = {}            # thống kê: tên -> số lần phát thật
var dropped: int = 0                  # số lần bị bỏ vì hết tiếng/giới hạn


func _ready() -> void:
	_ensure_buses()
	_streams["slash"] = _noise_burst(0.18, 0.6, 0.08, 0.0, 0.0)
	_streams["shot"] = _noise_burst(0.16, 0.7, 0.2, 150.0, 0.5)
	_streams["shotgun"] = _noise_burst(0.3, 0.95, 0.15, 90.0, 0.4)
	_streams["launcher"] = _sweep(0.3, 260.0, 90.0, 0.5)
	_streams["explosion"] = _noise_burst(0.7, 1.0, 0.05, 55.0, 0.6)
	_streams["sniper"] = _noise_burst(0.35, 1.0, 0.1, 70.0, 0.5)
	_streams["pickup"] = _arpeggio([660.0, 880.0, 1320.0], 0.07)
	_streams["crate"] = _noise_burst(0.18, 0.9, 0.1, 140.0, 0.3)
	_streams["step"] = _noise_burst(0.07, 0.6, 0.05, 110.0, 0.3)
	_streams["step_metal"] = _noise_burst(0.1, 0.9, 0.35, 420.0, 0.5)
	_streams["step_wood"] = _noise_burst(0.08, 0.5, 0.1, 200.0, 0.6)
	_streams["hit"] = _noise_burst(0.12, 0.4, 0.15, 90.0, 0.9)
	_streams["clash"] = _noise_burst(0.28, 0.9, 0.5, 880.0, 0.5)
	_streams["parry"] = _ping(0.4, 1320.0, 1980.0)
	_streams["hurt"] = _noise_burst(0.2, 0.3, 0.1, 140.0, 0.8)
	_streams["dash"] = _noise_burst(0.22, 0.12, 0.6, 0.0, 0.0)
	_streams["slide"] = _noise_burst(0.4, 0.1, 0.04, 70.0, 0.3)
	_streams["wall"] = _noise_burst(0.22, 0.1, 0.25, 0.0, 0.0)
	_streams["grapple"] = _sweep(0.25, 260.0, 900.0, 0.5)
	_streams["wave"] = _arpeggio([440.0, 554.4, 659.3, 880.0], 0.13)
	_streams["destabilized"] = _sweep(0.8, 420.0, 70.0, 0.7)
	_streams["recover"] = _sweep(0.3, 120.0, 500.0, 0.3)
	_streams["jump"] = _sweep(0.14, 180.0, 360.0, 0.2)
	_streams["ledge"] = _noise_burst(0.2, 0.4, 0.05, 100.0, 0.3)
	_streams["reload"] = _clicks([0.0, 0.3], 0.45, [900.0, 500.0])
	_streams["switch"] = _clicks([0.0], 0.12, [700.0])
	_streams["ui_click"] = _clicks([0.0], 0.07, [1200.0])
	_streams["bot_die"] = _sweep(0.35, 300.0, 60.0, 0.6)
	_streams["game_over"] = _sweep(1.0, 300.0, 50.0, 0.4)
	for i in int(Global.AUDIO["voices_2d"]):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for i in int(Global.AUDIO["voices_3d"]):
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = float(Global.AUDIO["unit_size"])
		p3.max_distance = float(Global.AUDIO["max_distance"])
		add_child(p3)
		_players_3d.append(p3)
	for l in LAYERS:
		var mp := AudioStreamPlayer.new()
		mp.bus = "Music"
		add_child(mp)
		_layer_players[l] = mp
		_layer_level[l] = 0.0
	Global.settings_changed.connect(_apply_volumes)
	_apply_volumes()


# ------------------------------------------------------------------ bus / âm lượng

func _ensure_buses() -> void:
	for b in Global.AUDIO_BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")


func _set_bus(bus: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


func _apply_volumes() -> void:
	_set_bus("Master", float(Global.settings["vol_master"]))
	_set_bus("SFX", float(Global.settings["vol_sfx"]))
	_set_bus("UI", float(Global.settings["vol_sfx"]))
	_set_bus("Music", float(Global.settings["vol_music"]))


## Âm lượng tuyến tính (0..1) hiện tại của một bus (0 nếu tắt tiếng).
func bus_volume(bus: String) -> float:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0 or AudioServer.is_bus_mute(idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


# ------------------------------------------------------------------ phát âm

func voices_of(sound_name: String) -> int:
	var st: Variant = _streams.get(sound_name)
	var n: int = 0
	for p in _players:
		if p.playing and p.stream == st:
			n += 1
	for p3 in _players_3d:
		if p3.playing and p3.stream == st:
			n += 1
	return n


func _can_play(sound_name: String) -> bool:
	return _streams.has(sound_name) and Global.SOUNDS.has(sound_name) \
		and voices_of(sound_name) < int(Global.SOUNDS[sound_name]["voices"])


func _setup_voice(p: Node, sound_name: String, extra_db: float) -> void:
	var def: Dictionary = Global.SOUNDS[sound_name]
	var pv: float = float(def["pitch_var"])
	p.stream = _streams[sound_name]
	p.bus = String(def["bus"])
	p.volume_db = float(def["vol_db"]) + extra_db
	p.pitch_scale = 1.0 + randf_range(-pv, pv)
	plays[sound_name] = int(plays.get(sound_name, 0)) + 1


## Âm 2D (người chơi / giao diện). Trả về player đang phát, null nếu bị bỏ.
func play(sound_name: String, extra_db: float = 0.0) -> AudioStreamPlayer:
	if not _can_play(sound_name):
		if _streams.has(sound_name):
			dropped += 1
		return null
	for i in _players.size():
		var p: AudioStreamPlayer = _players[(_next + i) % _players.size()]
		if not p.playing:
			_next = (_next + i + 1) % _players.size()
			_setup_voice(p, sound_name, extra_db)
			p.play()
			return p
	dropped += 1
	return null


## Âm 3D tại vị trí thế giới (bot, vụ nổ, vật thể).
func play_at(sound_name: String, pos: Vector3, extra_db: float = 0.0) -> AudioStreamPlayer3D:
	if not _can_play(sound_name):
		if _streams.has(sound_name):
			dropped += 1
		return null
	for p in _players_3d:
		if not p.playing:
			_setup_voice(p, sound_name, extra_db)
			p.global_position = pos
			p.play()
			return p
	dropped += 1
	return null


## Dừng mọi tiếng hiệu ứng đang phát (không đụng tới nhạc).
func stop_all() -> void:
	for p in _players:
		p.stop()
	for p3 in _players_3d:
		p3.stop()


# ------------------------------------------------------------------ nhạc động

## Cường độ 0..1 từ tình huống: số bot còn lại, tỉ lệ máu, mất thế. Hàm thuần (test được).
static func compute_intensity(enemies: int, health_ratio: float, destabilized: bool) -> float:
	var i: float = 0.1
	i += clampf(float(enemies) / float(Global.AUDIO["intensity_enemies"]), 0.0, 1.0) * 0.6
	var low: float = float(Global.AUDIO["intensity_low_hp"])
	if health_ratio < low:
		i += clampf((low - health_ratio) / low, 0.0, 1.0) * 0.25
	if destabilized:
		i += 0.1
	return clampf(i, 0.0, 1.0)


## Mức (0..1) mong muốn của từng lớp nhạc. Menu: chỉ lớp calm.
static func layer_levels(i: float, mode: String) -> Dictionary:
	if mode != "battle":
		return {"calm": 1.0 if mode == "menu" else 0.0, "base": 0.0, "intense": 0.0}
	i = clampf(i, 0.0, 1.0)
	return {
		"calm": clampf(1.0 - i * 1.6, 0.0, 1.0),
		"base": clampf(0.35 + i * 1.2, 0.0, 1.0),
		"intense": clampf((i - 0.4) / 0.5, 0.0, 1.0),
	}


func set_intensity(v: float) -> void:
	intensity = clampf(v, 0.0, 1.0)


## mode: "menu" (nhạc êm) hoặc "battle" (3 lớp theo cường độ). Cả 3 lớp bắt đầu cùng lúc để khớp nhịp.
func play_music(mode: String = "battle") -> void:
	if mode == music_mode and _layer_players["base"].playing:
		return
	for l in LAYERS:
		if not _streams.has("music_" + l):
			_streams["music_" + l] = _music_layer(l)
	music_mode = mode
	var target: Dictionary = layer_levels(intensity, mode)
	for l in LAYERS:
		var mp: AudioStreamPlayer = _layer_players[l]
		mp.stream = _streams["music_" + l]
		_layer_level[l] = float(target[l])
		_apply_layer(l)
		mp.play()


func stop_music() -> void:
	music_mode = ""
	for l in LAYERS:
		_layer_players[l].stop()


func _process(delta: float) -> void:
	if music_mode == "":
		return
	var target: Dictionary = layer_levels(intensity, music_mode)
	var step: float = delta / maxf(float(Global.AUDIO["music_fade"]), 0.01)
	for l in LAYERS:
		_layer_level[l] = move_toward(float(_layer_level[l]), float(target[l]), step)
		_apply_layer(l)


func _apply_layer(l: String) -> void:
	_layer_players[l].volume_db = float(LAYER_DB[l]) + linear_to_db(maxf(float(_layer_level[l]), 0.0001))


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


func _sweep(dur: float, hz0: float, hz1: float, noise: float) -> AudioStreamWAV:
	var n: int = int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		phase += TAU * lerpf(hz0, hz1, t) / RATE
		out[i] = (sin(phase) * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise * 0.5) * sin(PI * t) * 0.6
	return _to_stream(out)


func _arpeggio(notes: Array, note_dur: float) -> AudioStreamWAV:
	var per: int = int(RATE * note_dur)
	var out := PackedFloat32Array()
	out.resize(per * notes.size())
	for k in notes.size():
		for i in per:
			var t: float = float(i) / float(per)
			out[k * per + i] = sin(TAU * float(notes[k]) * float(i) / RATE) * exp(-4.0 * t) * 0.5
	return _to_stream(out)


## Tick ngắn (tiếng click): mỗi tick tại times[i] giây, tần số tones[i].
func _clicks(times: Array, dur: float, tones: Array) -> AudioStreamWAV:
	var n: int = int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for k in times.size():
		var start: int = int(float(times[k]) * RATE)
		for i in range(start, n):
			var t: float = float(i - start) / RATE
			if t > 0.06:
				break
			out[i] += (sin(TAU * float(tones[k]) * t) * 0.6 + (randf() * 2.0 - 1.0) * 0.4) * exp(-t * 70.0) * 0.7
	return _to_stream(out)


## Tần số làm tròn để đúng số chu kỳ nguyên trong vòng lặp (không bị "pop" khi lặp).
func _loop_hz(f: float) -> float:
	var total: float = BEAT * BEATS
	return roundf(f * total) / total


## Một lớp nhạc loop 3.2 s (8 nhịp, 150 BPM).
func _music_layer(layer: String) -> AudioStreamWAV:
	var total: float = BEAT * BEATS
	var n: int = int(RATE * total)
	var out := PackedFloat32Array()
	out.resize(n)
	var bass: Array = [55.0, 55.0, 65.4, 55.0, 73.4, 55.0, 65.4, 49.0]
	var chord: Array = [_loop_hz(110.0), _loop_hz(130.8), _loop_hz(164.8)]
	for i in n:
		var t: float = float(i) / RATE
		var b: int = int(t / BEAT)
		var bt: float = fmod(t, BEAT)
		var s: float = 0.0
		match layer:
			"calm":
				var swell: float = 0.6 + 0.4 * sin(TAU * t / total)
				for f in chord:
					s += sin(TAU * float(f) * t) * 0.14 * swell
				if b % 2 == 0:
					s += sin(TAU * _loop_hz(440.0) * bt) * exp(-bt * 6.0) * 0.08
			"base":
				if b % 2 == 0: # kick
					s += sin(TAU * (40.0 + 90.0 * exp(-bt * 28.0)) * bt) * exp(-bt * 9.0) * 0.9
				var ht: float = fmod(t, BEAT * 0.5)
				s += (randf() * 2.0 - 1.0) * exp(-ht * 70.0) * 0.12
				var f: float = bass[b % bass.size()]
				s += (fmod(t * f, 1.0) * 2.0 - 1.0) * exp(-bt * 3.0) * 0.18
			"intense":
				var ht16: float = fmod(t, BEAT * 0.25)
				s += (randf() * 2.0 - 1.0) * exp(-ht16 * 120.0) * 0.1
				if b % 2 == 1: # snare
					s += (randf() * 2.0 - 1.0) * exp(-bt * 18.0) * 0.35
				var step: int = int(t / (BEAT * 0.5))
				var lead: float = float(bass[(step / 2) % bass.size()]) * [4.0, 6.0, 8.0, 6.0][step % 4]
				s += (fmod(t * lead, 1.0) * 2.0 - 1.0) * exp(-fmod(t, BEAT * 0.5) * 8.0) * 0.1
		out[i] = s * 0.8
	var w := _to_stream(out)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w
