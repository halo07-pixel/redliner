extends RefCounted
## Áp một mức đồ họa (Global.QUALITY[level]) lên môi trường, mặt trời và viewport.
## Chỉ chỉnh hiển thị, không đụng vật lý hay logic game.

static func apply(level: int, env: Environment, sun: DirectionalLight3D, vp: Viewport) -> void:
	var q: Dictionary = Global.QUALITY[clampi(level, 0, Global.QUALITY.size() - 1)]
	var shadow_modes: Array = [
		DirectionalLight3D.SHADOW_ORTHOGONAL,
		DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
	]
	if sun != null:
		sun.shadow_enabled = q["shadows"]
		sun.directional_shadow_mode = shadow_modes[[1, 2, 4].find(int(q["cascades"]))]
		sun.directional_shadow_max_distance = q["shadow_dist"]
	if env != null:
		env.ssao_enabled = q["ssao"]
		env.glow_enabled = q["glow"]
		env.fog_enabled = q["fog"]
	if vp != null:
		var msaa: Array = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
		vp.msaa_3d = msaa[[0, 2, 4].find(int(q["msaa"]))]
		vp.scaling_3d_scale = q["scale"]
