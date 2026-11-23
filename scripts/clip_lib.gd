extends RefCounted
## Thư viện clip hoạt ảnh CC0 (Quaternius Universal Animation Library) cho người que glTF (M32).
## Clip được "bake" một lần sang góc xoay cục bộ của các khớp proxy (cùng quy ước với RigAnimator/mannequin_gltf),
## nên animator chỉ việc trộn quaternion với tư thế sinh bằng code: không cần AnimationPlayer hay xương thứ hai cho từng bot.
## Thiếu asset thì `available()` = false và mọi thứ chạy như cũ (hoàn toàn bằng code).
##
## Phép chuyển (giống `mannequin_gltf._apply_pose` nhưng chiều ngược): xương UAL ở T-pose, xương GodoDude ở A-pose; cả hai quy về
## "tay chân thẳng xuống" bằng `fix`, rồi lấy phép xoay toàn cục tương đối so với tư thế gốc (D = A * rest^-1 * fix^-1) -
## không phụ thuộc hướng trục xương.

const UAL_PATH: String = "res://assets/animations/ual/UAL1_Standard.glb"
const FPS: float = 30.0
const FLIP: Basis = Basis(Vector3.UP, PI)   # model nhìn +Z, game nhìn -Z (giống mannequin_gltf._flip)
const JOINTS: Array = [
	"hips", "spine", "head", "shoulder_l", "elbow_l", "hand_l", "shoulder_r", "elbow_r", "hand_r",
	"hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r",
]
## khớp proxy -> khớp cha (cùng cây với mannequin_gltf.JOINT_TREE)
const PARENT: Dictionary = {
	"hips": "", "spine": "hips", "head": "spine",
	"shoulder_l": "spine", "elbow_l": "shoulder_l", "hand_l": "elbow_l",
	"shoulder_r": "spine", "elbow_r": "shoulder_r", "hand_r": "elbow_r",
	"hip_l": "hips", "knee_l": "hip_l", "ankle_l": "knee_l",
	"hip_r": "hips", "knee_r": "hip_r", "ankle_r": "knee_r",
}
## khớp proxy -> xương UAL
const BONE: Dictionary = {
	"hips": "pelvis", "spine": "spine_02", "head": "Head",
	"shoulder_l": "upperarm_l", "elbow_l": "lowerarm_l", "hand_l": "hand_l",
	"shoulder_r": "upperarm_r", "elbow_r": "lowerarm_r", "hand_r": "hand_r",
	"hip_l": "thigh_l", "knee_l": "calf_l", "ankle_l": "foot_l",
	"hip_r": "thigh_r", "knee_r": "calf_r", "ankle_r": "foot_r",
}
## khớp cần kéo thẳng xuống -> xương con lấy hướng (giống mannequin_gltf.STRAIGHTEN; bàn tay đi theo cẳng tay)
const STRAIGHTEN: Dictionary = {
	"shoulder_l": "lowerarm_l", "elbow_l": "hand_l", "shoulder_r": "lowerarm_r", "elbow_r": "hand_r",
	"hip_l": "calf_l", "knee_l": "foot_l", "hip_r": "calf_r", "knee_r": "foot_r",
}

const USED: Array = ["Sword_Idle", "Pistol_Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle"]
static var _loaded: bool = false
static var _names: Array = []
static var _scene: Node = null
static var _skel: Skeleton3D = null
static var _player: AnimationPlayer = null
static var _fix: Dictionary = {}          # khớp -> Basis
static var _rest_g: Dictionary = {}       # khớp -> Basis toàn cục lúc gốc (hệ xương)
static var _bone_i: Dictionary = {}       # khớp -> chỉ số xương
static var _hips_rest_y: float = 0.9
static var _cache: Dictionary = {}        # tên clip -> dữ liệu đã bake
static var _failed: bool = false


static func available() -> bool:
	if _failed:
		return false
	if not _loaded:
		if not ResourceLoader.exists(UAL_PATH):
			_failed = true
			return false
		_load()
	return not _failed


## Nạp nền (không chặn) để lần đầu dùng không giật.
static func warm_up() -> void:
	if ResourceLoader.exists(UAL_PATH):
		ResourceLoader.load_threaded_request(UAL_PATH)


static func clip_names() -> Array:
	return _names.duplicate() if available() else []


static func _load() -> void:
	var ps := ResourceLoader.load(UAL_PATH) as PackedScene
	if ps == null:
		_failed = true
		return
	_scene = ps.instantiate()
	var sk: Array = _scene.find_children("*", "Skeleton3D", true, false)
	var ap: Array = _scene.find_children("*", "AnimationPlayer", true, false)
	if sk.is_empty() or ap.is_empty():
		_failed = true
		return
	_skel = sk[0]
	_player = ap[0]
	for j in JOINTS:
		var i: int = _skel.find_bone(String(BONE[j]))
		if i < 0:
			_failed = true
			push_warning("ClipLib: thiếu xương " + String(BONE[j]))
			return
		_bone_i[j] = i
		_rest_g[j] = _skel.get_bone_global_rest(i).basis.orthonormalized()
	for j in STRAIGHTEN:
		var a: int = _bone_i[j]
		var c: int = _skel.find_bone(String(STRAIGHTEN[j]))
		var dir: Vector3 = (_skel.get_bone_global_rest(c).origin - _skel.get_bone_global_rest(a).origin).normalized()
		_fix[j] = Basis(Quaternion(dir, Vector3.DOWN))
	_fix["hand_l"] = _fix["elbow_l"]
	_fix["hand_r"] = _fix["elbow_r"]
	_hips_rest_y = _skel.get_bone_global_rest(int(_bone_i["hips"])).origin.y
	# Bake sẵn các clip đang dùng rồi giải phóng cảnh glb (không để node mồ côi trong static).
	_names = Array(_player.get_animation_list())
	for n in USED:
		if _player.has_animation(n):
			_cache[n] = _bake(n)
	_scene.free()
	_scene = null
	_skel = null
	_player = null
	_loaded = true


## Dữ liệu clip: {"length": s, "fps": f, "n": số khung, "rot": Array[khung] của Dictionary(khớp -> Quaternion), "hips_y": PackedFloat32Array
## (độ dịch hông theo chiều cao, tính theo tỉ lệ cơ thể = chiều cao hông / chiều cao hông lúc gốc), "loop": bool}.
static func get_clip(clip_name: String) -> Dictionary:
	if _cache.has(clip_name):
		return _cache[clip_name]
	if not available():
		return {}
	return _cache.get(clip_name, {})


static func _bake(clip_name: String) -> Dictionary:
	var anim: Animation = _player.get_animation(clip_name)
	var rot_track: Dictionary = {}   # tên xương -> chỉ số track xoay
	var pos_track: Dictionary = {}
	for t in anim.get_track_count():
		var bone_name: String = String(anim.track_get_path(t)).get_slice(":", 1)
		match anim.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				rot_track[bone_name] = t
			Animation.TYPE_POSITION_3D:
				pos_track[bone_name] = t
	var n: int = maxi(2, int(round(anim.length * FPS)))
	var frames: Array = []
	var hips_y := PackedFloat32Array()
	var hips_bone: String = String(BONE["hips"])
	for f in n:
		var time: float = float(f) / FPS
		# FK trên toàn bộ xương UAL: tư thế cục bộ = track nếu có, không thì tư thế gốc
		var global_cache: Dictionary = {}
		var d_world: Dictionary = {}
		for j in JOINTS:
			var g: Basis = _global_basis(_bone_i[j], anim, rot_track, time, global_cache)
			# D = A * rest^-1 * fix^-1 (phép xoay toàn cục tương đối so với tư thế "tay chân thẳng xuống")
			var fix: Basis = _fix.get(j, Basis.IDENTITY)
			var d_model: Basis = (g * (_rest_g[j] as Basis).inverse() * fix.inverse()).orthonormalized()
			d_world[j] = FLIP * d_model * FLIP.inverse()   # sang hệ game (nhìn -Z)
		# Khớp proxy: xoay cục bộ = D(cha)^-1 * D(khớp)  (quy ước proxy: cha toàn cục^-1 * toàn cục)
		var q: Dictionary = {}
		for j in JOINTS:
			var p: String = PARENT[j]
			var local: Basis = d_world[j] if p == "" else (d_world[p] as Basis).inverse() * (d_world[j] as Basis)
			q[j] = local.get_rotation_quaternion()
		frames.append(q)
		var py: float = 0.0
		if pos_track.has(hips_bone):
			# vị trí cục bộ của pelvis nằm trong hệ của xương "root" (xoay trục): đổi sang hệ xương để lấy độ cao thật
			var hb: int = _bone_i["hips"]
			var pg: Transform3D = _skel.get_bone_global_rest(_skel.get_bone_parent(hb))
			var gpos: Vector3 = pg * (anim.position_track_interpolate(int(pos_track[hips_bone]), time) as Vector3)
			py = (gpos.y - _hips_rest_y) / maxf(_hips_rest_y, 0.01)   # độ dịch theo tỉ lệ chiều cao hông lúc gốc
		hips_y.append(py)
	return {"length": anim.length, "fps": FPS, "n": n, "rot": frames, "hips_y": hips_y, "loop": anim.loop_mode != Animation.LOOP_NONE}


static func _global_basis(bone: int, anim: Animation, rot_track: Dictionary, time: float, memo: Dictionary) -> Basis:
	if memo.has(bone):
		return memo[bone]
	var bn: String = _skel.get_bone_name(bone)
	var local: Quaternion = _skel.get_bone_rest(bone).basis.get_rotation_quaternion()
	if rot_track.has(bn):
		local = anim.rotation_track_interpolate(int(rot_track[bn]), time)
	var parent: int = _skel.get_bone_parent(bone)
	var b: Basis = Basis(local) if parent < 0 else _global_basis(parent, anim, rot_track, time, memo) * Basis(local)
	memo[bone] = b
	return b


## Lấy mẫu clip tại thời điểm `t` (giây, tự lặp nếu clip lặp): trả về {"rot": {khớp -> Quaternion}, "hips_y": số (theo chiều cao)}.
static func sample(clip: Dictionary, t: float) -> Dictionary:
	var n: int = int(clip["n"])
	var len: float = maxf(float(clip["length"]), 0.001)
	var tt: float = fposmod(t, len) if bool(clip["loop"]) else clampf(t, 0.0, len)
	var fi: float = tt * float(clip["fps"])
	var i0: int = clampi(int(floor(fi)), 0, n - 1)
	var i1: int = (i0 + 1) % n if bool(clip["loop"]) else mini(i0 + 1, n - 1)
	var fr: float = fi - floor(fi)
	var a: Dictionary = clip["rot"][i0]
	var b: Dictionary = clip["rot"][i1]
	var out: Dictionary = {}
	for j in JOINTS:
		out[j] = (a[j] as Quaternion).slerp(b[j] as Quaternion, fr)
	var ys: PackedFloat32Array = clip["hips_y"]
	return {"rot": out, "hips_y": lerpf(ys[i0], ys[i1], fr)}
