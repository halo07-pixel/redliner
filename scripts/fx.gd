extends RefCounted
## Hiệu ứng hình ảnh dùng chung (hạt tia lửa).


## direction/spread mặc định: phun mọi hướng. Truyền hướng + độ loe (độ) để phun theo hướng đòn (M28).
static func sparks(parent: Node, pos: Vector3, color: Color, direction: Vector3 = Vector3.UP, spread: float = 180.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = mini(int(Global.FX["max_particles"]), maxi(4, int(28.0 * (float(Global.FX["reduced_particles"]) if Global.reduced_fx else 1.0))))
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0.0, -14.0, 0.0)
	p.mesh = _cube(color, float(Global.FX["particle_size"]))
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	return p


## Hạt low poly: khối lập phương nhỏ không đổ bóng (dùng chung cho tia lửa, bụi, nổ nhặt vật).
static func _cube(color: Color, size: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	m.material = mat
	return m


## Tung hạt khi nhặt vật: phun lên từ vị trí vật, màu theo loại. Giảm hiệu ứng thì ít hạt đi.
static func burst(parent: Node, pos: Vector3, color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = mini(int(Global.FX["max_particles"]), maxi(3, int(float(Global.FX["burst_amount"]) * (float(Global.FX["reduced_particles"]) if Global.reduced_fx else 1.0))))
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = float(Global.FX["burst_speed"]) * 0.6
	p.initial_velocity_max = float(Global.FX["burst_speed"])
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.mesh = _cube(color, float(Global.FX["particle_size"]) * 1.2)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)
	return p


## Sóng parry: vòng tròn phẳng nở ra rồi tan. Không vẽ khi giảm hiệu ứng.
static func ring(parent: Node, pos: Vector3, color: Color, facing: Vector3 = Vector3.FORWARD) -> MeshInstance3D:
	if Global.reduced_fx:
		return null
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	t.rings = 24
	t.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	t.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.look_at(pos + facing, Vector3.UP) # trục -Z hướng ra; torus nằm trong mặt XZ nên xoay 90 độ
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	mi.scale = Vector3.ONE * 0.2
	var time: float = float(Global.FX["ring_time"])
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * float(Global.FX["ring_radius"]), time)
	tw.tween_property(mat, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Bụi bốc lên ở chân khi lướt/dash/tiếp đất. Không vẽ nhiều hạt khi giảm hiệu ứng.
static func dust(parent: Node, pos: Vector3, amount: int = 14) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(3, int(float(amount) * (float(Global.FX["reduced_particles"]) if Global.reduced_fx else 1.0)))
	p.lifetime = 0.55
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0.0, -2.0, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.72, 0.65, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	p.mesh = m
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(1.0).timeout.connect(p.queue_free)
