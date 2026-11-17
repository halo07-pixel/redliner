extends StaticBody3D
## Vật thể phá được: "barrel" (thùng nổ, nổ lan như pháo, nổ dây chuyền) hoặc "crate" (thùng gỗ).
## Có hurtbox phe địch nên kiếm/đạn/vụ nổ của người chơi đều trúng. Giao tiếp bằng Signal:
## `exploded(pos, radius)` (thùng nổ) và `broken(pos, kind)` (mọi loại, để rơi đồ).

const HurtboxScript = preload("res://scripts/components/hurtbox_component.gd")
const RocketScript = preload("res://scripts/rocket.gd")

signal exploded(position: Vector3, radius: float)
signal broken(position: Vector3, kind: String)

var kind: String = "barrel"
var hurtbox: Area3D
var cfg: Dictionary = {}


func _ready() -> void:
	cfg = Global.BREAKABLES[kind]
	collision_layer = Global.L_WORLD
	collision_mask = 0
	var barrel: bool = kind == "barrel"
	var cs := CollisionShape3D.new()
	var mesh: Mesh
	var color: Color
	if barrel:
		var sh := CylinderShape3D.new()
		sh.radius = 0.5
		sh.height = 1.2
		cs.shape = sh
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.5
		cm.height = 1.2
		mesh = cm
		color = Color(0.75, 0.15, 0.1)
	else:
		var sh := BoxShape3D.new()
		sh.size = Vector3(1.0, 1.0, 1.0)
		cs.shape = sh
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 1.0, 1.0)
		mesh = bm
		color = Color(0.55, 0.38, 0.2)
	cs.position.y = 0.6 if barrel else 0.5
	add_child(cs)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	mat.metallic = 0.3 if barrel else 0.0
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = cs.position
	add_child(mi)
	if barrel: # dải vàng cảnh báo
		var band := CylinderMesh.new()
		band.top_radius = 0.51
		band.bottom_radius = 0.51
		band.height = 0.2
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.95, 0.8, 0.15)
		bmat.emission_enabled = true
		bmat.emission = Color(0.95, 0.7, 0.1)
		bmat.emission_energy_multiplier = 0.6
		band.material = bmat
		var bi := MeshInstance3D.new()
		bi.mesh = band
		bi.position = Vector3(0.0, 0.75, 0.0)
		add_child(bi)
	hurtbox = HurtboxScript.new()
	var hs := CollisionShape3D.new()
	var hc := CylinderShape3D.new()
	hc.radius = 0.62
	hc.height = 1.4 if barrel else 1.2
	hs.shape = hc
	hs.position.y = 0.7 if barrel else 0.6
	hurtbox.add_child(hs)
	add_child(hurtbox)
	hurtbox.setup(Global.TEAM_ENEMY, float(cfg["health"]))
	hurtbox.died.connect(_on_died)


func _on_died() -> void:
	hurtbox.collision_layer = 0
	collision_layer = 0
	var pos: Vector3 = global_position
	if bool(cfg["explosive"]):
		var blast := cfg.duplicate()
		blast["life"] = 0.0
		exploded.emit(pos + Vector3(0.0, 0.6, 0.0), float(cfg["blast_radius"]))
		# Nổ sau 1 frame vật lý để vụ nổ dây chuyền không đệ quy trong cùng một lần take_hit
		await get_tree().physics_frame
		if is_inside_tree():
			RocketScript.explode(get_world_3d(), pos + Vector3(0.0, 0.6, 0.0), blast, self)
			_scorch(pos)
	broken.emit(pos, kind)
	queue_free()


## Vệt cháy trên sàn (đĩa phẳng tối) mờ dần; tồn tại độc lập sau khi thùng biến mất.
func _scorch(pos: Vector3) -> void:
	if Global.reduced_fx:
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	var d := CylinderMesh.new()
	d.top_radius = 1.6
	d.bottom_radius = 1.6
	d.height = 0.02
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.02, 0.02, 0.02, 0.7)
	d.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = d
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.02, pos.z)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, float(Global.FX["scorch_time"]))
	tw.tween_callback(mi.queue_free)
