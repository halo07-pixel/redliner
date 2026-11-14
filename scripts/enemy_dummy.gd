extends StaticBody3D
## Bia tập: có hurtbox + máu, kiếm, parry. Các hàm swing()/shoot_at() dùng cho test.
## Âm thanh chỉ phát qua Signal `sound`.

signal sound(sound_name: String)
signal died

const MannequinScript = preload("res://scripts/mannequin.gd")
const HurtboxScript = preload("res://scripts/components/hurtbox_component.gd")
const ParryScript = preload("res://scripts/components/parry_component.gd")
const MeleeScript = preload("res://scripts/components/melee_hitbox_component.gd")
const BulletScript = preload("res://scripts/bullet.gd")

@export var color: Color = Color(0.85, 0.2, 0.2)

var hurtbox: Area3D
var parry: Node
var melee: Node3D
var mannequin: Node3D

var _body_shape: CollisionShape3D


func _ready() -> void:
	collision_layer = Global.L_ENEMY # người chơi va chạm được (mask 5), đạn/tia không bị chặn
	collision_mask = 0
	_body_shape = CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.35
	cs.height = 1.8
	_body_shape.shape = cs
	_body_shape.position = Vector3(0.0, 0.9, 0.0)
	add_child(_body_shape)

	mannequin = MannequinScript.new()
	mannequin.color = color
	add_child(mannequin)

	parry = ParryScript.new()
	add_child(parry)
	parry.setup(self)

	hurtbox = HurtboxScript.new()
	var hs := CollisionShape3D.new()
	var hc := CapsuleShape3D.new()
	hc.radius = 0.4
	hc.height = 1.9
	hs.shape = hc
	hs.position = Vector3(0.0, 0.95, 0.0)
	hurtbox.add_child(hs)
	add_child(hurtbox)
	hurtbox.setup(Global.TEAM_ENEMY, Global.COMBAT["dummy_health"], parry)
	hurtbox.hurt.connect(_on_hurt)
	hurtbox.died.connect(_on_died)

	melee = MeleeScript.new()
	melee.position = Vector3(0.0, 1.2, 0.0)
	add_child(melee)
	melee.setup(Global.TEAM_ENEMY, self)
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.07, 0.9)
	blade.mesh = bm
	blade.position = Vector3(0.4, -0.1, -0.5)
	melee.add_child(blade)


func swing() -> bool:
	var ok: bool = melee.try_swing()
	if ok:
		sound.emit("slash")
	return ok


## Bắn 1 viên đạn vật thể vào điểm `target_pos`. Trả về viên đạn.
func shoot_at(target_pos: Vector3) -> Node3D:
	var origin: Vector3 = global_position + Vector3(0.0, 1.3, 0.0)
	var dir: Vector3 = (target_pos - origin).normalized()
	var b: Node3D = BulletScript.new()
	b.setup(Global.TEAM_ENEMY, self, dir)
	get_parent().add_child(b)
	b.global_position = origin + dir * 0.8
	sound.emit("shot")
	return b


func _on_hurt(_hit: Dictionary, _left: float) -> void:
	mannequin.flash()


func _on_died() -> void:
	sound.emit("hit")
	died.emit()
	hurtbox.collision_layer = 0
	_body_shape.set_deferred("disabled", true)
	visible = false
	await get_tree().create_timer(Global.COMBAT["dummy_respawn"]).timeout
	visible = true
	_body_shape.set_deferred("disabled", false)
	hurtbox.revive()
