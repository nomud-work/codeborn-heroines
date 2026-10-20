## Render driver. Modes (user args after --):
##   --mode=hero|face|wire|lineup|turntable  --char=paladin|mage|ranger  --out=name
extends Node3D

var chars := []
var cam: Camera3D
var mode := "hero"
var who := "paladin"
var out_name := ""
var frame := 0
var timings := PackedFloat64Array()
var last := 0
const KINDS := ["paladin", "mage", "ranger"]

func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + k + "="): return a.substr(k.length() + 3)
	return d

func _ready() -> void:
	mode = _arg("mode", "hero")
	who = _arg("char", "paladin")
	out_name = _arg("out", mode + "_" + who)
	var t0 := Time.get_ticks_msec()
	Studio.backdrop(self)
	var list: Array = KINDS if mode in ["lineup", "turntable"] else [who]
	var xs := {"paladin": -0.95, "mage": 0.0, "ranger": 0.95}
	for k in list:
		var tc := Time.get_ticks_msec()
		var ch := Character.new()
		ch.build(k)
		ch.seed_phase = {"paladin": 0.0, "mage": 2.3, "ranger": 4.1}[k]
		add_child(ch)
		if list.size() > 1:
			ch.position.x = xs[k]
			ch.rotation.y = {"paladin": 0.35, "mage": 0.0, "ranger": -0.35}[k]
		else:
			ch.rotation.y = 0.55 if mode != "face" else 0.0
		chars.append(ch)
		print("BUILD %s ms=%d tris=%d timings=%s" % [k, Time.get_ticks_msec() - tc, ch.total_tris(), ch.timings])
		print("TRIS %s %s" % [k, ch.tris])
	print("BUILD_TOTAL_MS ", Time.get_ticks_msec() - t0)
	var key_yaw := 0.70
	Studio.lights(self, Vector3.ZERO, key_yaw, true)
	cam = Camera3D.new()
	add_child(cam)
	cam.make_current()
	match mode:
		"hero", "wire":
			cam.fov = 24.0
			cam.look_at_from_position(Vector3(0, 1.02, 4.4), Vector3(0, 0.875, 0))
			if mode == "wire":
				_wire(chars[0])
		"face":
			cam.fov = 14.0
			var yaw := 0.52
			chars[0].rotation.y = yaw
			var hc: Vector3 = chars[0].body.J.head + Vector3(0, -0.04, 0.0)
			cam.look_at_from_position(hc + Vector3(0, 0.07, 1.45), hc)
		"wireface":
			cam.fov = 14.0
			chars[0].rotation.y = 0.52
			var hc2: Vector3 = chars[0].body.J.head + Vector3(0, -0.04, 0.0)
			cam.look_at_from_position(hc2 + Vector3(0, 0.07, 1.45), hc2)
			_wire(chars[0])
		"lineup", "turntable":
			cam.fov = 30.0
			cam.look_at_from_position(Vector3(0, 1.05, 4.9), Vector3(0, 0.88, 0))
	if not mode.begins_with("wire"):
		for ch in chars: ch.idle(1.0)
	if mode == "turntable":
		Engine.max_fps = 0

func _process(delta: float) -> void:
	frame += 1
	var now := Time.get_ticks_usec()
	if last > 0: timings.append((now - last) / 1000.0)
	last = now
	if mode == "turntable":
		var t := frame / 30.0
		for ch in chars:
			ch.rotation.y = ({"paladin": 0.35, "mage": 0.0, "ranger": -0.35}[ch.kind] as float) + t * TAU / 10.0
			ch.idle(t, 0.6)
		if frame % 30 == 0: print("FRAME ", frame)
		if frame in [75, 150, 225]:
			get_viewport().get_texture().get_image().save_png("res://out/turntable_f%d.png" % frame)
		return
	if frame == 6:
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://out/" + out_name + ".png")
		var s := timings.duplicate(); s.sort()
		print("STILL ", out_name, " frame_ms_median=", s[s.size() / 2] if s.size() > 0 else 0.0)
		get_tree().quit()

func _exit_tree() -> void:
	if mode == "turntable" and timings.size() > 0:
		var s: PackedFloat64Array = timings.duplicate(); s.sort()
		var tot := 0.0
		for x in s: tot += x
		print("FRAME_MS mean=%.1f median=%.1f p95=%.1f n=%d" % [tot / s.size(), s[s.size() / 2], s[int(s.size() * 0.95)], s.size()])

## Breakdown view (DEBUG_DRAW_WIREFRAME is unsupported in Compatibility):
## clay override on the skinned mesh + a line mesh built from the triangle
## index buffers, coloured per material surface. Rest pose, so they coincide.
func _wire(ch: Node3D) -> void:
	var mi: MeshInstance3D = ch.find_children("*", "MeshInstance3D", true, false)[0]
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color(0.62, 0.62, 0.64)
	clay.roughness = 0.8
	clay.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = clay
	var am: ArrayMesh = mi.mesh
	var lines := ArrayMesh.new()
	for si in am.get_surface_count():
		var a := am.surface_get_arrays(si)
		var V: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var N: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var I: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var lv := PackedVector3Array()
		lv.resize(I.size() * 2)
		var k := 0
		for t in range(0, I.size(), 3):
			for e in 3:
				var i0 := I[t + e]; var i1 := I[t + (e + 1) % 3]
				lv[k] = V[i0] + N[i0] * 0.0004; lv[k + 1] = V[i1] + N[i1] * 0.0004
				k += 2
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = lv
		lines.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = Color.from_hsv(fmod(si * 0.17, 1.0), 0.75, 0.55)
		lines.surface_set_material(si, lm)
	var li := MeshInstance3D.new()
	li.mesh = lines
	li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.get_parent().add_child(li)
	li.transform = mi.transform
