## One character: skeleton, skinned meshes for head/hands/garments/armour/hair,
## per-character materials, and a procedural idle (breath, weight shift, head
## drift, spring-lagged hair and cloth).
class_name Character
extends Node3D

var kind := "paladin"
var body: Body
var head: Head
var sk: Skeleton3D
var B := {}
var segs := [] # [bone, a, b, scale] for automatic skin weights
var mesh := ArrayMesh.new()
var sts := {} # material key -> SurfaceTool
var mats := {}
var tris := {}
var hair_bones := []
var t := 0.0
var seed_phase := 0.0
var timings := {}

# ------------------------------------------------------------------ skeleton
func _bones(extra := []) -> void:
	var J := body.J
	var table := [
		["pelvis", "", J.pelvis], ["spine", "pelvis", J.spine], ["chest", "spine", J.chest],
		["neck", "chest", J.neck], ["head", "neck", J.head],
		["skirtF", "pelvis", Vector3(0, 0.95, 0.08)], ["skirtB", "pelvis", Vector3(0, 0.95, -0.08)],
	]
	for s in ["L", "R"]:
		table.append(["upperarm_" + s, "chest", J["shoulder_" + s]])
		table.append(["forearm_" + s, "upperarm_" + s, J["elbow_" + s]])
		table.append(["hand_" + s, "forearm_" + s, J["wrist_" + s]])
		table.append(["thigh_" + s, "pelvis", J["hip_" + s]])
		table.append(["shin_" + s, "thigh_" + s, J["knee_" + s]])
		table.append(["foot_" + s, "shin_" + s, J["ankle_" + s]])
	table.append_array(extra)
	sk = Skeleton3D.new()
	var gp := {}
	for row in table:
		var i := sk.add_bone(row[0])
		B[row[0]] = i
		gp[row[0]] = row[2]
		var pp := Vector3.ZERO
		if row[1] != "":
			sk.set_bone_parent(i, B[row[1]])
			pp = gp[row[1]]
		sk.set_bone_rest(i, Transform3D(Basis(), (row[2] as Vector3) - pp))
	sk.reset_bone_poses()
	add_child(sk)
	segs = [
		["pelvis", Vector3(0, 0.80, 0), Vector3(0, 1.0, 0), 1.0],
		["spine", Vector3(0, 1.0, 0), Vector3(0, 1.18, 0), 1.0],
		["chest", Vector3(0, 1.18, 0), Vector3(0, 1.40, -0.01), 1.0],
		["neck", Vector3(0, 1.42, -0.022), Vector3(0, 1.50, -0.02), 1.2],
		["head", Vector3(0, 1.52, 0), Vector3(0, 1.70, 0), 1.0],
	]
	for s in ["L", "R"]:
		segs.append(["upperarm_" + s, J["shoulder_" + s], J["elbow_" + s], 1.25])
		segs.append(["forearm_" + s, J["elbow_" + s], J["wrist_" + s], 1.0])
		segs.append(["hand_" + s, J["wrist_" + s], (J["wrist_" + s] as Vector3) + Vector3(0, -0.17, 0), 1.0])
		segs.append(["thigh_" + s, J["hip_" + s], J["knee_" + s], 1.7])
		segs.append(["shin_" + s, J["knee_" + s], J["ankle_" + s], 1.0])
		segs.append(["foot_" + s, J["ankle_" + s], (J["ankle_" + s] as Vector3) + Vector3(0, -0.06, 0.16), 1.0])

static func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var h := clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return (p - a - ab * h).length()

## nearest two bone segments -> [b0, b1, w1]
func wauto(p: Vector3) -> Array:
	var best := [1e9, 1e9]
	var bi := [0, 0]
	for sgm in segs:
		var d: float = seg_dist(p, sgm[1], sgm[2]) * sgm[3]
		if d < best[0]:
			best[1] = best[0]; bi[1] = bi[0]
			best[0] = d; bi[0] = B[sgm[0]]
		elif d < best[1]:
			best[1] = d; bi[1] = B[sgm[0]]
	var w := clampf(0.5 - (best[1] - best[0]) / 0.07, 0.0, 0.5)
	return [bi[0], bi[1], w]

func AUTO() -> Callable:
	return func(u, v, p): return wauto(p)

func rigid(bone: String) -> Callable:
	var b: int = B[bone]
	return func(u, v, p): return [b, b, 0.0]

# ------------------------------------------------------------------ materials
func st(key: String) -> SurfaceTool:
	if not sts.has(key):
		sts[key] = Geo.new_st(true)
	return sts[key]

static var _tex_cache := {}
func surface(kind_: String, tint: Color, uv_scale: float, o := {}) -> ShaderMaterial:
	var key := kind_ + str(o.get("seed", 1))
	if not _tex_cache.has(key):
		var m := TexGen.make(kind_, 256, o.get("seed", 1), Color(0.75, 0.75, 0.75))
		_tex_cache[key] = [m.albedo_texture, m.normal_texture, m.roughness_texture]
	var tx: Array = _tex_cache[key]
	var sm := ShaderMaterial.new()
	sm.shader = _shader("SURFACE", Shaders.SURFACE)
	sm.set_shader_parameter("albedo_tex", tx[0])
	sm.set_shader_parameter("normal_tex", tx[1])
	sm.set_shader_parameter("rough_tex", tx[2])
	sm.set_shader_parameter("tint", tint)
	sm.set_shader_parameter("uv_scale", uv_scale)
	for k in o:
		if k != "seed":
			sm.set_shader_parameter(k, o[k])
	return sm

static var _shaders := {}
static func _shader(name: String, code: String) -> Shader:
	if not _shaders.has(name):
		var s := Shader.new(); s.code = code; _shaders[name] = s
	return _shaders[name]

func shader_mat(name: String, code: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = _shader(name, code)
	for k in params: m.set_shader_parameter(k, params[k])
	return m

# ------------------------------------------------------------------ build
func build(kind_: String) -> void:
	kind = kind_
	var t0 := Time.get_ticks_msec()
	var P: Dictionary = Looks.params(kind)
	body = Body.new(P.body)
	head = Head.new(P.face)
	var hb: Array = P.get("hair_bones", [])
	_bones(hb)
	for k in hb: hair_bones.append(k[0])
	mats = Looks.materials(self, kind)
	# head, eyes, lashes, ears
	var ho: Vector3 = body.J.head
	var hst := st("skin_head")
	head.build(hst, 144, 108, B.head, ho)
	for i in 2:
		var e := st("eye_" + str(i))
		Face.eye_mesh(e, head, i, ho, B.head)
		Face.lashes(st("lashes"), head, i, ho, B.head, true)
		Face.lashes(st("lashes"), head, i, ho, B.head, false)
	if P.get("ears", true):
		Face.ear(st("skin_head"), 1.0, ho, B.head)
		Face.ear(st("skin_head"), -1.0, ho, B.head)
	timings["head"] = Time.get_ticks_msec() - t0
	t0 = Time.get_ticks_msec()
	Outfits.new().call(kind, self)
	timings["outfit"] = Time.get_ticks_msec() - t0
	t0 = Time.get_ticks_msec()
	Styles.new().call(kind, self)
	timings["hair"] = Time.get_ticks_msec() - t0
	t0 = Time.get_ticks_msec()
	for k in sts:
		Geo.tri_count.clear()
		Geo.finish(sts[k], mesh, mats[k], k)
		tris[k] = Geo.tri_count[k]
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = sk.create_skin_from_rest_transforms()
	timings["commit"] = Time.get_ticks_msec() - t0

func total_tris() -> int:
	var n := 0
	for k in tris: n += tris[k]
	return n

# ------------------------------------------------------------------ idle
func rot(n: String, x: float, y := 0.0, z := 0.0) -> void:
	if B.has(n):
		sk.set_bone_pose_rotation(B[n], Quaternion.from_euler(Vector3(x, y, z)))

func idle(time: float, yaw_vel := 0.0) -> void:
	t = time + seed_phase
	var br := sin(t * TAU / 4.2) # breath
	var sh := sin(t * TAU / 9.0) # weight shift
	var hd := sin(t * TAU / 7.0 + 1.0)
	rot("pelvis", 0.0, 0.03 * sh, 0.035 * sh)
	sk.set_bone_pose_position(B.pelvis, body.J.pelvis + Vector3(0.012 * sh, -0.004 * absf(sh), 0))
	rot("spine", 0.012 * br, -0.015 * sh, -0.02 * sh)
	rot("chest", -0.018 * br, -0.01 * sh, -0.02 * sh)
	rot("neck", 0.01 * br, 0.04 * hd, 0.0)
	rot("head", 0.02 * sin(t * TAU / 5.3), 0.06 * hd, 0.025 * sh)
	for s in ["L", "R"]:
		var sg := 1.0 if s == "L" else -1.0
		rot("thigh_" + s, 0.0, 0.0, -0.035 * sh)
		rot("upperarm_" + s, 0.025 * br, 0.0, sg * (0.012 * br) + 0.02 * sh * 0.0)
		rot("forearm_" + s, -0.03 - 0.015 * br, 0.0, 0.0)
	# springy secondary motion: lagged, decaying copies of body motion + turntable drag
	var lag := sin((t - 0.5) * TAU / 9.0)
	var lag2 := sin((t - 0.35) * TAU / 7.0 + 1.0)
	var k := 1.0
	for hbn in hair_bones:
		rot(hbn, 0.03 * k * sin((t - 0.4 * k) * TAU / 4.2) + 0.04 * yaw_vel, -0.03 * lag2 * k, -0.06 * lag * k - 0.08 * yaw_vel * k)
		k += 0.6
	rot("skirtF", -0.015 * lag, 0.0, -0.03 * lag)
	rot("skirtB", 0.02 * lag, 0.0, -0.03 * lag + 0.05 * yaw_vel)
