extends SceneTree
## M46 "Vật phẩm, hiệu ứng, ánh sáng": 3 vật nhặt low poly (tools/blender/make_items.py) nằm trong ngân sách, pickup dùng chúng (it_glow tô
## theo màu loại, nhặt vẫn phát `collected`), hạt là khối nhỏ có trần số hạt, nhặt vật tung hạt, cửa sổ module sáng hơn khi trời tối.
##   timeout 150 godot --headless --path . -s tools/tests/test_m46.gd

const KINDS: Array = ["health", "ammo", "stamina"]

var failures: int = 0
var G
var Pickup
var Fx
var Look
var Mods


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		printerr("  FAIL  ", msg)


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	await process_frame
	G = root.get_node("Global")
	Pickup = load("res://scripts/pickup.gd")
	Fx = load("res://scripts/fx.gd")
	Look = load("res://scripts/endless_look.gd")
	Mods = load("res://scripts/endless_modules.gd")
	print("[Vật nhặt low poly]")
	_check(G.PICKUPS["kinds"].keys().size() == 3 and G.LOWPOLY["items"].keys().size() == 3, "3 loại vật nhặt, 3 model")
	for k in KINDS:
		var path: String = G.LOWPOLY["items"][k]
		_check(ResourceLoader.exists(path), "có file %s" % path)
		var n: Node3D = load(path).instantiate()
		var t: int = Mods.tri_count(n)
		_check(t > 0 and t <= int(G.LOWPOLY["budget"]["prop"]), "%s: %d tam giác <= 3000" % [k, t])
		var a := AABB()
		var first := true
		var roles: Array = []
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var inst := mi as MeshInstance3D
			a = inst.get_aabb() if first else a.merge(inst.get_aabb())
			first = false
			for s in inst.mesh.get_surface_count():
				roles.append(String(inst.mesh.surface_get_material(s).resource_name))
		_check(a.size.x <= 0.7 and a.size.y <= 0.7 and a.size.z <= 0.7 and a.size.length() > 0.2, "%s: kích thước vừa tay nhặt (%s)" % [k, str(a.size)])
		_check(roles.all(func(r): return r in ["it_body", "it_glow"]) and roles.has("it_glow"), "%s: vật liệu it_body/it_glow" % k)
		n.free()

	print("[Pickup dùng model, tô màu, vẫn nhặt được]")
	var world := Node3D.new()
	root.add_child(world)
	for k in KINDS:
		var p: Area3D = Pickup.spawn(world, Vector3(0, 0, 0), k)
		await _frames(1)
		var model: Node = p.get_node_or_null("Model")
		_check(model != null, "%s: dùng model low poly" % k)
		var glow_ok := false
		var c: Color = G.PICKUPS["kinds"][k]["color"]
		for mi in p.find_children("*", "MeshInstance3D", true, false):
			for i in (mi as MeshInstance3D).mesh.get_surface_count():
				var m := (mi as MeshInstance3D).get_surface_override_material(i) as StandardMaterial3D
				if m != null and m.emission_enabled and m.emission.is_equal_approx(c):
					glow_ok = true
		_check(glow_ok, "%s: phần sáng tô đúng màu loại" % k)
		var light: OmniLight3D = p.find_children("*", "OmniLight3D", true, false)[0]
		_check(is_equal_approx(light.light_energy, float(G.FX["pickup_light_energy"])), "%s: đèn lấy từ hằng số FX" % k)
		p.queue_free()
	var got: Array = []
	var p2: Area3D = Pickup.spawn(world, Vector3.ZERO, "health")
	p2.collected.connect(func(kind): got.append(kind))
	var cp := CharacterBody3D.new()
	cp.add_to_group("player")
	cp.collision_layer = G.L_PLAYER
	var cs := CollisionShape3D.new()
	cs.shape = SphereShape3D.new()
	cp.add_child(cs)
	world.add_child(cp)
	cp.global_position = Vector3(0, 0.8, 0)
	await _frames(4)
	_check(got == ["health"], "chạm người chơi -> collected('health')")
	var bursts: int = world.find_children("*", "CPUParticles3D", true, false).size()
	_check(bursts >= 1, "nhặt vật tung hạt (%d)" % bursts)

	print("[Hạt low poly có trần]")
	var sp: CPUParticles3D = Fx.sparks(world, Vector3.ZERO, Color.WHITE)
	_check(sp.mesh is BoxMesh and absf((sp.mesh as BoxMesh).size.x - float(G.FX["particle_size"])) < 0.001, "tia lửa là khối nhỏ")
	_check(sp.amount <= int(G.FX["max_particles"]), "tia lửa <= trần %d hạt" % int(G.FX["max_particles"]))
	var b: CPUParticles3D = Fx.burst(world, Vector3.ZERO, Color.GREEN)
	_check(b.mesh is BoxMesh and b.amount <= int(G.FX["max_particles"]) and b.one_shot, "burst: khối nhỏ, một lần, <= trần")
	G.reduced_fx = true
	var b2: CPUParticles3D = Fx.burst(world, Vector3.ZERO, Color.GREEN)
	var s2: CPUParticles3D = Fx.sparks(world, Vector3.ZERO, Color.WHITE)
	_check(b2.amount < b.amount and s2.amount < sp.amount, "giảm hiệu ứng -> ít hạt hơn")
	G.reduced_fx = false

	print("[Ánh sáng theo chủ đề]")
	var day: float = Look.theme_window_energy(0)
	var night: float = Look.theme_window_energy(3)
	_check(night > day and is_equal_approx(day, float(Look.LOOK["window_energy"])), "đêm: cửa sổ sáng hơn ngày (%.2f > %.2f)" % [night, day])
	for i in Look.THEMES.size():
		_check(Look.theme_window_energy(i) >= day, "chủ đề %d không tối hơn ngày" % i)
	var env: Dictionary = Look.theme_env(3)
	_check(float(env["sun_energy"]) >= Look.MIN_SUN and float(env["ambient_energy"]) >= Look.MIN_AMBIENT, "đêm vẫn có sàn độ sáng")
	var a1: Node3D = load("res://scripts/arena.gd").new()
	a1.map_id = "endless"
	a1.floor_n = 4
	a1.bake_nav = false
	root.add_child(a1)
	await _frames(2)
	var found := false
	for mi in a1.find_children("*", "MeshInstance3D", true, false):
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			var m := (mi as MeshInstance3D).get_surface_override_material(i) as StandardMaterial3D
			if m != null and m.emission_enabled and absf(m.emission_energy_multiplier - Look.theme_window_energy(Look.theme_index(4))) < 0.001:
				found = true
	_check(found, "Arena tầng 4 (đêm): cửa sổ module dùng độ sáng của chủ đề")

	print("")
	print("---- ", "TẤT CẢ ĐẠT" if failures == 0 else "%d LỖI" % failures)
	quit(1 if failures > 0 else 0)
