extends Node3D
## Nhân vật dựng từ model glTF (KayKit Adventurers, CC0) — cùng API với `mannequin.gd`:
## `color`, `kind`, `animate()`, `play()`, `clear_overlay()`, `flash()`, `fade_out()`, `set_render_layers()`, `weapon`.
## Hoạt ảnh lấy từ AnimationPlayer của model; trượt/lướt/chạy tường/móc dùng clip gần nhất + nghiêng thân bằng code.
## Dùng `MannequinGltf.has_asset(kind)` để biết có model hay không; nếu không có, chủ nhân dùng mannequin.gd.

const HEIGHT: float = 1.8
## kind -> {file, weapon (node ở handslot_r được giữ lại)}
const ASSETS: Dictionary = {
	"swordsman": {"file": "res://assets/characters/kaykit/Knight.glb", "weapon": "1H_Sword"},
	"elite": {"file": "res://assets/characters/kaykit/Barbarian.glb", "weapon": "1H_Axe"},
	"gunner": {"file": "res://assets/characters/kaykit/Rogue_Hooded.glb", "weapon": "1H_Crossbow"},
}
const LOOPED: Array = ["Idle", "Running_A", "Jump_Idle", "Walking_A"]
## overlay -> clip (không loop; chạy hết thời lượng yêu cầu rồi quay lại di chuyển)
const OVERLAY_CLIPS: Dictionary = {
	"swing": "1H_Melee_Attack_Slice_Diagonal",
	"shoot": "1H_Ranged_Shoot",
	"parry": "Block",
	"parry_miss": "Block_Hit",
	"hurt": "Hit_A",
	"stagger": "Hit_B",
	"die": "Death_A",
}
const PRIORITY: Dictionary = {"die": 3, "stagger": 2}  # còn lại = 1; overlay thấp không ngắt overlay cao đang chạy
const LOCO_CLIPS: Dictionary = {
	"idle": "Idle", "run": "Running_A", "air": "Jump_Idle",
	"slide": "Dodge_Forward", "dash": "Dodge_Forward", "wallrun": "Running_B", "grapple": "Jump_Idle",
}

@export var color: Color = Color(0.85, 0.85, 0.9)
var kind: String = "swordsman"

var joints: Dictionary = {}  # để trống: khung xương nằm trong model
var weapon: Node3D
var player: AnimationPlayer
var model: Node3D
var _mats: Array = []
var _overlay: String = ""
var _overlay_left: float = 0.0
var _dead: bool = false
var _loco: String = ""


static func has_asset(k: String) -> bool:
	return ASSETS.has(k) and ResourceLoader.exists(String(ASSETS[k]["file"]))


func _ready() -> void:
	var cfg: Dictionary = ASSETS.get(kind, ASSETS["swordsman"])
	var scene: PackedScene = load(String(cfg["file"]))
	model = scene.instantiate()
	add_child(model)
	_prepare_attachments(String(cfg["weapon"]))
	_fit_height()
	_prepare_materials()
	player = model.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in LOOPED:
		if player.has_animation(clip):
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_set_loco("idle")


func _prepare_attachments(keep_weapon: String) -> void:
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	for c in sk.get_children():
		if not (c is BoneAttachment3D):
			continue
		for m in c.get_children():
			var is_weapon: bool = c.name == &"handslot_r" and String(m.name) == keep_weapon
			var is_gear: bool = c.name in [&"head", &"chest"]  # mũ, áo choàng giữ lại
			(m as Node3D).visible = is_weapon or is_gear
			if is_weapon:
				weapon = m


func _fit_height() -> void:
	var top: float = -1e9
	var bottom: float = 1e9
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if not (mi as Node).get_parent() is Skeleton3D:
			continue
		var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		top = maxf(top, a.end.y)
		bottom = minf(bottom, a.position.y)
	if top > bottom:
		model.scale = Vector3.ONE * (HEIGHT / (top - bottom))


## Mỗi nhân vật có bản sao vật liệu riêng để nháy/mờ không ảnh hưởng nhân vật khác.
func _prepare_materials() -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var src: Material = m.get_active_material(s)
			if src is StandardMaterial3D:
				var copy: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
				copy.emission = Color.WHITE
				copy.emission_energy_multiplier = 0.0
				m.set_surface_override_material(s, copy)
				_mats.append(copy)


func animate(delta: float, speed: float, grounded: bool, _vel_y: float, state_name: String = "", side: float = 1.0) -> void:
	if _dead:
		return
	if _overlay != "":
		_overlay_left -= delta
		if _overlay_left <= 0.0:
			_overlay = ""
			_loco = ""
		else:
			return
	var st: String = RigAnimatorScript.pick_state(speed, grounded, state_name)
	_set_loco(st)
	if st == "run":
		player.speed_scale = clampf(speed / 5.5, 0.7, 1.6)
	else:
		player.speed_scale = 1.0
	# nghiêng thân cho các trạng thái không có clip riêng
	var tilt: float = 0.0
	match st:
		"slide":
			tilt = -35.0
		"wallrun":
			tilt = 18.0 * side
	model.rotation_degrees.z = lerpf(model.rotation_degrees.z, tilt if st == "wallrun" else 0.0, minf(1.0, 12.0 * delta))
	model.rotation_degrees.x = lerpf(model.rotation_degrees.x, tilt if st == "slide" else 0.0, minf(1.0, 12.0 * delta))


const RigAnimatorScript = preload("res://scripts/rig_animator.gd")


func _set_loco(st: String) -> void:
	if st == _loco:
		return
	_loco = st
	var clip: String = String(LOCO_CLIPS[st])
	if player.has_animation(clip):
		player.play(clip, 0.15)


## Chạy overlay chiến đấu; thời lượng `duration` quyết định tốc độ clip.
func play(overlay_name: String, duration: float, _data: Dictionary = {}) -> void:
	if _dead or not OVERLAY_CLIPS.has(overlay_name):
		return
	var clip: String = String(OVERLAY_CLIPS[overlay_name])
	if not player.has_animation(clip):
		return
	if _overlay != "" and int(PRIORITY.get(overlay_name, 1)) < int(PRIORITY.get(_overlay, 1)):
		return
	_overlay = overlay_name
	_overlay_left = maxf(duration, 0.05)
	_loco = ""
	model.rotation_degrees = Vector3.ZERO
	player.play(clip, 0.06, player.get_animation(clip).length / maxf(duration, 0.05))
	if overlay_name == "die":
		_dead = true


func clear_overlay() -> void:
	_overlay = ""
	_overlay_left = 0.0
	_dead = false
	_loco = ""
	player.speed_scale = 1.0
	model.rotation_degrees = Vector3.ZERO
	_set_loco("idle")


func set_render_layers(mask: int) -> void:
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).layers = mask


func get_joint(joint_name: String) -> Node3D:
	return joints.get(joint_name)


func reset_pose() -> void:
	clear_overlay()


func flash() -> void:
	for m in _mats:
		var mat: StandardMaterial3D = m
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 1.5
		create_tween().tween_property(mat, "emission_energy_multiplier", 0.0, 0.12)


func fade_out(duration: float) -> void:
	for m in _mats:
		var mat: StandardMaterial3D = m
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c: Color = mat.albedo_color
		create_tween().tween_property(mat, "albedo_color", Color(c.r, c.g, c.b, 0.0), duration)
