extends Node3D
## Điều phối: đặt người chơi vào đấu trường, NỐI SIGNAL giữa các hệ thống (HUD, âm thanh,
## hitstop, rung camera, hạt), tạm dừng, tổng kết khi chết, lưu điểm cao.

const PickupScript = preload("res://scripts/pickup.gd")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const WaveScript = preload("res://scripts/wave_manager.gd")
const ScoreScript = preload("res://scripts/score_manager.gd")
const PauseScript = preload("res://scripts/pause_menu.gd")
const GameOverScript = preload("res://scripts/game_over.gd")
const GameModeScript = preload("res://scripts/game_mode.gd")
const PortalScript = preload("res://scripts/portal.gd")
const RunProgressScript = preload("res://scripts/run_progress.gd")
const XpOrbScript = preload("res://scripts/xp_orb.gd")
const LevelUpScript = preload("res://scripts/level_up_ui.gd")
const RunStatsScript = preload("res://scripts/run_stats.gd")
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
var mode: Node       # luật chế độ chơi (game_mode.gd)
var stats            # thống kê ván (run_stats.gd)
var portal: Area3D   # Vô Tận: cổng ra tầng
var progress: Node   # Vô Tận: XP / cấp / nâng cấp (run_progress.gd)
var level_ui: CanvasLayer

var _over: bool = false
var _last_charges: int = 2
var _enemies: int = 0
var _hp_ratio: float = 1.0
var _destab: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	preload("res://scripts/mannequin_gltf.gd").warm_up()   # nạp nền model bot trước khi wave đầu sinh bot
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = arena.spawn_point
	add_child(preload("res://scripts/perf_overlay.gd").new())
	add_child(preload("res://scripts/anim_tuner.gd").new())

	# --- Di chuyển -> HUD / âm thanh
	player.speed_changed.connect(hud.set_speed)
	player.state_changed.connect(hud.set_state)
	player.state_changed.connect(_on_state_changed)
	var speed_lines := CanvasLayer.new()
	speed_lines.set_script(preload("res://scripts/speed_lines.gd"))
	add_child(speed_lines)
	player.speed_changed.connect(speed_lines.set_speed)
	player.grapple_target_changed.connect(hud.set_grapple_ready)
	player.grapple_started.connect(func(pt): Fx.sparks(self, pt, Color(1.0, 0.55, 0.2)); Fx.ring(self, pt, Color(1.0, 0.6, 0.3, 0.8)))
	player.dash_charges_changed.connect(func(c, _m): if c < _last_charges: Fx.dust(self, player.global_position, 10))
	player.stamina_changed.connect(hud.set_stamina)
	player.slammed.connect(_on_slammed)
	player.footstep.connect(func(_sp: float): _play_footstep())
	player.jumped.connect(func(): Sfx.play("jump"))
	player.ledge_climbed.connect(func(): Sfx.play("ledge"))
	player.dash_charges_changed.connect(_on_dash_charges)

	# --- Chiến đấu -> HUD / âm thanh / hiệu ứng
	player.hurtbox.health_changed.connect(hud.set_health)
	player.hurtbox.health_changed.connect(_on_health_for_music)
	player.hurtbox.hurt.connect(_on_player_hurt)
	player.combat.ammo_changed.connect(hud.set_ammo)
	player.combat.reloading_changed.connect(hud.set_reloading)
	player.combat.shot_fired.connect(_on_shot_fired)
	player.combat.weapon_changed.connect(hud.set_weapon)
	player.combat.weapon_changed.connect(func(id, _n): player.viewmodel.set_weapon(id))
	player.combat.weapon_changed.connect(func(_id, _n): Sfx.play("switch"))
	player.combat.reloading_changed.connect(func(on: bool):
		if on:
			Sfx.play("reload"))
	player.combat.exploded.connect(_on_exploded)
	player.combat.hit_confirmed.connect(_on_hit_confirmed)
	player.melee.swing_started.connect(func(_w, _a, _r): Sfx.play("slash"))
	player.melee.hit_landed.connect(_on_melee_hit)
	player.melee.clashed.connect(_on_clash)
	player.parry.parried.connect(_on_parried)
	player.parry.parry_missed.connect(func():
		Sfx.play("parry_miss")
		hud.flash("PARRY HỤT", Color(0.8, 0.8, 0.8)))
	player.parry.cooldown_progress.connect(hud.set_parry)
	player.instability.changed.connect(hud.set_instability)
	player.instability.destabilized_changed.connect(_on_destabilized)
	player.died.connect(_on_player_died)

	hud.set_health(player.hurtbox.health, player.hurtbox.max_health)
	hud.set_ammo(player.combat.ammo, Global.COMBAT["gun_mag"])
	_last_charges = player.dash_charges

	# --- Wave + điểm
	score = ScoreScript.new()
	add_child(score)
	score.best = Global.best_score()
	hud.set_score(0, 0, score.best)
	stats = RunStatsScript.new()
	player.combat.shot_fired.connect(func(_f, _t): stats.record_shot())
	player.combat.hit_confirmed.connect(func(landed: bool): stats.record_hit(landed))
	waves = WaveScript.new()
	add_child(waves)
	waves.titans_enabled = arena.titans
	var endless: bool = Global.game_mode == "endless"
	waves.stream = endless
	waves.first_wave = Global.start_wave if Global.game_mode in ["survival", "timed"] else 1
	waves.setup(arena, arena.bot_spawns, arena.spawn_band)
	waves.wave_started.connect(_on_wave_started)
	waves.enemies_left_changed.connect(func(left): hud.set_floor(waves.wave, left) if endless else hud.set_wave(waves.wave, left))
	waves.enemies_left_changed.connect(_on_enemies_for_music)
	waves.wave_cleared.connect(_on_wave_cleared)
	waves.enemies_left_changed.connect(func(_l): hud.set_enemy_types(waves.alive_types))
	waves.bot_spawned.connect(func(bot):
		bot.sound.connect(func(n: String): Sfx.play_at(n, bot.global_position))
		bot.exploded.connect(_on_exploded)
		if "is_titan" in bot:
			_hook_titan(bot))
	waves.bot_killed.connect(_on_bot_killed)
	arena.explosion.connect(_on_exploded)
	arena.prop_broken.connect(_on_prop_broken)
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

	# --- Chế độ chơi
	mode = GameModeScript.new()
	add_child(mode)
	mode.setup(Global.game_mode)
	mode.objective_changed.connect(hud.set_objective)
	mode.time_changed.connect(hud.set_timer)
	mode.finished.connect(_on_mode_finished)
	if endless:
		portal = PortalScript.new()
		add_child(portal)
		portal.global_position = arena.exit_point
		portal.entered.connect(mode.next_floor, CONNECT_DEFERRED)   # không đổi vật lý ngay trong callback va chạm
		mode.portal_opened.connect(_on_portal_opened)
		mode.floor_changed.connect(_on_floor_changed)
		progress = RunProgressScript.new()
		add_child(progress)
		level_ui = LevelUpScript.new()
		add_child(level_ui)
		progress.xp_changed.connect(hud.set_xp)
		progress.leveled_up.connect(func(_lv): _next_level_choice.call_deferred())
		progress.upgrade_chosen.connect(func(_id, _tier): _apply_upgrades())
		level_ui.card_chosen.connect(_on_card_chosen)
		level_ui.skipped.connect(_on_level_skipped)
		hud.set_xp(0, 0, RunProgressScript.need_for(0))
	waves.practice_bot_killed.connect(_on_practice_bot_killed)
	hud.set_mode_layout(mode.mode)
	hud.set_objective(mode.objective_text())
	if mode.mode == "timed":
		waves.break_time = float(Global.TIMED["break_time"])
	if mode.mode == "training":
		_setup_training()

	Sfx.set_intensity(Sfx.compute_intensity(0, 1.0, false))
	Sfx.play_music("battle")
	if autostart_waves:
		await get_tree().create_timer(2.0).timeout
		_start_mode()


## Bắt đầu luật chế độ: sinh tồn / thời gian chạy wave; tập luyện sinh bot tập.
func _start_mode() -> void:
	mode.start()
	if mode.mode == "training":
		_spawn_practice_bot()
	else:
		waves.start()


## Vô Tận: hiện lần chọn nâng cấp kế tiếp (game pause), hoặc đóng màn và chơi tiếp nếu hết lần chờ.
func _next_level_choice() -> void:
	if _over or progress == null or level_ui.visible:
		return
	while progress.pending > 0:
		var choices: Array = progress.draw_choices()
		if not choices.is_empty():
			level_ui.open(progress.level - progress.pending + 1, choices)
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			return
		_on_level_skipped_silent()   # hết thẻ để lấy: tính như Bỏ qua
	level_ui.close()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_card_chosen(id: String) -> void:
	if progress.choose(id):
		Sfx.play("pickup")
	level_ui.close()
	_next_level_choice()


func _on_level_skipped() -> void:
	_on_level_skipped_silent()
	level_ui.close()
	_next_level_choice()


func _on_level_skipped_silent() -> void:
	if progress.skip():
		player.hurtbox.heal(player.hurtbox.max_health * float(Global.XP["skip_heal"]))


## Áp thống kê từ các nâng cấp đã lấy lên người chơi (call down).
func _apply_upgrades() -> void:
	var c = player.combat
	c.damage_mult = progress.stat("damage")
	c.fire_rate_mult = progress.stat("fire_rate")
	c.mag_mult = progress.stat("mag")
	c.reload_mult = progress.stat("reload")
	c.ammo_changed.emit(c.ammo, c.max_ammo())
	player.speed_mult = progress.stat("speed")
	player.stamina_regen_mult = progress.stat("stamina")
	player.pickup_magnet = float(Global.XP["magnet_base"]) + progress.stat("magnet")
	var new_max: float = float(Global.COMBAT["player_health"]) + progress.stat("max_hp")
	var diff: float = new_max - player.hurtbox.max_health
	if diff > 0.0:
		player.hurtbox.max_health = new_max
		player.hurtbox.heal(diff)


## Vô Tận: đủ chỉ tiêu, mở cổng.
func _on_portal_opened(_floor_n: int) -> void:
	portal.set_open(true)
	Sfx.play("wave")
	hud.flash("CỔNG ĐÃ MỞ", Color(0.4, 1.0, 0.6))


## Vô Tận: sang tầng mới. Dựng bản đồ mới, đưa người chơi về chỗ xuất phát (giữ đồ, hồi một phần máu), bot tầng mới sinh quanh đó.
func _on_floor_changed(floor_n: int, _quota: int) -> void:
	portal.set_open(false)
	arena.load_floor(floor_n)
	waves.setup(arena, arena.bot_spawns, arena.spawn_band)
	player.teleport(arena.spawn_point)
	portal.global_position = arena.exit_point
	for child in get_children():
		if child is Area3D and child.get_script() == PickupScript:
			child.queue_free()
	player.hurtbox.heal(player.hurtbox.max_health * float(Global.ENDLESS["heal_on_floor"]))
	waves.begin_floor(floor_n, GameModeScript.has_boss(floor_n))
	Sfx.play("wave")
	hud.flash("TẦNG %d" % floor_n, Color(1.0, 0.85, 0.3))
	if not _over and mode.mode == "endless":
		Global.submit_mode_score(mode.result_score(score.score))


## Tập luyện: bất tử (hồi đầy sau mỗi đòn), đạn vô hạn.
func _setup_training() -> void:
	player.hurtbox.hurt.connect(func(_h, _l): player.hurtbox.heal(player.hurtbox.max_health))
	player.combat.shot_fired.connect(func(_f, _t):
		player.combat.ammo = player.combat.max_ammo()
		player.combat.ammo_changed.emit(player.combat.ammo, player.combat.max_ammo()))


var _practice_i: int = 0


func _spawn_practice_bot() -> void:
	if _over:
		return
	var types: Array = Global.TRAINING["types"]
	waves.spawn_practice(types[_practice_i % types.size()], int(Global.TRAINING["bot_wave"]))
	_practice_i += 1


## Tập luyện (phím T): gọi một Titan, bấm lần nữa để xoá. Chỉ ở bản đồ Khu phố.
func _toggle_practice_titan() -> void:
	if mode == null or mode.mode != "training":
		return
	if not arena.titans:
		hud.flash("Titan chỉ có ở Khu phố", Color(0.8, 0.8, 0.8))
		return
	if waves.clear_titans() > 0:
		hud.set_boss(false, 0.0)
		hud.flash("ĐÃ XOÁ TITAN", Color(0.8, 0.8, 0.8))
		return
	waves.spawn_titan_practice()
	hud.flash("TITAN!", Color(1.0, 0.5, 0.3))


func _on_practice_bot_killed(_bot: Node3D, _info: Dictionary) -> void:
	stats.record_kill(String(_bot.type_name))
	hud.flash("ĐÃ HẠ", Color(0.5, 1.0, 0.5))
	await get_tree().create_timer(float(Global.TRAINING["respawn_time"])).timeout
	_spawn_practice_bot()


func _input(event: InputEvent) -> void:
	if _over:
		return
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		_set_paused(true)
	elif event.is_action_pressed("spawn_titan") and not get_tree().paused:
		_toggle_practice_titan()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused and not Global.anim_debug:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and mode != null:
		Global.submit_mode_score(mode.result_score(score.score))


func _set_paused(on: bool) -> void:
	get_tree().paused = on
	pause_menu.set_open(on)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func _go_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Global.submit_mode_score(mode.result_score(score.score))
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
			Fx.dust(self, player.global_position, 12)
		"WALLRUN":
			Sfx.play("wall")
		"GRAPPLE":
			Sfx.play("grapple")


## Âm bước chân theo chất liệu sàn (meta "surface" của collider dưới chân).
func _play_footstep() -> void:
	var from: Vector3 = player.global_position + Vector3(0.0, 0.3, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.5, Global.L_WORLD)
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	var surface: String = "stone"
	if not hit.is_empty() and (hit["collider"] as Node).has_meta("surface"):
		surface = String((hit["collider"] as Node).get_meta("surface"))
	Sfx.play(Global.step_sound(surface))


## Nhạc động: cường độ theo số bot còn lại, máu và trạng thái mất thế.
func _on_enemies_for_music(left: int) -> void:
	_enemies = left
	_update_music()


func _on_health_for_music(current: float, maximum: float) -> void:
	_hp_ratio = current / maxf(maximum, 1.0)
	_update_music()


func _update_music() -> void:
	if _over:
		return
	Sfx.set_intensity(Sfx.compute_intensity(_enemies, _hp_ratio, _destab))


func _on_dash_charges(charges: int, _maximum: int) -> void:
	if charges < _last_charges:
		Sfx.play("dash")
	_last_charges = charges


func _on_player_hurt(hit: Dictionary, _left: float) -> void:
	Sfx.play("hurt")
	player.shake(0.04)
	hud.flash_damage()
	var src: Variant = hit.get("source")
	if is_instance_valid(src) and src is Node3D:
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
	Global.hitstop(float(Global.ta("pf_clash_hitstop")) * (float(Global.ANIM["pf_reduced_hitstop"]) if Global.reduced_fx else 1.0), float(Global.ta("pf_hitstop_scale")))


## Hướng đòn bay tới người chơi (thế giới): kiếm = từ kẻ tấn công tới mình (phẳng); đạn = ngược vận tốc đã bị phản.
func _incoming_dir(hit: Dictionary) -> Vector3:
	var back: Vector3 = player.head.global_transform.basis.z
	var src: Variant = hit.get("source")
	if hit.get("kind") == "bullet" and is_instance_valid(hit.get("bullet")):
		var v: Vector3 = -Vector3(hit["bullet"].velocity)
		return v.normalized() if v.length() > 0.01 else back
	if src is Node3D and is_instance_valid(src):
		var d: Vector3 = player.global_position - (src as Node3D).global_position
		d.y = 0.0
		return d.normalized() if d.length() > 0.01 else back
	return back


func _on_parried(hit: Dictionary) -> void:
	var incoming: Vector3 = _incoming_dir(hit)
	var at: Vector3 = _front_point()
	Sfx.play("parry")
	Sfx.play("parry_low")
	hud.flash("PARRY!", Color(0.4, 0.85, 1.0))
	var cone: float = float(Global.ta("pf_spark_cone"))
	Fx.sparks(self, at, Color(0.5, 0.9, 1.0), -incoming, cone)          # bật ngược về phía kẻ tấn công
	Fx.sparks(self, at + Vector3(0.0, 0.15, 0.0), Color(1.0, 1.0, 1.0), -incoming, cone * 0.6)
	Fx.ring(self, at, Color(0.5, 0.9, 1.0, 0.9), -player.head.global_transform.basis.z)
	player.shake(0.05)
	player.parry_react(incoming)
	Global.hitstop(Global.parry_hitstop_time(String(hit.get("kind", "melee"))), float(Global.ta("pf_hitstop_scale")))


## Lưới an toàn: rơi khỏi bản đồ thì mất 30 máu và quay về điểm xuất phát (không hồi máu).
func _physics_process(delta: float) -> void:
	if progress != null and not player.dead and player.hurtbox.health < player.hurtbox.max_health:
		var regen: float = progress.stat("regen")
		if regen > 0.0:
			player.hurtbox.heal(regen * delta)
	_update_compass()
	if _over or player.dead:
		return
	if mode != null and mode.active:
		stats.tick(delta)
	if player.global_position.y < arena.void_y:
		player.hurtbox.take_hit({"damage": 30.0, "kind": "void", "source": null, "direction": Vector3.ZERO})
		if not player.dead:
			player.global_position = arena.spawn_point
			player.velocity = Vector3.ZERO


## Titan: thanh máu, rung màn hình theo khoảng cách, chữ báo trúng điểm yếu (chỉ nối Signal, không xử lý logic).
func _hook_titan(t: Node3D) -> void:
	hud.set_boss(true, 1.0)
	t.health_changed.connect(func(cur: float, mx: float): hud.set_boss(cur > 0.0, cur / maxf(mx, 1.0)))
	t.stepped.connect(func(p: Vector3): _titan_shake(p, 0.025))
	t.stomp_landed.connect(func(p: Vector3, r: float):
		_titan_shake(p, 0.12)
		Fx.ring(self, p, Color(1.0, 0.4, 0.2, 0.9))
		Fx.sparks(self, p + Vector3(0.0, 0.3, 0.0), Color(1.0, 0.6, 0.3)))
	t.weak_point_hit.connect(func(zone: String):
		hud.flash("GÁY!" if zone == "nape" else "GỐI!", Color(1.0, 0.85, 0.2)))
	t.died.connect(func(_b, _i): hud.set_boss(false, 0.0))


func _titan_shake(p: Vector3, amount: float) -> void:
	var d: float = p.distance_to(player.global_position)
	var rng: float = float(Global.TITAN["shake_range"])
	if d < rng:
		player.shake(amount * (1.0 - d / rng))


## La bàn (chỉ map lớn): hướng + khoảng cách tới kẻ địch gần nhất, chỉ cập nhật UI qua hàm của HUD.
func _update_compass() -> void:
	if not arena.compass:
		return
	var best: Node3D = null
	var best_d: float = INF
	for b in get_tree().get_nodes_in_group("bots"):
		var n := b as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var d: float = n.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best == null:
		hud.set_compass(false, 0.0, 0.0)
		return
	var local: Vector3 = player.global_transform.affine_inverse() * best.global_position
	hud.set_compass(true, atan2(local.x, -local.z), best_d)


func _on_slammed(pos: Vector3, _radius: float) -> void:
	Sfx.play("clash")
	Fx.sparks(self, pos + Vector3(0.0, 0.2, 0.0), Color(1.0, 0.7, 0.3))
	Global.hitstop(0.06)


func _on_destabilized(active: bool) -> void:
	hud.set_destabilized(active)
	_destab = active
	_update_music()
	if not active:
		Sfx.play("recover")
	if active:
		Sfx.play("destabilized")
		hud.flash("MẤT THẾ!", Color(0.7, 0.5, 1.0))


func _on_shot_fired(from: Vector3, to: Vector3) -> void:
	Sfx.play(String(player.combat.cfg()["sfx"]))
	if player.combat.cfg()["kind"] != "explosive":
		_spawn_tracer(from, to)


func _on_exploded(pos: Vector3, radius: float) -> void:
	Sfx.play_at("explosion", pos)
	Fx.sparks(self, pos, Color(1.0, 0.55, 0.15))
	Fx.sparks(self, pos + Vector3(0.0, 0.3, 0.0), Color(1.0, 0.85, 0.4))
	var near: float = clampf(1.0 - player.global_position.distance_to(pos) / (radius * 3.0), 0.0, 1.0)
	player.shake(0.03 + 0.07 * near)
	Global.hitstop(0.04)


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
	if mode.mode == "survival":
		Global.submit_score(score.score)


func _on_bot_killed(bot: Node3D, info: Dictionary) -> void:
	kills += 1
	stats.record_kill(String(bot.type_name))
	Sfx.play_at("bot_die", bot.global_position)
	if randf() < float(Global.PICKUPS["drop_chance"]):
		_drop_pickup(bot.global_position)
	score.register_kill(info["score"], info) # trước mode.on_kill: phát hạ cuối có thể kết thúc ván ngay
	if progress != null:
		var orb: Area3D = XpOrbScript.spawn(self, bot.global_position, RunProgressScript.orb_value(String(bot.type_name)))
		orb.collected.connect(progress.add_xp)
	var gained: float = mode.on_kill(String(bot.type_name))
	if gained > 0.0:
		hud.flash("+%d s" % roundi(gained), Color(0.5, 0.9, 1.0))


func _drop_pickup(pos: Vector3) -> void:
	var p: Area3D = PickupScript.spawn(self, pos, PickupScript.pick_kind(randf()))
	p.collected.connect(_on_pickup_collected)


func _on_prop_broken(pos: Vector3, kind: String) -> void:
	if kind == "crate":
		Sfx.play_at("crate", pos)
		Fx.sparks(self, pos + Vector3(0.0, 0.5, 0.0), Color(0.75, 0.55, 0.3))
		if randf() < float(Global.PICKUPS["crate_drop_chance"]):
			_drop_pickup(pos)


## Áp hiệu ứng vật nhặt lên người chơi (pickup chỉ phát signal).
func _on_pickup_collected(kind: String) -> void:
	var info: Dictionary = Global.PICKUPS["kinds"][kind]
	match kind:
		"health":
			player.hurtbox.heal(float(info["heal"]))
		"ammo":
			player.combat.refill()
		"stamina":
			player.dash_stamina = float(Global.PLAYER["dash_stamina_max"])
	Sfx.play("pickup")
	hud.flash(String(info["label"]), info["color"])


func _on_player_died() -> void:
	mode.stop()
	_end_run("BẠN ĐÃ GỤC", false)


## Chế độ thời gian tự kết thúc: thắng (đủ bot) hoặc hết giờ.
func _on_mode_finished(won: bool, _info: Dictionary) -> void:
	_end_run("CHIẾN THẮNG!" if won else "HẾT GIỜ", won)


## Kết thúc ván: dừng wave, nộp điểm theo chế độ, hiện màn tổng kết đầy đủ.
func _end_run(title: String, won: bool) -> void:
	if _over:
		return
	_over = true
	waves.stop()
	var death: bool = player.dead
	if death:
		hud.show_death(true)
		Sfx.play("game_over")
	else:
		Sfx.play("wave")
	Sfx.set_intensity(0.0)
	Sfx.play_music("menu")
	var prev_best: int = Global.best_score()
	var final_score: int = mode.result_score(score.score, won)
	var new_record: bool = Global.submit_mode_score(final_score)
	await get_tree().create_timer(1.2 if death else 0.6).timeout
	hud.show_death(false)
	game_over.show_result(build_result(title, won, final_score, prev_best, new_record))
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Nội dung màn tổng kết (tách riêng để test được).
func build_result(title: String, won: bool, final_score: int, prev_best: int, new_record: bool) -> Dictionary:
	var map_name: String = "Bản đồ lưới" if mode.mode == "endless" else String(Global.MAP_NAMES[Global.selected_map])
	var lines: Array = ["Chế độ: %s   -   %s   -   %s" % [Global.MODE_NAMES[mode.mode], map_name, Global.DIFFICULTY_NAMES[Global.difficulty]]]
	if mode.mode == "survival":
		lines.append("Wave đạt được: %d" % waves.wave)
	elif mode.mode == "endless":
		lines.append("Tầng đạt được: %d   (%d / %d bot ở tầng này)" % [mode.floor_n, mode.floor_kills, mode.quota])
	elif mode.mode == "timed":
		lines.append("Mục tiêu: %d / %d bot      Còn lại: %s" % [mode.kills, mode.target, RunStatsScript.format_time(mode.time_left)])
	lines.append("Điểm: %d" % final_score)
	if mode.mode != "timed":
		lines.append("Bot đã hạ: %d" % kills)
	var by_type: String = stats.breakdown_text()
	if by_type != "":
		lines.append(by_type)
	var acc: float = stats.accuracy()
	lines.append("Độ chính xác súng: %s" % ("%d%%" % roundi(acc * 100.0) if acc >= 0.0 else "-"))
	lines.append("Thời gian: %s" % RunStatsScript.format_time(stats.time_alive))
	var best: int = maxi(prev_best, final_score)
	if new_record:
		lines.append("Kỷ lục cũ: %d" % prev_best)
	else:
		lines.append("Kỷ lục: %d (còn thiếu %d)" % [best, best - final_score])
	return {"title": title, "won": won, "lines": lines, "record": "KỶ LỤC MỚI!" if new_record else ""}
