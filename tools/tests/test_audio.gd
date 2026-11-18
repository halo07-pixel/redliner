extends SceneTree
## Test headless M15: bus âm lượng, bảng âm, âm 2D/3D, giới hạn tiếng, nhạc động, chất liệu bước chân.
##   timeout 300 godot --headless --path . -s tools/tests/test_audio.gd

var failures: int = 0
var G
var S


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	S = root.get_node("Sfx")
	G.save_path = "user://test_audio.cfg"
	G.load_save()
	G.reset_settings()

	print("[bảng âm]")
	var missing: Array = []
	for n in G.SOUNDS:
		if not S._streams.has(n):
			missing.append(n)
	_check(missing.is_empty(), "mọi âm trong Global.SOUNDS đều có stream %s" % [missing])
	var untabled: Array = []
	for n in S._streams:
		if not String(n).begins_with("music_") and not G.SOUNDS.has(n):
			untabled.append(n)
	_check(untabled.is_empty(), "mọi stream hiệu ứng đều có trong bảng %s" % [untabled])
	var bad_def: int = 0
	for n in G.SOUNDS:
		var d: Dictionary = G.SOUNDS[n]
		if not (d["bus"] in ["SFX", "UI"]) or int(d["voices"]) < 1 or float(d["pitch_var"]) < 0.0 or float(d["pitch_var"]) > 0.3:
			bad_def += 1
	_check(bad_def == 0, "định nghĩa âm hợp lệ (bus, voices, pitch_var)")
	var re := RegEx.new()
	re.compile("Sfx\\.play(?:_at)?\\(\"([a-z_]+)\"")
	var used: Array = []
	for f in ["main", "ui_kit"]:
		var txt: String = FileAccess.get_file_as_string("res://scripts/%s.gd" % f)
		for m in re.search_all(txt):
			used.append(m.get_string(1))
	var unknown: Array = used.filter(func(n): return not G.SOUNDS.has(n))
	_check(used.size() > 10 and unknown.is_empty(), "tên âm main.gd/ui_kit gọi đều có trong bảng (%d lời gọi) %s" % [used.size(), unknown])
	var gun_missing: Array = []
	for id in G.WEAPON_ORDER:
		if not G.SOUNDS.has(String(G.WEAPONS[id]["sfx"])):
			gun_missing.append(id)
	_check(gun_missing.is_empty(), "mỗi súng có âm bắn trong bảng %s" % [gun_missing])
	var bot_missing: Array = []
	for n in ["slash", "launcher", "shot", "hit"]:
		if not G.SOUNDS.has(n):
			bot_missing.append(n)
	_check(bot_missing.is_empty(), "âm bot phát ra đều có trong bảng")

	print("[bus + âm lượng]")
	for b in ["Master", "SFX", "Music", "UI"]:
		_check(AudioServer.get_bus_index(b) >= 0, "bus %s tồn tại" % b)
	_check(absf(S.bus_volume("SFX") - 1.0) < 0.01 and absf(S.bus_volume("Music") - 0.7) < 0.01, "mặc định: SFX 100%, nhạc 70%")
	G.set_setting("vol_sfx", 0.5)
	_check(absf(S.bus_volume("SFX") - 0.5) < 0.01, "vol_sfx 0.5 -> bus SFX 0.5")
	_check(absf(S.bus_volume("UI") - 0.5) < 0.01, "bus UI đi theo vol_sfx")
	G.set_setting("vol_music", 0.2)
	_check(absf(S.bus_volume("Music") - 0.2) < 0.01, "vol_music đổi bus Music")
	_check(absf(S.bus_volume("SFX") - 0.5) < 0.01, "đổi nhạc không ảnh hưởng SFX")
	G.set_setting("vol_master", 0.0)
	_check(S.bus_volume("Master") == 0.0, "vol_master 0 -> tắt tiếng bus Master")
	G.set_setting("vol_master", 7.0)
	_check(G.settings["vol_master"] == 1.0, "âm lượng bị kẹp trong 0..1")
	G.set_setting("vol_music", -3.0)
	_check(G.settings["vol_music"] == 0.0 and S.bus_volume("Music") == 0.0, "âm lượng âm -> 0 và tắt tiếng")
	G.set_setting("vol_music", 0.4)
	G.set_setting("vol_sfx", 0.3)
	G.load_save()
	S._apply_volumes()
	_check(absf(G.settings["vol_music"] - 0.4) < 0.001 and absf(G.settings["vol_sfx"] - 0.3) < 0.001, "âm lượng được lưu và nạp lại")
	_check(absf(S.bus_volume("Music") - 0.4) < 0.01, "bus áp lại âm lượng sau khi nạp")
	G.reset_settings()
	_check(absf(S.bus_volume("SFX") - 1.0) < 0.01 and absf(S.bus_volume("Music") - 0.7) < 0.01, "Mặc định đặt lại âm lượng")
	var sm = load("res://scripts/settings_menu.gd").new()
	root.add_child(sm)
	await _frames(2)
	for k in ["vol_master", "vol_sfx", "vol_music"]:
		_check(sm._sliders.has(k), "Cài đặt có thanh trượt " + k)
	sm._sliders["vol_sfx"][0].value = 0.25
	_check(absf(S.bus_volume("SFX") - 0.25) < 0.01, "kéo thanh trượt đổi bus SFX")
	sm.queue_free()
	G.reset_settings()

	print("[phát âm 2D]")
	S.stop_all()
	var p = S.play("hit")
	_check(p != null and p.playing, "play(hit) đang phát")
	_check(p.bus == "SFX", "âm hit ở bus SFX")
	_check(absf(p.volume_db - float(G.SOUNDS["hit"]["vol_db"])) < 0.01, "âm lượng gốc theo bảng")
	var pv: float = float(G.SOUNDS["hit"]["pitch_var"])
	var lo: float = 9.0
	var hi: float = 0.0
	S.stop_all()
	for i in 40:
		var q = S.play("hit")
		if q != null:
			lo = minf(lo, q.pitch_scale)
			hi = maxf(hi, q.pitch_scale)
			q.stop()
	_check(lo >= 1.0 - pv - 0.0001 and hi <= 1.0 + pv + 0.0001, "pitch lệch trong ±%.2f (%.3f..%.3f)" % [pv, lo, hi])
	_check(hi - lo > 0.02, "pitch thật sự thay đổi giữa các lần phát")
	_check(S.play("khong_co_am_nay") == null, "âm lạ bị bỏ qua")
	var ui = S.play("ui_click")
	_check(ui != null and ui.bus == "UI", "ui_click ở bus UI")
	S.stop_all()
	var cap: int = int(G.SOUNDS["slash"]["voices"])
	var got: int = 0
	var d0: int = S.dropped
	for i in cap + 3:
		if S.play("slash") != null:
			got += 1
	_check(got == cap, "slash: tối đa %d tiếng cùng lúc (phát %d)" % [cap, got])
	_check(S.dropped - d0 == 3, "3 lần vượt giới hạn được tính là bỏ")
	S.stop_all()
	var one: int = 0
	for i in 3:
		if S.play("reload") != null:
			one += 1
	_check(one == 1, "reload: chỉ 1 tiếng cùng lúc")
	S.stop_all()
	_check(S.voices_of("slash") == 0, "stop_all dừng hết")
	var plays0: int = int(S.plays.get("jump", 0))
	S.play("jump")
	_check(int(S.plays["jump"]) == plays0 + 1, "thống kê plays đếm lần phát thật")
	S.stop_all()
	var total: int = 0
	for n in ["slash", "shot", "hit", "clash", "dash", "crate", "bot_die", "hurt", "step", "jump", "pickup"]:
		for i in 4:
			if S.play(n) != null:
				total += 1
	_check(total <= int(G.AUDIO["voices_2d"]), "tổng tiếng 2D không vượt %d (%d)" % [G.AUDIO["voices_2d"], total])
	S.stop_all()

	print("[phát âm 3D]")
	var w := Node3D.new()
	root.add_child(w)
	var a3 = S.play_at("explosion", Vector3(5, 1, -8))
	_check(a3 != null and a3.playing, "play_at(explosion) đang phát")
	_check(a3.global_position.distance_to(Vector3(5, 1, -8)) < 0.01, "đặt đúng vị trí thế giới")
	_check(a3.max_distance == float(G.AUDIO["max_distance"]) and a3.unit_size == float(G.AUDIO["unit_size"]), "giảm theo khoảng cách (unit_size/max_distance)")
	_check(a3.bus == "SFX", "âm 3D cũng đi qua bus SFX")
	var near: int = 0
	var d1: int = S.dropped
	S.stop_all()
	for i in int(G.SOUNDS["explosion"]["voices"]) + 2:
		if S.play_at("explosion", Vector3(i, 0, 0)) != null:
			near += 1
	_check(near == int(G.SOUNDS["explosion"]["voices"]), "explosion 3D: tối đa %d tiếng" % G.SOUNDS["explosion"]["voices"])
	_check(S.dropped - d1 == 2, "vượt giới hạn 3D bị bỏ")
	S.stop_all()
	_check(S.play_at("khong_co", Vector3.ZERO) == null, "âm 3D lạ bị bỏ qua")
	w.queue_free()

	print("[cường độ nhạc]")
	var c0: float = S.compute_intensity(0, 1.0, false)
	var c4: float = S.compute_intensity(4, 1.0, false)
	var c8: float = S.compute_intensity(8, 1.0, false)
	_check(c0 < c4 and c4 < c8, "nhiều bot -> cường độ tăng (%.2f < %.2f < %.2f)" % [c0, c4, c8])
	_check(S.compute_intensity(20, 1.0, false) == c8, "số bot có trần")
	_check(S.compute_intensity(3, 0.2, false) > S.compute_intensity(3, 1.0, false), "máu thấp -> dồn thêm")
	_check(S.compute_intensity(3, 0.9, false) == S.compute_intensity(3, 1.0, false), "máu cao không ảnh hưởng")
	_check(S.compute_intensity(3, 1.0, true) > S.compute_intensity(3, 1.0, false), "mất thế -> dồn thêm")
	_check(S.compute_intensity(50, 0.0, true) == 1.0, "cường độ tối đa là 1")
	_check(c0 >= 0.0 and c0 < 0.3, "nghỉ giữa wave: cường độ thấp")
	var lv0: Dictionary = S.layer_levels(0.0, "battle")
	var lv1: Dictionary = S.layer_levels(1.0, "battle")
	_check(lv0["calm"] > 0.9 and lv0["intense"] == 0.0 and lv0["base"] > 0.0, "cường độ 0: calm + nền nhẹ, chưa có lớp dồn")
	_check(lv1["calm"] == 0.0 and lv1["intense"] == 1.0 and lv1["base"] == 1.0, "cường độ 1: bỏ calm, đủ lớp dồn")
	var mono: bool = true
	var prev: Dictionary = S.layer_levels(0.0, "battle")
	for k in range(1, 21):
		var cur: Dictionary = S.layer_levels(k / 20.0, "battle")
		if cur["intense"] < prev["intense"] or cur["base"] < prev["base"] or cur["calm"] > prev["calm"]:
			mono = false
		prev = cur
	_check(mono, "các lớp chuyển đơn điệu theo cường độ")
	var lm: Dictionary = S.layer_levels(1.0, "menu")
	_check(lm["calm"] == 1.0 and lm["base"] == 0.0 and lm["intense"] == 0.0, "menu: chỉ lớp calm bất kể cường độ")

	print("[nhạc]")
	S.stop_music()
	S.set_intensity(0.0)
	S.play_music("battle")
	_check(S.music_mode == "battle", "đang ở chế độ battle")
	var all_playing: bool = true
	var same_len: bool = true
	var loops: bool = true
	var base_len: int = (S._streams["music_base"] as AudioStreamWAV).data.size()
	for l in ["calm", "base", "intense"]:
		all_playing = all_playing and S._layer_players[l].playing
		var st: AudioStreamWAV = S._streams["music_" + l]
		same_len = same_len and st.data.size() == base_len
		loops = loops and st.loop_mode == AudioStreamWAV.LOOP_FORWARD
	_check(all_playing, "3 lớp nhạc cùng phát")
	_check(same_len, "3 lớp cùng độ dài (khớp nhịp khi loop)")
	_check(loops, "cả 3 lớp loop")
	_check(S._layer_players["base"].bus == "Music", "nhạc ở bus Music")
	_check(S._layer_level["intense"] == 0.0 and S._layer_level["calm"] > 0.9, "bắt đầu êm: lớp dồn tắt")
	S.set_intensity(1.0)
	S._process(0.3)
	var mid: float = S._layer_level["intense"]
	_check(mid > 0.0 and mid < 1.0, "đổi cường độ: lớp dồn lên dần, không nhảy vọt (%.2f)" % mid)
	_check(S._layer_players["intense"].volume_db > -60.0 or mid > 0.0, "âm lượng lớp dồn tăng")
	for i in 10:
		S._process(0.3)
	_check(S._layer_level["intense"] == 1.0 and S._layer_level["calm"] == 0.0, "đủ lâu: đạt mức đích")
	S.set_intensity(0.0)
	for i in 10:
		S._process(0.3)
	_check(S._layer_level["intense"] == 0.0 and S._layer_level["calm"] > 0.9, "cường độ về 0: quay lại êm")
	S.play_music("menu")
	for i in 10:
		S._process(0.3)
	_check(S.music_mode == "menu" and S._layer_level["base"] == 0.0 and S._layer_level["calm"] == 1.0, "menu: chỉ còn lớp calm")
	var same_mode: bool = true
	S.play_music("menu")
	_check(S._layer_players["calm"].playing, "gọi lại cùng chế độ không làm mất nhạc")
	S.stop_music()
	_check(S.music_mode == "" and not S._layer_players["base"].playing, "stop_music dừng hết")

	print("[chất liệu bước chân]")
	_check(G.step_sound("metal") == "step_metal" and G.step_sound("wood") == "step_wood" and G.step_sound("stone") == "step" and G.step_sound("?") == "step", "step_sound theo chất liệu")
	var arena: Node3D = load("res://scripts/arena.gd").new()
	arena.map_id = "tower"
	root.add_child(arena)
	await _frames(3)
	var kinds: Dictionary = {}
	for ch in arena.get_children():
		if ch is StaticBody3D and ch.has_meta("surface"):
			kinds[ch.get_meta("surface")] = int(kinds.get(ch.get_meta("surface"), 0)) + 1
	_check(kinds.has("stone") and kinds.has("metal"), "map có cả sàn đá và kim loại %s" % [kinds])
	arena.queue_free()
	for k in ["barrel", "crate"]:
		var b = load("res://scripts/breakable.gd").new()
		b.kind = k
		root.add_child(b)
		await _frames(1)
		_check(b.get_meta("surface", "") == ("metal" if k == "barrel" else "wood"), "%s: chất liệu %s" % [k, b.get_meta("surface", "")])
		b.queue_free()

	print("[nối vào game]")
	G.selected_map = "yard"
	var main = load("res://scenes/main.tscn").instantiate()
	main.autostart_waves = false
	root.add_child(main)
	await _frames(6)
	main.player.use_input = false
	_check(S.music_mode == "battle", "vào game: nhạc battle")
	S.stop_all()
	var n0: Dictionary = S.plays.duplicate()
	main.player.jumped.emit()
	main.player.ledge_climbed.emit()
	main.player.combat.reloading_changed.emit(true)
	main.player.combat.weapon_changed.emit("shotgun", "Shotgun")
	main.player.instability.destabilized_changed.emit(true)
	main.player.instability.destabilized_changed.emit(false)
	for n in ["jump", "ledge", "reload", "switch", "destabilized", "recover"]:
		_check(int(S.plays.get(n, 0)) == int(n0.get(n, 0)) + 1, "signal -> âm '%s'" % n)
	S.stop_all()
	var s0: int = int(S.plays.get("step", 0)) + int(S.plays.get("step_metal", 0))
	main._play_footstep()
	var s1: int = int(S.plays.get("step", 0)) + int(S.plays.get("step_metal", 0))
	_check(s1 == s0 + 1, "footstep -> phát âm bước chân")
	S.stop_all()
	var e0: int = int(S.plays.get("explosion", 0))
	main._on_exploded(Vector3(3, 1, 3), 3.0)
	_check(int(S.plays.get("explosion", 0)) == e0 + 1, "vụ nổ -> âm explosion (3D)")
	S.stop_all()
	main.waves.enemies_left_changed.emit(8)
	var hi_i: float = S.intensity
	main.waves.enemies_left_changed.emit(0)
	var lo_i: float = S.intensity
	_check(hi_i > lo_i + 0.4, "bot còn nhiều -> nhạc dồn (%.2f vs %.2f)" % [hi_i, lo_i])
	main.player.hurtbox.health_changed.emit(10.0, 100.0)
	_check(S.intensity > lo_i, "máu thấp -> nhạc dồn thêm")
	main.player.hurtbox.health_changed.emit(100.0, 100.0)
	var bots_fired: Array = []
	var fake = load("res://scripts/bot.gd").new()
	main.add_child(fake)
	fake.global_position = Vector3(6, 0, 6)
	S.stop_all()
	var sl0: int = int(S.plays.get("slash", 0))
	main.waves.bot_spawned.emit(fake)
	fake.sound.emit("slash")
	_check(int(S.plays.get("slash", 0)) == sl0 + 1, "bot.sound -> phát 3D tại vị trí bot")
	var found3d: bool = false
	for p3 in S._players_3d:
		if p3.playing and p3.global_position.distance_to(Vector3(6, 0, 6)) < 0.5:
			found3d = true
	_check(found3d, "tiếng bot phát đúng chỗ bot đứng")
	S.stop_all()
	main.queue_free()
	await _frames(2)
	S.stop_music()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_audio.cfg"))
	print("----", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
