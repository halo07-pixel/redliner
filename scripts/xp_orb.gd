extends Area3D
## Viên XP rơi từ bot (Vô Tận). Lại gần trong tầm hút của người chơi (`pickup_magnet`) thì bay về phía người chơi;
## chạm thì phát `collected(amount)`. Không áp XP: main nghe signal (call down, signal up). Hết hạn sau Global.XP.orb_lifetime.

signal collected(amount: int)

var amount: int = 1
var age: float = 0.0
var _taken: bool = false
var _mesh: MeshInstance3D


static func spawn(parent: Node, pos: Vector3, p_amount: int) -> Area3D:
	var o: Area3D = load("res://scripts/xp_orb.gd").new()
	o.amount = p_amount
	parent.add_child(o)
	o.global_position = pos
	return o


func _ready() -> void:
	collision_layer = 0
	collision_mask = Global.L_PLAYER
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.9
	cs.shape = sh
	add_child(cs)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 0.85, 1.0)
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	sm.material = mat
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sm
	_mesh.position.y = 0.7
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	age += delta
	if age >= float(Global.XP["orb_lifetime"]) and not _taken:
		_taken = true
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or _taken:
		return
	var to: Vector3 = (player.global_position + Vector3(0.0, 0.9, 0.0)) - global_position
	var magnet: float = float(player.get("pickup_magnet")) if player.get("pickup_magnet") != null else float(Global.XP["magnet_base"])
	if to.length() <= magnet:
		global_position += to.normalized() * minf(float(Global.XP["orb_speed"]) * delta, to.length())
	_mesh.position.y = 0.7 + sin(age * 4.0) * 0.1


func _on_body(body: Node3D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	collected.emit(amount)
	queue_free()
