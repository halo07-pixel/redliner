extends Node3D
## Điều phối: đặt người chơi vào đấu trường, NỐI SIGNAL giữa các hệ thống (HUD, âm thanh,
## hitstop, rung camera, hạt), tạm dừng, tổng kết khi chết, lưu điểm cao.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const WaveScript = preload("res://scripts/wave_manager.gd")
const ScoreScript = preload("res://scripts/score_manager.gd")
const PauseScript = preload("res://scripts/pause_menu.gd")
const GameOverScript = preload("res://scripts/game_over.gd")
const Fx = preload("res://scripts/fx.gd")
const MENU_SCENE := "res://scenes/menu.tscn"

@onready var arena: Node3D = $Arena
@onready var hud: CanvasLayer = $HUD

var player: CharacterBody3D
var waves: Node
var score: Node
var pause_menu: CanvasLayer
var game_over: CanvasLayer
var autostart_waves: bool = true # script chụp ảnh/test có thể tắt để tự điều khiển wave
var kills: int = 0

var _over: bool = false
var _last_charges: int = 2


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = arena.spawn_point

	# --- Di chuyển -> HUD / âm thanh
	player.speed_changed.connect(hud.set_speed)
	player.state_changed.connect(hud.set_state)
	player.state_changed.connect(_on_state_changed)
	player.dash_charges_changed.connect(hud.set_dash)
	player.dash_charges_changed.connect(_on_dash_charges)

	# --- Chiến đấu -> HUD / âm thanh / hiệu ứng
	player.hurtbox.health_changed.connect(hud.set_health)
	player.hurtbox.hurt.connect(_on_player_hurt)
	player.combat.ammo_changed.connect(hud.set_ammo)
	player.combat.reloading_changed.connect(hud.set_reloading)
	player.combat.shot_fired.connect(_on_shot_fired)
	player.combat.hit_confirmed.connect(_on_hit_confirmed)
	player.melee.swing_started.connect(func(_w, _a, _r): Sfx.play("slash"))
	player.melee.hit_landed.connect(_on_melee_hit)
	player.melee.clashed.connect(_on_clash)
	player.parry.parried.connect(_on_parried)
	player.parry.parry_missed.connect(func(): hud.flash("PARRY HỤT", Color(0.8, 0.8, 0.8)))
	player.parry.cooldown_progress.connect(hud.set_parry)
	player.instability.changed.connect(hud.set_instability)
	player.instability.redline_changed.connect(_on_redline)
	player.died.connect(_on_player_died)

	hud.set_health(player.hurtbox.health, player.hurtbox.max_health)
	hud.set_ammo(player.combat.ammo, Global.COMBAT["gun_mag"])
	_last_charges = player.dash_charges

	# --- Wave + điểm
	score = ScoreScript.new()
	add_child(score)
	score.best = Global.high_score
	hud.set_score(0, 0, score.best)
	waves = WaveScript.new()
	add_child(waves)
	waves.setup(arena, arena.bot_spawns)
	waves.wave_started.connect(_on_wave_started)
	waves.enemies_left_changed.connect(func(left): hud.set_wave(waves.wave, left))
	waves.wave_cleared.connect(_on_wave_cleared)
	waves.bot_spawned.connect(func(bot): bot.sound.connect(Sfx.play))
	waves.bot_killed.connect(_on_bot_killed)
	score.score_changed.connect(hud.set_score)
	score.bonus.connect(func(text): hud.flash(text, Color(1.0, 0.85, 0.3)))

	# --- Menu tạm dừng + tổng kết
	pause_menu = PauseScript.new()
	add_child(pause_menu)
	pause_menu.resume_requested.connect(_set_paused.bind(false))
	pause_menu.menu_requested.connect(_go_menu)
	game_over = GameOverScript.new()
	add_child(game_over)
	game_over.restart_requested.connect(_restart)
	game_over.menu_requested.connect(_go_menu)

	Sfx.play_music()
	if autostart_waves:
		await get_tree().create_timer(2.0).timeout
		waves.start()


func _input(event: InputEvent) -> void:
	if _over:
		return
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		_set_paused(true)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Global.submit_score(score.score)


func _set_paused(on: bool) -> void:
	get_tree().paused = on
	pause_menu.set_open(on)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func _go_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Global.submit_score(score.score)
	Sfx.stop_music()
	get_tree().change_scene_to_file(MENU_SCENE)


func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# ------------------------------------------------------------------ phản hồi (HUD / âm thanh / hiệu ứng)

func _on_state_changed(state_name: String) -> void:
	match state_name:
		"SLIDE":
			Sfx.play("slide")
		"WALLRUN":
			Sfx.play("wall")
		"GRAPPLE":
			Sfx.play("grapple")


func _on_dash_charges(charges: int, _maximum: int) -> void:
	if charges < _last_charges:
		Sfx.play("dash")
	_last_charges = charges


func _on_player_hurt(hit: Dictionary, _left: float) -> void:
	Sfx.play("hurt")
	player.shake(0.04)
	hud.flash_damage()
	var src: Variant = hit.get("source")
	if src is Node3D and is_instance_valid(src):
		var local: Vector3 = player.global_transform.affine_inverse() * (src as Node3D).global_position
		hud.show_hit_indicator(atan2(local.x, -local.z))


func _on_melee_hit(_hurtbox: Area3D, landed: bool) -> void:
	if landed:
		Sfx.play("hit")
		player.shake(0.03)
		Global.hitstop(0.06)


func _on_hit_confirmed(landed: bool) -> void:
	if landed:
		Sfx.play("hit")


func _front_point() -> Vector3:
	return player.head.global_position - player.head.global_transform.basis.z * 1.6


func _on_clash(_direction: Vector3) -> void:
	Sfx.play("clash")
	hud.flash("CLASH!", Color(1.0, 0.85, 0.3))
	Fx.sparks(self, _front_point(), Color(1.0, 0.85, 0.3))
	Global.hitstop(0.08)


func _on_parried(_hit: Dictionary) -> void:
	Sfx.play("parry")
	hud.flash("PARRY!", Color(0.4, 0.85, 1.0))
	Fx.sparks(self, _front_point(), Color(0.5, 0.9, 1.0))
	player.shake(0.05)
	Global.hitstop(0.08)


func _on_redline(active: bool) -> void:
	hud.set_redline(active)
	if active:
		Sfx.play("redline")
		hud.flash("REDLINE!", Color(1.0, 0.35, 0.15))


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


# ------------------------------------------------------------------ wave / điểm / chết

func _on_wave_started(n: int, count: int) -> void:
	Sfx.play("wave")
	hud.flash("WAVE %d" % n, Color(1.0, 0.4, 0.3))
	hud.set_wave(n, count)


func _on_wave_cleared(n: int) -> void:
	hud.flash("WAVE %d XONG!" % n, Color(0.5, 1.0, 0.5))
	Global.submit_score(score.score)


func _on_bot_killed(_bot: Node3D, info: Dictionary) -> void:
	kills += 1
	score.register_kill(info["score"], info)


func _on_player_died() -> void:
	_over = true
	waves.stop()
	hud.show_death(true)
	var prev_best: int = Global.high_score
	var new_record: bool = Global.submit_score(score.score)
	await get_tree().create_timer(1.2).timeout
	hud.show_death(false)
	Sfx.stop_music()
	game_over.show_summary(waves.wave, score.score, kills, maxi(prev_best, score.score), new_record)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
