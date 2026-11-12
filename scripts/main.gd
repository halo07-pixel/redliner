extends Node3D
## Điều phối: đặt người chơi vào đấu trường, NỐI SIGNAL giữa các hệ thống (HUD, âm thanh,
## hitstop, rung camera), quản lý con trỏ chuột và hồi sinh.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

@onready var arena: Node3D = $Arena
@onready var hud: CanvasLayer = $HUD

var player: CharacterBody3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = arena.spawn_point

	# --- Di chuyển -> HUD
	player.speed_changed.connect(hud.set_speed)
	player.state_changed.connect(hud.set_state)
	player.dash_charges_changed.connect(hud.set_dash)

	# --- Chiến đấu -> HUD / âm thanh / hiệu ứng
	player.hurtbox.health_changed.connect(hud.set_health)
	player.hurtbox.hurt.connect(_on_player_hurt)
	player.combat.ammo_changed.connect(hud.set_ammo)
	player.combat.shot_fired.connect(_on_shot_fired)
	player.combat.hit_confirmed.connect(_on_hit_confirmed)
	player.melee.swing_started.connect(func(_w, _a, _r): Sfx.play("slash"))
	player.melee.hit_landed.connect(_on_melee_hit)
	player.melee.clashed.connect(_on_clash)
	player.parry.parried.connect(_on_parried)
	player.parry.parry_missed.connect(func(): hud.flash("PARRY HỤT", Color(0.8, 0.8, 0.8)))
	player.died.connect(_on_player_died)
	for d in arena.dummies:
		d.sound.connect(Sfx.play)

	hud.set_health(player.hurtbox.health, player.hurtbox.max_health)
	hud.set_ammo(player.combat.ammo, Global.COMBAT["gun_mag"])


func _input(event: InputEvent) -> void:
	# ESC nhả chuột, bấm chuột trái để bắt lại.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_player_hurt(_hit: Dictionary, _left: float) -> void:
	Sfx.play("hurt")
	player.shake(0.04)


func _on_melee_hit(_hurtbox: Area3D, landed: bool) -> void:
	if landed:
		Sfx.play("hit")
		player.shake(0.03)
		Global.hitstop(0.06)


func _on_hit_confirmed(landed: bool) -> void:
	if landed:
		Sfx.play("hit")


func _on_clash(_direction: Vector3) -> void:
	Sfx.play("clash")
	hud.flash("CLASH!", Color(1.0, 0.85, 0.3))
	Global.hitstop(0.08)


func _on_parried(hit: Dictionary) -> void:
	Sfx.play("parry")
	hud.flash("PARRY!", Color(0.4, 0.85, 1.0))
	player.shake(0.05)
	Global.hitstop(0.08)


func _on_shot_fired(from: Vector3, to: Vector3) -> void:
	Sfx.play("shot")
	_spawn_tracer(from, to)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	get_tree().create_timer(0.06).timeout.connect(mi.queue_free)


func _on_player_died() -> void:
	hud.show_death(true)
	await get_tree().create_timer(Global.COMBAT["respawn_time"]).timeout
	player.respawn(arena.spawn_point)
	hud.show_death(false)
