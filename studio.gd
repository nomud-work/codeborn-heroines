## Studio: 3-point lighting, cyclorama backdrop, environment.
class_name Studio
extends RefCounted

static func lights(root: Node3D, target: Vector3, key_yaw := 0.75, shadows := true) -> void:
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.95, 0.88)
	key.light_energy = 1.7
	key.rotation = Vector3(deg_to_rad(-32), key_yaw, 0)
	key.shadow_enabled = shadows
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 2.5
	key.shadow_blur = 1.5
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 6.0
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.75, 0.82, 1.0)
	fill.light_energy = 0.6
	fill.rotation = Vector3(deg_to_rad(-10), key_yaw - 2.0, 0)
	root.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(1.0, 0.93, 0.85)
	rim.light_energy = 2.2
	rim.rotation = Vector3(deg_to_rad(-25), key_yaw + PI - 0.5, 0)
	root.add_child(rim)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	# studio "HDRI" made in a sky shader: dim grey dome + softboxes matching the lights
	var sky := Sky.new()
	var sm := ShaderMaterial.new(); var sh := Shader.new(); sh.code = Shaders.SKY; sm.shader = sh
	sm.set_shader_parameter("key_dir", Vector3(sin(key_yaw), 0.55, cos(key_yaw)).normalized())
	sm.set_shader_parameter("rim_dir", Vector3(sin(key_yaw + PI - 0.5), 0.45, cos(key_yaw + PI - 0.5)).normalized())
	sm.set_shader_parameter("fill_dir", Vector3(sin(key_yaw - 2.0), 0.15, cos(key_yaw - 2.0)).normalized())
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.32
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.8
	env.glow_enabled = false
	env.glow_intensity = 0.25
	env.glow_hdr_threshold = 1.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.02
	we.environment = env
	root.add_child(we)

static func backdrop(root: Node3D) -> void:
	# cyclorama: floor that sweeps up into a back wall with a quarter-round cove
	var st := Geo.new_st(false)
	var R := 2.0
	var P := func(u: float, v: float) -> Vector3:
		var x := lerpf(-14.0, 14.0, u)
		var s := v * (8.0 + PI * R * 0.5 + 6.0) # arc length from front of floor
		var z: float
		var y: float
		if s < 8.0:
			z = 4.0 - s; y = 0.0
		elif s < 8.0 + PI * R * 0.5:
			var a := (s - 8.0) / R
			z = -4.0 - sin(a) * R; y = R - cos(a) * R
		else:
			z = -4.0 - R; y = R + (s - 8.0 - PI * R * 0.5)
		return Vector3(x, y, z)
	Geo.patch(st, P, 8, 60, {"closed_u": false, "orient": func(u, v, p): return Vector3(0, 1, 1)})
	var m := ArrayMesh.new()
	var sm := ShaderMaterial.new(); var sh := Shader.new(); sh.code = Shaders.BACKDROP; sm.shader = sh
	Geo.finish(st, m, sm, "backdrop")
	var mi := MeshInstance3D.new(); mi.mesh = m
	root.add_child(mi)
