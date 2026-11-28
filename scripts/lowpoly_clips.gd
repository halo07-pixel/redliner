extends RefCounted
## Thư viện clip hoạt ảnh do chính dự án dựng trong Blender (M47) cho thân bot low poly (`tools/blender/make_clips.py` -> clips.glb).
## Cùng giao diện tĩnh với ClipLib (CC0 cũ): `available / get_clip / sample / clip_names / JOINTS`, nên RigAnimator dùng được cả hai.
## Khác ClipLib: clip nằm sẵn trên các Empty trùng tên khớp proxy (cùng quy ước xoay), không cần phép chuyển xương; mỗi khung bake thêm
## góc Euler (độ, YXZ, liên tục theo khung) để overlay chiến đấu pha trộn với tư thế sinh bằng code mà không bị lật ở vai > 90°.
## Thiếu file -> `available()` = false và mọi thứ chạy như cũ (hoàn toàn bằng code).

const VisualData = preload("res://scripts/data/visual_data.gd")
const FPS: float = 30.0
const JOINTS: Array = [
	"hips", "spine", "head", "shoulder_l", "elbow_l", "hand_l", "shoulder_r", "elbow_r", "hand_r",
	"hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r",
]
## Clip lặp (glTF không mang cờ lặp). Còn lại phát một lần.
const LOOPING: Array = ["Sword_Idle", "Pistol_Idle", "Crouch_Idle", "Walk", "Jog_Fwd", "Sprint"]
## Mốc thời gian (giây) của clip Slash trong Blender: lấy đà / chém / thu về. Overlay "swing" co giãn theo windup/active/recovery của đòn.
const SLASH: Dictionary = {"windup": 0.6, "active": 0.1, "recovery": 0.6}

static var _cache: Dictionary = {}
static var _names: Array = []
static var _loaded: bool = false
static var _failed: bool = false


static func _path() -> String:
	return String(VisualData.LOWPOLY["clips"])


static func available() -> bool:
	if _failed:
		return false
	if not _loaded:
		_load()
	return not _failed


static func warm_up() -> void:
	if ResourceLoader.exists(_path()):
		ResourceLoader.load_threaded_request(_path())


static func clip_names() -> Array:
	return _names.duplicate() if available() else []


static func get_clip(clip_name: String) -> Dictionary:
	if not available():
		return {}
	return _cache.get(clip_name, {})


static func _load() -> void:
	_loaded = true
	if not bool(VisualData.LOWPOLY["enabled"]) or not ResourceLoader.exists(_path()):
		_failed = true
		return
	var ps := ResourceLoader.load(_path()) as PackedScene
	if ps == null:
		_failed = true
		return
	var scene: Node = ps.instantiate()
	var player: AnimationPlayer = null
	for n in scene.find_children("*", "AnimationPlayer", true, false):
		player = n
		break
	if player == null:
		scene.free()
		_failed = true
		return
	var hips_rest: float = 0.92
	for n in scene.find_children("hips", "Node3D", true, false):
		hips_rest = maxf((n as Node3D).position.y, 0.01)
		break
	for nm in player.get_animation_list():
		var anim: Animation = player.get_animation(nm)
		_cache[String(nm)] = _bake(anim, String(nm), hips_rest)
		_names.append(String(nm))
	scene.free()
	_failed = _cache.is_empty()


static func _bake(anim: Animation, clip_name: String, hips_rest: float) -> Dictionary:
	var rot_track: Dictionary = {}
	var pos_hips: int = -1
	for t in anim.get_track_count():
		var jn: String = String(anim.track_get_path(t)).get_slice(":", 0).get_file()
		match anim.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				rot_track[jn] = t
			Animation.TYPE_POSITION_3D:
				if jn == "hips":
					pos_hips = t
	var loop: bool = clip_name in LOOPING
	var length: float = maxf(anim.length, 0.001)   # clip lặp: khung cuối trùng khung đầu nên chỉ lấy n khung rồi quay vòng
	var n: int = maxi(2, int(round(length * FPS)) + (0 if loop else 1))
	var frames: Array = []
	var eul: Array = []
	var hips_y := PackedFloat32Array()
	var hips_z := PackedFloat32Array()
	var prev: Dictionary = {}
	for i in n:
		var tm: float = minf(float(i) / FPS, length)
		var f: Dictionary = {}
		var e: Dictionary = {}
		for j in JOINTS:
			var q: Quaternion = Quaternion.IDENTITY
			if rot_track.has(j):
				q = anim.rotation_track_interpolate(int(rot_track[j]), tm)
			f[j] = q
			e[j] = _euler(q, prev.get(j, Vector3.ZERO))
		prev = e
		frames.append(f)
		eul.append(e)
		var hp := Vector3(0.0, hips_rest, 0.0)
		if pos_hips >= 0:
			hp = anim.position_track_interpolate(pos_hips, tm)
		hips_y.append((hp.y - hips_rest) / hips_rest)
		hips_z.append(hp.z)
	return {"length": length, "fps": FPS, "n": n, "rot": frames, "eul": eul, "hips_y": hips_y, "hips_z": hips_z, "loop": loop}


## Quaternion -> Euler YXZ (độ) chọn nghiệm gần khung trước nhất (x có thể vượt ±90°, vd. vai giơ 150°).
static func _euler(q: Quaternion, prev: Vector3) -> Vector3:
	var e: Vector3 = Basis(q).get_euler()
	var cands: Array = [e, Vector3(PI - e.x, e.y + PI, e.z + PI)]
	var best := Vector3.ZERO
	var best_d: float = INF
	for c in cands:
		var cv: Vector3 = c
		var pv: Vector3 = Vector3(deg_to_rad(prev.x), deg_to_rad(prev.y), deg_to_rad(prev.z))
		cv = Vector3(_near(cv.x, pv.x), _near(cv.y, pv.y), _near(cv.z, pv.z))
		var d: float = cv.distance_to(pv)
		if d < best_d:
			best_d = d
			best = cv
	return Vector3(rad_to_deg(best.x), rad_to_deg(best.y), rad_to_deg(best.z))


static func _near(a: float, ref: float) -> float:
	return a - roundf((a - ref) / TAU) * TAU


## Lấy mẫu tại thời điểm t (giây; clip lặp tự quay vòng, clip một lần dừng ở khung cuối):
## {"rot": {khớp: Quaternion}, "eul": {khớp: Vector3 độ}, "hips_y": theo chiều cao hông, "hips_z": mét}.
static func sample(clip: Dictionary, t: float) -> Dictionary:
	var n: int = int(clip["n"])
	var len: float = maxf(float(clip["length"]), 0.001)
	var loop: bool = bool(clip["loop"])
	var tt: float = fposmod(t, len) if loop else clampf(t, 0.0, len)
	var fi: float = tt * float(clip["fps"])
	var i0: int = clampi(int(floor(fi)), 0, n - 1)
	var i1: int = (i0 + 1) % n if loop else mini(i0 + 1, n - 1)
	var fr: float = fi - floor(fi)
	var out: Dictionary = {}
	var eo: Dictionary = {}
	for j in JOINTS:
		out[j] = ((clip["rot"][i0][j]) as Quaternion).slerp((clip["rot"][i1][j]) as Quaternion, fr)
		eo[j] = ((clip["eul"][i0][j]) as Vector3).lerp((clip["eul"][i1][j]) as Vector3, fr)
	var ys: PackedFloat32Array = clip["hips_y"]
	var zs: PackedFloat32Array = clip["hips_z"]
	return {"rot": out, "eul": eo, "hips_y": lerpf(ys[i0], ys[i1], fr), "hips_z": lerpf(zs[i0], zs[i1], fr)}
